# TSPI-ACTION-BSP

## 项目介绍

TSPI-ACTION 是一款基于立创泰山派 RK3566 的开源运动相机。本仓库维护相机的板级支持包（BSP），包含 Linux 内核、板级配置和 Buildroot 的补丁，以及根文件系统覆盖目录。

构建系统镜像时，Buildroot 会自动拉取相机应用的源码，编译并安装到镜像中。将镜像烧录到泰山派后，相机应用会随系统启动。

## 快速开始

### 1. 准备 Linux SDK

按立创的指南下载并同步泰山派 RK3566 的 repo 版 Linux SDK，并安装编译依赖。[立创泰山派 SDK 编译指南](https://wiki.lckfb.com/zh-hans/tspi-rk3566/project-case/fat-little-cell-phone/sdk-compile.html#linux-sdk)

本项目使用 Linux 4.19.232。内核、`device/rockchip` 和 Buildroot 的基线提交见 [VERSION](VERSION)。

将本仓库克隆到 SDK 根目录下。以下以 `linux_sdk` 为 SDK 目录名。

```text
linux_sdk/
└── tspi_action_bsp/
```

从 SDK 的上一级目录进入 BSP 仓库并应用补丁。

```bash
cd linux_sdk/tspi_action_bsp
./scripts/apply.sh
```

请在干净的 SDK 上执行。若子仓库的当前提交与 `VERSION` 中的基线不同，脚本会提示确认。输入 `YES` 会将偏离基线的仓库重置到基线，丢弃未提交的改动，并使基线之后的本地提交脱离当前分支。

### 2. 构建系统镜像

将相机应用仓库（`tspi_action_source`）的提交 ID 填入 [tspi_action_source.mk](buildroot/external/package/tspi_action_source/tspi_action_source.mk) 中的 `TSPI_ACTION_SOURCE_VERSION`。Buildroot 会拉取该提交的源码，编译并安装到镜像中。编译前，请确认构建机已根据源码地址配置对应的 SSH 访问（Gitee 或 GitHub）。

返回 SDK 根目录，打开板型选择菜单。

```bash
cd ..
./build.sh lunch
```

选择 `BoardConfig-rk3566-tspi-v10.mk`，然后编译并打包。

```bash
export RK_ROOTFS_SYSTEM=buildroot
./build.sh all && ./build.sh firmware
```

### 3. 烧录到泰山派

将泰山派切到 Loader 模式，使用立创的烧录工具，按设备的分区配置选择 `rockdev/` 下的镜像进行烧录。[立创泰山派镜像烧录教程](https://wiki.lckfb.com/zh-hans/tspi-rk3566/img-download/img-download.html)

## 开发与调试

BSP 的目录结构、补丁维护、增量编译和启动调试见 [AGENTS.md](AGENTS.md)。
