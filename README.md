# tspi_action_bsp

泰山派 RK3566（tspi-action）板级改动：内核 / device / buildroot 补丁，以及 Buildroot `BR2_EXTERNAL`（fs-overlay）。

本仓库放在 Rockchip SDK 旁使用，默认路径：

```text
/home/lzp/linux_sdk/                  # Rockchip SDK（repo 管理，不上传）
└── tspi_action_bsp/                  # 本仓库
```

基线见 `VERSION`（kernel / buildroot / device 均为原厂 tag `tspi-v1.0` 对应提交）。

## 目录

```text
VERSION
doc/                                # 启动耗时记录
patches/kernel/                     # 内核补丁
patches/device/                     # device/rockchip 补丁（BR2_EXTERNAL 等）
patches/buildroot/                  # rockchip_rk3566_defconfig 补丁
buildroot/external/                 # BR2_EXTERNAL
  external.desc / Config.in / external.mk
  package/tspi_action_source/       # 相机应用包：拉 Gitee 源码，用 CMake 交叉编译
    tspi_action_source.mk           # 版本与依赖；编译安装走 cmake-package
    Config.in
  board/tspi/fs-overlay/            # 根文件系统覆盖（叠在原厂 overlay 之上）
    etc/init.d/S22dbus              # system D-Bus，排在相机应用前面
    etc/init.d/S22rkaiq_3A          # 3A 服务
    etc/init.d/S23tspiAction        # 启动 /usr/bin/media-service 与 camera-ui
    etc/tspiAction_debug            # 计时启动开关；skip= 里跳过 S30dbus 等
    etc/tspi/boot_timing.sh
scripts/apply.sh                    # 向干净 SDK 重放补丁
```

## 应用到干净 SDK

1. SDK 停在 `VERSION` 基线，且 `kernel` / `device/rockchip` / `buildroot` 工作区干净。
2. 本仓库位于 `$SDK_DIR/tspi_action_bsp`（否则设置 `SDK_DIR`）。
3. 打补丁：

```bash
# 默认 SDK_DIR = 本仓库上一级（即 linux_sdk）
./scripts/apply.sh

# 或显式指定
SDK_DIR=/home/lzp/linux_sdk ./scripts/apply.sh
```

会依次 `git am`：

| 仓库 | 补丁目录 |
|------|----------|
| `kernel` | `patches/kernel/` |
| `device/rockchip` | `patches/device/` |
| `buildroot` | `patches/buildroot/` |

`buildroot/external` 不用打补丁；由 BoardConfig / `mk-buildroot.sh` 设置  
`BR2_EXTERNAL=$TOP_DIR/tspi_action_bsp/buildroot/external`。

`apply.sh` 会先对照 `VERSION` 检查 `kernel` / `device/rockchip` / `buildroot`：  
若不在基线则 **`git reset --hard` 到基线**（丢弃这三仓未导出的本地提交），再 `git am` 补丁。

## 编译

应用已做成 BR2_EXTERNAL 包 `tspi_action_source`（`BR2_PACKAGE_TSPI_ACTION_SOURCE`）。  
编 rootfs 时由 Buildroot 按依赖先编 Qt/OpenCV 等，再拉 Gitee 用 CMake 编译。装到目标系统的是 `/usr/bin/camera-ui`、`/usr/bin/media-service`、`/usr/lib/libmedia_hal.so`、`/usr/lib/qt/plugins/platforms/libqtspi.so`，以及 `/etc/dbus-1/system.d/com.tspi.MediaService.conf`。

```bash
cd /home/lzp/linux_sdk

# 若尚未选板，选 rk3566-tspi-v10 对应 BoardConfig
./build.sh lunch

# 内核
./build.sh kernel
# 产物：rockdev/boot.img

# 根文件系统（含 tspi_action_source 包；需能访问 Gitee）
./build.sh rootfs
# 产物：rockdev/rootfs.ext4

# 打包分区镜像（oem / userdata 等）
./build.sh firmware
# 产物：rockdev/oem.img、rockdev/userdata.img，并把 boot/rootfs 等链到 rockdev/
```

说明：

- 包定义见 `buildroot/external/package/tspi_action_source/`。
- `TSPI_ACTION_SOURCE_VERSION` 可为分支名、tag 或 commit hash；改版本后建议清缓存再编。
- rootfs overlay 顺序：原厂 common/rk356x/wifi，再叠本仓库 `board/tspi/fs-overlay`。
  
  成功时日志应有：  
  `Copying overlay .../tspi_action_bsp/buildroot/external/board/tspi/fs-overlay`
- 烧录：按立创泰山派方式分别下载  
  `boot.img`、`rootfs.ext4`（或 `rootfs.img`）、`oem.img`、`userdata.img`。
- 烧 `userdata.img` 会覆盖板上 `/userdata`（照片/录像等）；日常只更新系统时可以不烧这一项。

### 清除 tspi_action_source 旧构建

在 SDK 根目录执行：

```bash
cd /home/lzp/linux_sdk
rm -f buildroot/dl/tspi_action_source-*.tar.gz
rm -rf buildroot/output/rockchip_rk3566/build/tspi_action_source-*
```

### 单独重编应用包

清完缓存后，或仅需重编并安装到 `target`：

```bash
cd /home/lzp/linux_sdk
make -C buildroot/output/rockchip_rk3566 tspi_action_source-rebuild
```

产物装到 `buildroot/output/rockchip_rk3566/target/` 下的 `usr/bin/camera-ui`、`usr/bin/media-service`、`usr/lib/libmedia_hal.so`、`usr/lib/qt/plugins/platforms/libqtspi.so` 和 `etc/dbus-1/system.d/com.tspi.MediaService.conf`。  
若还要刷新可烧录镜像，再执行 `./build.sh rootfs`（或至少让 Buildroot 重新打 `rootfs.ext4`）。

### 清除全部旧构建，完整重编

会删掉当前输出目录下的 `target` / `images` / `host` / `build` 等，下次编 rootfs 相当于重新装包打包（工具链与各包也会重编，耗时很长）：

```bash
cd /home/lzp/linux_sdk/buildroot
make O=output/rockchip_rk3566 clean
cd /home/lzp/linux_sdk
./build.sh rootfs
```

## 导出补丁（维护时）

在对应仓库相对基线提交后：

```bash
# 内核
cd /home/lzp/linux_sdk/kernel
git format-patch <kernel_base> -o /home/lzp/linux_sdk/tspi_action_bsp/patches/kernel

# device（tag tspi-v1.0 之后的本地提交）
cd /home/lzp/linux_sdk/device/rockchip
git format-patch tspi-v1.0..HEAD -o /home/lzp/linux_sdk/tspi_action_bsp/patches/device

# buildroot defconfig
cd /home/lzp/linux_sdk/buildroot
git format-patch -1 <commit> -o /home/lzp/linux_sdk/tspi_action_bsp/patches/buildroot
```

fs-overlay、启动脚本等直接改 `buildroot/external/board/tspi/fs-overlay/`，无需打进 buildroot 仓库。
