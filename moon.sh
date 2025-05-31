#!/bin/bash
set -e

# Clean any previous AnyKernel directory
rm -rf AnyKernel

# Use Telegram token from GitHub Actions environment
echo "Using TELEGRAM_BOT_TOKEN: ${TELEGRAM_BOT_TOKEN:+***}"
export TOKEN="$TELEGRAM_BOT_TOKEN"

# Path to your kernel root (assumed to be current directory)
KERNEL_ROOT="$PWD"

echo "Kernel root: $KERNEL_ROOT"

function compile() {
    source ~/.bashrc && source ~/.profile
    export LC_ALL=C
    export USE_CCACHE=1
    ccache -M 120G
    export ARCH=arm64
    export KBUILD_BUILD_HOST=Radiata
    export KBUILD_BUILD_USER="wein"

    # Clone toolchains
    git clone --depth=1 https://github.com/sarthakroy2002/android_prebuilts_clang_host_linux-x86_clang-6443078 clang
    git clone --depth=1 https://github.com/ghostrider-reborn/prebuilts_gcc_linux-x86_aarch64_aarch64-linaro-7 los-4.9-64
    git clone --depth=1 https://github.com/MayuriLabs/linaro_arm-linux-gnueabihf-7.5 los-4.9-32

    # Clone SUSFS patches (simonpunk)
    git clone --depth=1 --branch kernel-4.14 https://gitlab.com/simonpunk/susfs4ksu.git susfs4ksu

    # Apply SUSFS kernel patches
    # Copy patches to appropriate kernel directories
    cp susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch $KERNEL_ROOT/KernelSU-Next/

    # Determine kernel version for patch filename
    KVER=$(make -sC "$KERNEL_ROOT" kernelversion)
    cp susfs4ksu/kernel_patches/50_add_susfs_in_kernel-${KVER}.patch $KERNEL_ROOT/

    # Copy filesystem and include patches
    cp susfs4ksu/kernel_patches/fs/* $KERNEL_ROOT/fs/
    cp susfs4ksu/kernel_patches/include/linux/* $KERNEL_ROOT/include/linux/

    # Apply patches
    cd $KERNEL_ROOT/KernelSU
    patch -p1 < 10_enable_susfs_for_ksu.patch
    cd $KERNEL_ROOT
    patch -p1 < 50_add_susfs_in_kernel-${KVER}.patch || echo "Some hunks failed; please patch manually."

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

function zupload() {
    git clone --depth=1 https://github.com/DPSLEGEND/Anykernel3.git -b moon AnyKernel
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel
    cd AnyKernel
    export KERNEL_NAMEZ="X-DolphinKernel-v4.14.265"
    zip -r9 "${KERNEL_NAMEZ}.zip" *
}

function teleup() {
    curl -v -F "chat_id=1478995427" -F document=@"AnyKernel/${KERNEL_NAMEZ}.zip" https://api.telegram.org/bot$TOKEN/sendDocument
}

compile
zupload
teleup
