# TSPI-ACTION-BSP

## Project Overview

TSPI-ACTION is an open-source action camera built on the Lichuang Taishan Pi RK3566. This repository maintains the camera's board support package (BSP), including patches for the Linux kernel, board configuration, and Buildroot, as well as a root filesystem overlay.

When building the system image, Buildroot fetches the camera application source, compiles it, and installs it into the image. Once you flash the image to the Taishan Pi, the camera application starts automatically at boot.

## Quick Start

### 1. Prepare the Linux SDK

Follow Lichuang's guide to download and sync the repo-managed Linux SDK for the Taishan Pi RK3566 and install the build dependencies. [Lichuang SDK build guide (Chinese)](https://wiki.lckfb.com/zh-hans/tspi-rk3566/project-case/fat-little-cell-phone/sdk-compile.html#linux-sdk)

This project uses Linux 4.19.232. The baseline commits for the kernel, `device/rockchip`, and Buildroot are listed in [VERSION](VERSION).

Clone this repository into the SDK root. The example below assumes the SDK directory is named `linux_sdk`.

```text
linux_sdk/
└── tspi_action_bsp/
```

From the SDK's parent directory, enter the BSP repository and apply the patches.

```bash
cd linux_sdk/tspi_action_bsp
./scripts/apply.sh
```

Run the script on a clean SDK. If any SDK repository's HEAD differs from its baseline in `VERSION`, the script prompts for confirmation. Entering `YES` resets each affected repository to its baseline, discards uncommitted changes, and leaves local commits made after the baseline off the current branch.

### 2. Build the System Image

Set `TSPI_ACTION_SOURCE_VERSION` in [tspi_action_source.mk](buildroot/external/package/tspi_action_source/tspi_action_source.mk) to the commit ID from the camera application repository (`tspi_action_source`). Buildroot fetches the source at that commit, builds it, and installs the application into the image. Before building, make sure the build machine has SSH access to the configured source repository on Gitee or GitHub.

Return to the SDK root and open the board selection menu.

```bash
cd ..
./build.sh lunch
```

Select `BoardConfig-rk3566-tspi-v10.mk`, then build and package the system images.

```bash
export RK_ROOTFS_SYSTEM=buildroot
./build.sh all && ./build.sh firmware
```

### 3. Flash the Taishan Pi

Put the Taishan Pi into Loader mode. Use Lichuang's flashing tool to select and flash the images from `rockdev/` according to your device's partition layout. [Lichuang Taishan Pi flashing guide (Chinese)](https://wiki.lckfb.com/zh-hans/tspi-rk3566/img-download/img-download.html)

## Development and Debugging

See [AGENTS.md](AGENTS.md) for the BSP repository layout, patch maintenance, incremental builds, and boot debugging.
