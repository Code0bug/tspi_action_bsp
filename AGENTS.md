# TSPI-ACTION-BSP

## 介绍

本仓库维护泰山派 RK3566 运动相机的 BSP，与 `tspi_action_source` 应用仓库配套使用。Rockchip Linux SDK 由 repo 管理，内核、`device/rockchip` 和 Buildroot 的定制改动通过补丁维护。相机软件包、系统启动脚本和其他根文件系统覆盖文件放在 Buildroot 的 `BR2_EXTERNAL` 目录中。

## 目录

| 路径 | 职责 |
| --- | --- |
| `VERSION` | 记录内核版本和各 SDK 子仓库的基线提交。当前基线对应原厂 `tspi-v1.0`，内核版本为 4.19.232。 |
| `patches/kernel/` | 内核补丁，包括设备树、驱动等相关改动。 |
| `patches/device/rockchip/` | 板级配置补丁，引入 `BR2_EXTERNAL`，并将 OEM 和 userdata 分区设为 ext4。 |
| `patches/buildroot/` | Buildroot 配置补丁，打开相机应用、qt、ffmepg 等必要系统组件配置 |
| `buildroot/external/` | Buildroot 外部树，入口为 `external.desc`、`Config.in` 和 `external.mk`。 |
| `buildroot/external/package/tspi_action_source/` | 相机应用包，定义应用版本、Buildroot 依赖和 CMake 安装参数。 |
| `buildroot/external/board/tspi/fs-overlay/` | 根文件系统覆盖目录，包含服务启动脚本、调试配置、字体和辅助工具。 |
| `scripts/apply.sh` | 根据 `VERSION` 向 SDK 重放补丁。 |
| `doc/` | 相关文档记录。 |

## 系统构建

### 应用补丁

首次构建时，在干净的 SDK 上应用本仓库的补丁，为相机应用补齐驱动、内核配置、Buildroot 软件包和根文件系统配置。脚本依次对 `kernel`、`device/rockchip` 和 `buildroot` 执行 `git am`。

执行前检查三个子仓库的工作区、当前提交和 `VERSION` 中的基线，保存需要保留的改动。脚本在检查 HEAD 前会尝试中止未完成的 `git am`。若有仓库偏离基线，输入 `YES` 后，脚本才会对这些仓库执行 `git reset --hard` 并继续应用补丁。

在 BSP 仓库根目录执行。脚本默认将本仓库的上一级目录作为 SDK 根目录。

```bash
./scripts/apply.sh

# SDK 位于其他目录时，显式指定补丁目标
SDK_DIR=/path/to/linux_sdk ./scripts/apply.sh
```

`SDK_DIR` 用于指定打补丁的目标。

### 编译

首次构建前，在 [tspi_action_source.mk](buildroot/external/package/tspi_action_source/tspi_action_source.mk) 中确认 `TSPI_ACTION_SOURCE_VERSION` 对应要打包的应用提交，并确认构建机能通过 SSH 访问配置中的源码仓库。后续相机应用若有源码修改，push 到远程后，可以直接修改 `TSPI_ACTION_SOURCE_VERSION` 为最新的提交 ID，这样执行 `./build.sh rootfs` 时 buildroot 会拉取指定提交的源码进行编译安装。

在 SDK 根目录运行以下命令，在菜单中选择 `BoardConfig-rk3566-tspi-v10.mk`。

```bash
./build.sh lunch
```

**完整编译**

```bash
export RK_ROOTFS_SYSTEM=buildroot
./build.sh all && ./build.sh firmware
```

**增量编译**

平常开发调试建议使用增量编译

增量构建时，先确认 `device/rockchip/.BoardConfig.mk` 指向 `rk356x/BoardConfig-rk3566-tspi-v10.mk`，再按改动范围从 SDK 根目录运行对应命令。

```bash
# 生成 rockdev/boot.img，包含内核、驱动和启动 Logo。
./build.sh kernel

# 生成根文件系统 rockdev/rootfs.ext4，包含依赖包和相机应用。
./build.sh rootfs

# 生成 rockdev/oem.img 和 rockdev/userdata.img。
# 烧录 userdata.img 会覆盖板上的 /userdata（包括照片和录像）。
# 日常只更新系统时，可以跳过 userdata.img。
./build.sh firmware
```

### 单独重编相机应用包

已有 Buildroot 构建产物时，可在 SDK 根目录运行以下命令，重编当前版本的应用包。

```bash
cd linux_sdk
# 先清除旧构建
rm -f buildroot/dl/tspi_action_source-*.tar.gz
rm -rf buildroot/output/rockchip_rk3566/build/tspi_action_source-*
# 重新编译
make -C buildroot/output/rockchip_rk3566 tspi_action_source-rebuild
```

应用安装到 `buildroot/output/rockchip_rk3566/target/` 下，对应路径如下。

- `usr/bin/camera-ui` 和 `usr/bin/media-service`
- `usr/lib/libmedia_hal.so`
- `usr/lib/qt/plugins/platforms/libqtspi.so`
- `etc/dbus-1/system.d/com.tspi.MediaService.conf`

### 完整重编 Buildroot

`clean` 会删除 Buildroot 输出目录中的 `target/`、`images/`、`host/` 和 `build/` 等产物，下一次构建会重新编译工具链和各软件包。要完整重编，在 SDK 根目录执行以下命令。

```bash
make -C buildroot O=output/rockchip_rk3566 clean
./build.sh rootfs
```

## SDK 改动和提交

在对应的 SDK 子仓库提交改动后，使用 `git format-patch` 将提交导出到 BSP 仓库。导出前根据 `VERSION` 核对基线和提交范围，避免混入无关提交。以下命令从 SDK 根目录运行。

```bash
. ./tspi_action_bsp/VERSION
bsp_dir="$PWD/tspi_action_bsp"
git -C kernel format-patch "$kernel_base..HEAD" -o "$bsp_dir/patches/kernel"
git -C device/rockchip format-patch "$device_base..HEAD" -o "$bsp_dir/patches/device/rockchip"
git -C buildroot format-patch "$buildroot_base..HEAD" -o "$bsp_dir/patches/buildroot"
```

完整导出后，对照原有补丁检查文件名和顺序，确保目录中保留一套可从基线重放的补丁。只更新部分补丁时，按对应提交范围导出并核对编号。相机应用包、启动脚本等文件直接在 `buildroot/external/` 下维护。
