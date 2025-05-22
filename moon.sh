#!/bin/bash
rm -rf AnyKernel

# Set Telegram token (should be stored as secret in real use)
export TOKEN="$TELEGRAM_BOT_TOKEN"

function compile() 
{
    source ~/.bashrc && source ~/.profile
    export LC_ALL=C && export USE_CCACHE=1
    ccache -M 120G
    export ARCH=arm64
    export KBUILD_BUILD_HOST=Radiata
    export KBUILD_BUILD_USER="wein"

    # Toolchain cloning
    git clone --depth=1 https://github.com/sarthakroy2002/android_prebuilts_clang_host_linux-x86_clang-6443078 clang
    git clone --depth=1 https://github.com/ghostrider-reborn/prebuilts_gcc_linux-x86_aarch64_aarch64-linaro-7 los-4.9-64
    git clone --depth=1 https://github.com/MayuriLabs/linaro_arm-linux-gnueabihf-7.5 los-4.9-32

    # Clean build environment
    make O=out ARCH=arm64 mrproper

    # Kernel defconfig
    make O=out ARCH=arm64 moon_defconfig

    # Start compilation
    PATH="${PWD}/clang/bin:${PWD}/los-4.9-32/bin:${PWD}/los-4.9-64/bin:${PATH}" \
    make -j$(nproc --all) O=out \
        ARCH=arm64 \
        CC="clang" \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE="${PWD}/los-4.9-64/bin/aarch64-linux-gnu-" \
        CROSS_COMPILE_ARM32="${PWD}/los-4.9-32/bin/arm-linux-gnueabihf-" \
        CONFIG_NO_ERROR_ON_MISMATCH=y
}

function zupload()
{
    git clone --depth=1 https://github.com/DPSLEGEND/Anykernel3.git -b moon AnyKernel
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel
    cd AnyKernel
    export KERNEL_NAMEZ="X-DolphinKernel-v4.14.265"
    zip -r9 "${KERNEL_NAMEZ}.zip" *
}

function teleup()
{
    curl -v -F "chat_id=1478995427" -F document=@"${KERNEL_NAMEZ}.zip" https://api.telegram.org/bot$TOKEN/sendDocument
}

compile
zupload
teleup
