#!/bin/bash
# Ensure kernel / device/rockchip / buildroot are at VERSION
# baselines, then replay BSP patches. Resets these repos if they are not on baseline.
set -euo pipefail

finish() {
	local status=$?
	echo
	echo "****************************************************************"
	if [ "$status" -eq 0 ]; then
		echo "success"
	else
		echo "fail"
	fi
	echo "****************************************************************"
}
trap finish EXIT

BSP_DIR=$(cd "$(dirname "$0")/.." && pwd)
SDK_DIR=${SDK_DIR:-$(cd "$BSP_DIR/.." && pwd)}
VERSION_FILE="$BSP_DIR/VERSION"

if [ ! -f "$VERSION_FILE" ]; then
	echo "ERROR: missing $VERSION_FILE"
	exit 1
fi

# Only pull baseline keys (avoid sourcing sdk_note etc. with spaces)
version_get() {
	local key=$1
	local val
	val=$(grep -E "^${key}=" "$VERSION_FILE" | tail -n1 | cut -d= -f2-)
	val=${val#\"}
	val=${val%\"}
	if [ -z "$val" ]; then
		echo "ERROR: $key not set in $VERSION_FILE"
		exit 1
	fi
	printf '%s' "$val"
}

kernel_base=$(version_get kernel_base)
device_base=$(version_get device_base)
buildroot_base=$(version_get buildroot_base)

EXPECTED_KERNEL_VER=4.19.232

read_kernel_version() {
	local makefile="$SDK_DIR/kernel/Makefile"
	local ver="unknown"

	if [ -f "$makefile" ]; then
		local v p s
		v=$(grep -E '^VERSION = ' "$makefile" | head -n1 | awk '{print $3}')
		p=$(grep -E '^PATCHLEVEL = ' "$makefile" | head -n1 | awk '{print $3}')
		s=$(grep -E '^SUBLEVEL = ' "$makefile" | head -n1 | awk '{print $3}')
		if [ -n "$v" ] && [ -n "$p" ] && [ -n "$s" ]; then
			ver="${v}.${p}.${s}"
		fi
	fi
	printf '%s' "$ver"
}

prepare_repo() {
	local repo=$1
	local base=$2
	local name=${repo#$SDK_DIR/}

	if [ ! -d "$repo/.git" ] && [ ! -d "$repo" ]; then
		echo "ERROR: repo not found: $repo"
		exit 1
	fi

	if ! git -C "$repo" rev-parse --verify "$base^{commit}" >/dev/null 2>&1; then
		echo "ERROR: $name: baseline $base not found in repo"
		exit 1
	fi

	# Drop an interrupted git am, if any
	if [ -d "$repo/.git/rebase-apply" ]; then
		echo "$name: abort interrupted git am"
		git -C "$repo" am --abort || true
	fi
}

print_repo_baseline() {
	local name=$1
	local head=$2
	local base_full=$3
	local key=$4

	if [ "$head" = "$base_full" ]; then
		echo "  $name: 已在基线 $base_full"
	else
		echo "  $name: 不在基线"
		echo "    当前 HEAD : $head"
		echo "    基线提交  : $base_full"
	fi
	echo "    VERSION   : $key"
}

# One prompt for kernel / device / buildroot before any reset.
remind_baselines() {
	local ver
	ver=$(read_kernel_version)

	echo
	echo "****************************************************************"
	echo "提醒: 有仓库不在 VERSION 基线，即将 git reset --hard 后 apply"
	echo
	print_repo_baseline "kernel" "$kernel_head" "$kernel_base_full" "kernel_base=$kernel_base"
	print_repo_baseline "device/rockchip" "$device_head" "$device_base_full" "device_base=$device_base"
	print_repo_baseline "buildroot" "$buildroot_head" "$buildroot_base_full" "buildroot_base=$buildroot_base"
	echo
	echo "请先检查:"
	echo "  1. 当前内核版本是不是 ${EXPECTED_KERNEL_VER}（Makefile 读到: $ver）"
	echo "  2. kernel、device/rockchip、buildroot 是不是都位于 VERSION 的基线"
	echo
	if [ "$ver" != "$EXPECTED_KERNEL_VER" ]; then
		echo "注意: Makefile 版本是 $ver，不是 ${EXPECTED_KERNEL_VER}。"
		echo
	fi
	echo "输入 YES 后才会 reset 并开始 apply；其他输入将退出。"
	echo "****************************************************************"
	local answer
	read -r answer || true
	if [ "$answer" != "YES" ]; then
		echo "未输入 YES，已取消。"
		exit 1
	fi
	echo
}

reset_to_baseline() {
	local repo=$1
	local head=$2
	local base_full=$3
	local name=${repo#$SDK_DIR/}

	if [ "$head" = "$base_full" ]; then
		echo "$name: already at baseline ${base_full:0:12}"
		return 0
	fi

	echo "$name: HEAD ${head:0:12} != baseline ${base_full:0:12}, reset --hard"
	git -C "$repo" reset --hard "$base_full"
}

apply_series() {
	local repo=$1
	local patchdir=$2
	local patches=()

	shopt -s nullglob
	patches=("$patchdir"/*.patch)
	shopt -u nullglob

	if [ ${#patches[@]} -eq 0 ]; then
		echo "skip ${repo#$SDK_DIR/}: no patches"
		return 0
	fi

	echo "apply ${#patches[@]} patches -> ${repo#$SDK_DIR/}"
	git -C "$repo" am "${patches[@]}"
}

echo "BSP: $BSP_DIR"
echo "SDK: $SDK_DIR"
echo "baselines: kernel=$kernel_base device=$device_base buildroot=$buildroot_base"
echo

prepare_repo "$SDK_DIR/kernel" "$kernel_base"
prepare_repo "$SDK_DIR/device/rockchip" "$device_base"
prepare_repo "$SDK_DIR/buildroot" "$buildroot_base"

kernel_head=$(git -C "$SDK_DIR/kernel" rev-parse HEAD)
kernel_base_full=$(git -C "$SDK_DIR/kernel" rev-parse "$kernel_base^{commit}")
device_head=$(git -C "$SDK_DIR/device/rockchip" rev-parse HEAD)
device_base_full=$(git -C "$SDK_DIR/device/rockchip" rev-parse "$device_base^{commit}")
buildroot_head=$(git -C "$SDK_DIR/buildroot" rev-parse HEAD)
buildroot_base_full=$(git -C "$SDK_DIR/buildroot" rev-parse "$buildroot_base^{commit}")

if [ "$kernel_head" != "$kernel_base_full" ] \
	|| [ "$device_head" != "$device_base_full" ] \
	|| [ "$buildroot_head" != "$buildroot_base_full" ]; then
	remind_baselines
fi

reset_to_baseline "$SDK_DIR/kernel" "$kernel_head" "$kernel_base_full"
reset_to_baseline "$SDK_DIR/device/rockchip" "$device_head" "$device_base_full"
reset_to_baseline "$SDK_DIR/buildroot" "$buildroot_head" "$buildroot_base_full"
echo

apply_series "$SDK_DIR/kernel" "$BSP_DIR/patches/kernel"
apply_series "$SDK_DIR/device/rockchip" "$BSP_DIR/patches/device/rockchip"
apply_series "$SDK_DIR/buildroot" "$BSP_DIR/patches/buildroot"
