#!/bin/bash

# Defined path
MainPath="$(pwd)"
GCC64="$(pwd)/../GCC64"
GCC="$(pwd)/../GCC"
Any="$(pwd)/../AnyKernel3"

# Upload to telegram
UT=0
if [ $UT = 1 ]; then
    BOT_TOKEN="bot1446507242:AAFivf422Yvh3CL7y98TJmxV1KgyKByuPzM"
    CHAT_ID="-1001421078455"
fi

msg() {
    curl -X POST "https://api.telegram.org/bot1446507242:AAFivf422Yvh3CL7y98TJmxV1KgyKByuPzM/sendMessage" \
    -d chat_id="-1001421078455" \
    -d "disable_web_page_preview=true" \
    -d "parse_mode=html" \
    -d text="$Text"
}

Upload() {
    curl -F chat_id="-1001421078455" \
    -F document=@"$FILE" \
    -F parse_mode=markdown https://api.telegram.org/bot1446507242:AAFivf422Yvh3CL7y98TJmxV1KgyKByuPzM/sendDocument \
    -F caption="$Caption"
}

# Make flashable zip
MakeZip() {
    if [ ! -d $Any ]; then
        git clone https://github.com/TeraaBytee/AnyKernel3 -b master $Any
        cd $Any
    else
        cd $Any
        git reset --hard
        git checkout master
        git fetch origin master
        git reset --hard origin/master
    fi
    cp -af $MainPath/out/arch/arm64/boot/Image.gz-dtb $Any
    sed -i "s/kernel.string=.*/kernel.string=$KERNEL_NAME-$HeadCommit test by $KBUILD_BUILD_USER/g" anykernel.sh
    zip -r9 $MainPath/"[$Compiler][R-OSS]-$ZIP_KERNEL_VERSION-$KERNEL_NAME-$TIME.zip" * -x .git README.md *placeholder
    cd $MainPath
}

# Clone compiler
CloneCompiler() {
    if [ $UT = 1 ]; then
        Text="Clone compiler"
        msg
    fi
    if [ ! -d $GCC64 ]; then
        git clone --depth=1 https://github.com/mvaisakh/gcc-arm64 -b gcc-master $GCC64
    else
        cd $GCC64
        git fetch origin gcc-master
        git checkout FETCH_HEAD
        git branch -D gcc-master
        git branch gcc-master && git checkout gcc-master
        cd $MainPath
    fi
    GCC64_Version="$($GCC64/bin/*gcc --version | grep gcc)"

    if [ ! -d $GCC ]; then
        git clone --depth=1 https://github.com/mvaisakh/gcc-arm -b gcc-master $GCC
    else
        cd $GCC
        git fetch origin gcc-master
        git checkout FETCH_HEAD
        git branch -D gcc-master
        git branch gcc-master && git checkout gcc-master
        cd $MainPath
    fi
    GCC_Version="$($GCC/bin/*gcc --version | grep gcc)"
}

# Defined config
HeadCommit="$(git log --pretty=format:'%h' -1)"
export ARCH="arm64"
export SUBARCH="arm64"
export KBUILD_BUILD_USER="TeraaBytee"
export KBUILD_BUILD_HOST="$(hostname)"
Defconfig="begonia_user_defconfig"
KERNEL_NAME=$(cat "$MainPath/arch/arm64/configs/$Defconfig" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )
ZIP_KERNEL_VERSION="4.14.$(cat "$MainPath/Makefile" | grep "SUBLEVEL =" | sed 's/SUBLEVEL = *//g')$(cat "$(pwd)/Makefile" | grep "EXTRAVERSION =" | sed 's/EXTRAVERSION = *//g')"

# Start building
Compile() {
    Compiler=GCC
    if [ $UT = 1 ]; then
        Text="<b>Device</b>: <code>Redmi Note 8 Pro [BEGONIA]</code>%0A<b>Branch</b>: <code>$(git branch | grep '*' | awk '{ print $2 }')</code>%0A<b>Kernel name</b>: <code>$(cat "arch/arm64/configs/begonia_user_defconfig" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )</code>%0A<b>Kernel version</b>: <code>4.14.$(cat "Makefile" | grep "SUBLEVEL =" | sed 's/SUBLEVEL = *//g')</code>%0A<b>Build user</b>: <code>$KBUILD_BUILD_USER</code>%0A<b>Build host</b>: <code>$KBUILD_BUILD_HOST</code>%0A<b>Cross compile</b>:%0A<code>$GCC64_Version</code>%0A<b>Cross compile arm32</b>:%0A<code>$GCC_Version</code>%0A<b>Changelogs</b>:%0A<code>$(git log --oneline -5 --no-decorate)</code>"
        msg
    fi
    rm -rf out
    TIME=$(date +"%m%d%H%M")
    BUILD_START=$(date +"%s")

    make  -j$(nproc --all)  O=out ARCH=arm64 SUBARCH=arm64 $Defconfig
    exec 2> >(tee -a out/error.log >&2)
    make  -j$(nproc --all)  O=out \
                            PATH="$GCC64/bin:$GCC/bin:/usr/bin:$PATH" \
                            AR=aarch64-elf-ar \
                            LD=aarch64-elf-ld \
                            NM=llvm-nm \
                            OBCOPY=llvm-objcopy \
                            OBJDUMP=aarch64-elf-objdump \
                            STRIP=aarch64-elf-strip \
                            CROSS_COMPILE=aarch64-elf- \
                            CROSS_COMPILE_ARM32=arm-eabi-
}

# End with success or fail
End() {
    if [ -e $MainPath/out/arch/arm64/boot/Image.gz-dtb ]; then
        BUILD_END=$(date +"%s")
        DIFF=$((BUILD_END - BUILD_START))
        MakeZip
        ZIP=$(echo *$Compiler*$TIME*.zip)
        if [ $UT = 1 ]; then
            TIME=$(echo "Build success in : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)")
            FILE=$ZIP
            Caption="$TIME @TeraaBytee"
            Upload
        else
            echo "Build success in : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
        fi
    else
        BUILD_END=$(date +"%s")
        DIFF=$((BUILD_END - BUILD_START))
        if [ $UT = 1 ]; then
            TIME=$(echo "Build fail in : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)")
            FILE="out/error.log"
            Caption="$TIME Check this @TeraaBytee"
            Upload
        else
            echo "Build fail in : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
        fi
    fi
}

Text="Start to build kernel"

if [ $UT = 1 ]; then
    msg
fi
CloneCompiler
Compile
End
