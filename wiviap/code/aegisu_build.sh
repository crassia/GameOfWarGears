#!/bin/bash

generate_buildenv() {
    # Prepare build enviroment
    mkdir openwrt_build
    cd openwrt_build
    git clone --depth=1 https://github.com/mirrors/openwrt.git
    cd openwrt
}

dl_and_install_feeds() {
    # Download and install package feeds
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    rm -f .config .config.old
}

dl_and_apply_patches() {
    # Download and apply patches in build directory
    mkdir ../patches
    wget -qO ../patches/74kc_compiler_optimizations.patch http://paste.debian.net/downloadh/3ed50b52
    wget -qO ../patches/miniupnpd-1.8.20131216.patch http://paste.debian.net/downloadh/60229a8d
    for f in ../patches/*.patch; do
        patch -p1 < "${f}";
    done
}

dl_and_update_config() {
    # Download and update .config
    wget -qO .config http://paste.debian.net/downloadh/1d7f3f65
    make defconfig
}

run_make() {
    # Compile firmware
    make -j $(getconf _NPROCESSORS_ONLN 2> /dev/null)
}

gen_sha256sums() {
    # Generate sha256sums
    cd bin/ar71xx
    sha256sum openwrt-ar71xx-generic-tl-wr841n-v8-squashfs-factory.bin openwrt-ar71xx-generic-tl-wr841n-v8-squashfs-sysupgrade.bin > sha256sums
    cd ../..
}

create_archive() {
    # Create zip archive containing firmware images
    zip -9j ../openwrt-ar71xx-generic-tl-wr841n-v8-squashfs-$(git rev-parse --short HEAD).zip bin/ar71xx/sha256sums bin/ar71xx/openwrt-ar71xx-generic-tl-wr841n-v8-squashfs-factory.bin bin/ar71xx/openwrt-ar71xx-generic-tl-wr841n-v8-squashfs-sysupgrade.bin
}

optimize_luci() {

    dl_and_extract_apps() {
        wget -qO yuicompressor.jar https://github.com/yui/yuicompressor/releases/download/v2.4.8/yuicompressor-2.4.8.jar
        wget -qO compiler.zip http://dl.google.com/closure-compiler/compiler-latest.zip

        unzip -ojqq compiler.zip
        rm -f compiler.zip
    }

    # The following code is based on:
    # https://forum.openwrt.org/viewtopic.php?pid=183795#p183795
    #
    # We might want to look at modifiying imgopt for our needs
    minify_css() {
        for file in $( find "feeds/luci" -iname '*.css' )
        do
            echo "$file"
            java -jar yuicompressor.jar -o "$file-min.css" "$file"
            mv "$file-min.css" "$file"
        done
    }

    optimize_js() {
        for file in $( find "feeds/luci" -iname '*.js' )
        do
            echo "$file"
            java -jar compiler.jar --compilation_level=SIMPLE_OPTIMIZATIONS --js="$file" --js_output_file="$file-min.js"
            mv "$file-min.js" "$file"
        done
    }


    dl_and_extract_apps
    minify_css
    optimize_js

    rm -f yuicompressor.jar compiler.jar

}


generate_buildenv
dl_and_install_feeds
dl_and_apply_patches
optimize_luci
dl_and_update_config
run_make
gen_sha256sums
create_archive