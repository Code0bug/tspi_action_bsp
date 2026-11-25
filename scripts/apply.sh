#!/bin/bash
# Ensure kernel / device/rockchip / buildroot are at VERSION
# baselines, then replay BSP patches. Resets these repos if they are not on baseline.
set -euo pipefail

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

ensure_baseline() {
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

	local head base_full
	head=$(git -C "$repo" rev-parse HEAD)
	base_full=$(git -C "$repo" rev-parse "$base^{commit}")

	# Drop an interrupted git am, if any
	if [ -d "$repo/.git/rebase-apply" ]; then
		echo "$name: abort interrupted git am"
		git -C "$repo" am --abort || true
	fi

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

ensure_baseline "$SDK_DIR/kernel" "$kernel_base"
ensure_baseline "$SDK_DIR/device/rockchip" "$device_base"
ensure_baseline "$SDK_DIR/buildroot" "$buildroot_base"
echo

apply_series "$SDK_DIR/kernel" "$BSP_DIR/patches/kernel"
apply_series "$SDK_DIR/device/rockchip" "$BSP_DIR/patches/device"
apply_series "$SDK_DIR/buildroot" "$BSP_DIR/patches/buildroot"

echo
echo "done."
