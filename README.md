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
kernel/patches/                 # 内核补丁
device/patches/                 # device/rockchip 补丁（BR2_EXTERNAL 等）
buildroot/patches/              # rockchip_rk3566_defconfig 补丁
buildroot/external/             # BR2_EXTERNAL
  external.desc / Config.in / external.mk
  package/tspi_action_source/   # 相机应用 Buildroot 包（拉 Gitee 编译）
  board/tspi/fs-overlay/        # 根文件系统覆盖（叠在原厂 overlay 之上）
scripts/apply.sh                # 向干净 SDK 重放补丁
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
| `kernel` | `kernel/patches/` |
| `device/rockchip` | `device/patches/` |
| `buildroot` | `buildroot/patches/` |

`buildroot/external` 不用打补丁；由 BoardConfig / `mk-buildroot.sh` 设置  
`BR2_EXTERNAL=$TOP_DIR/tspi_action_bsp/buildroot/external`。

`apply.sh` 会先对照 `VERSION` 检查 `kernel` / `device/rockchip` / `buildroot`：  
若不在基线则 **`git reset --hard` 到基线**（丢弃这三仓未导出的本地提交），再 `git am` 补丁。

## 编译

应用已做成 BR2_EXTERNAL 包 `tspi_action_source`（`BR2_PACKAGE_TSPI_ACTION_SOURCE`）。  
编 rootfs 时由 Buildroot 按依赖先编 Qt/OpenCV 等，再拉 Gitee 编译 `ai-cam-ui-widget`，安装到 `/root/ai-cam-ui-widget`。

```bash
cd /home/lzp/linux_sdk

# 若尚未选板，选 rk3566-tspi-v10 对应 BoardConfig
./build.sh lunch

# 根文件系统（含 tspi_action_source 包；需能访问 Gitee）
./build.sh rootfs
# 产物：rockdev/rootfs.ext4

# 内核（单独烧录，不打包完整 update.img）
./build.sh kernel
# 产物：rockdev/boot.img
```

说明：

- 包定义见 `buildroot/external/package/tspi_action_source/`。
- 仅改应用源码后可在 buildroot 输出目录重建该包，例如：  
  `make -C buildroot/output/rockchip_rk3566 tspi_action_source-rebuild`
- rootfs overlay 顺序：原厂 common/rk356x/wifi，再叠本仓库 `board/tspi/fs-overlay`。
  
  成功时日志应有：  
  `Copying overlay .../tspi_action_bsp/buildroot/external/board/tspi/fs-overlay`
- 烧录：按立创泰山派方式分别下载 `boot.img` 与 `rootfs.ext4`（见 `tspi_action_source` 的 CLAUDE.md）。

## 导出补丁（维护时）

在对应仓库相对基线提交后：

```bash
# 内核
cd /home/lzp/linux_sdk/kernel
git format-patch <kernel_base> -o /home/lzp/linux_sdk/tspi_action_bsp/kernel/patches

# device（tag tspi-v1.0 之后的本地提交）
cd /home/lzp/linux_sdk/device/rockchip
git format-patch tspi-v1.0..HEAD -o /home/lzp/linux_sdk/tspi_action_bsp/device/patches

# buildroot defconfig
cd /home/lzp/linux_sdk/buildroot
git format-patch -1 <commit> -o /home/lzp/linux_sdk/tspi_action_bsp/buildroot/patches
```

fs-overlay、启动脚本等直接改 `buildroot/external/board/tspi/fs-overlay/`，无需打进 buildroot 仓库。
