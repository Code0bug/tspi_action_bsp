#!/bin/sh
# Boot timing helpers. Sourced by rcS / S99z_boot_time.
# Config file /etc/tspiAction_debug:
#   - a line that is exactly "true"  -> enable the timed rcS path
#   - skip=NAME1 NAME2,...           -> init scripts skipped on the timed path
#   - '#' comment lines and blank lines may appear anywhere
# Only effective on the timed path.

TSPI_BOOT_LOG=/run/boot_service_times.log
TSPI_BOOT_PHASES=/run/boot_phases.env
TSPI_DEBUG_FLAG=/etc/tspiAction_debug

tspi_debug_enabled() {
	[ -f "$TSPI_DEBUG_FLAG" ] && grep -qx 'true' "$TSPI_DEBUG_FLAG"
}

# Skip list: all "skip=NAME..." lines in $TSPI_DEBUG_FLAG.
# Comment lines (#) and blank lines are ignored anywhere in the file;
# inline comments after values are stripped. Names are space/comma
# separated; multiple skip= lines are merged.
tspi_boot_skip_init() {
	TSPI_SKIP_LIST=
	[ -r "$TSPI_DEBUG_FLAG" ] || return 0
	TSPI_SKIP_LIST=$(sed -n \
		-e 's|#.*$||' \
		-e 's|^[[:space:]]*skip[[:space:]]*=[[:space:]]*||p' \
		"$TSPI_DEBUG_FLAG" \
		| tr -s ' \t\n,' '    ')
}

tspi_should_skip() {
	[ -n "$TSPI_SKIP_LIST" ] || return 1
	case " $TSPI_SKIP_LIST " in
		*" $1 "*) return 0 ;;
	esac
	return 1
}

tspi_boot_uptime() {
	awk '{print $1}' /proc/uptime
}

tspi_boot_log_init() {
	mkdir -p /run 2>/dev/null || true
	if ! : > "$TSPI_BOOT_LOG" 2>/dev/null; then
		TSPI_BOOT_LOG=/tmp/boot_service_times.log
		TSPI_BOOT_PHASES=/tmp/boot_phases.env
		: > "$TSPI_BOOT_LOG"
	fi
}

tspi_boot_log() {
	echo "boot_svc: $*"
	echo "$*" >> "$TSPI_BOOT_LOG"
}

# Seconds from kernel start until /sbin/init (from dmesg printk timestamps).
# Note: BusyBox awk gsub(/[\[\] ]/, ...) does NOT strip brackets; use sed instead.
tspi_kernel_boot_secs() {
	dmesg 2>/dev/null \
		| grep 'Run /sbin/init as init process' \
		| head -n1 \
		| sed -n 's/^\[ *\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p'
}

# Capture kernel / early userspace phases; write log + phases env file.
tspi_boot_capture_phases() {
	_pre_rcs=$(awk '{printf "%.2f", $1}' /proc/uptime)
	_kernel=$(tspi_kernel_boot_secs)

	if [ -n "$_kernel" ]; then
		_kernel=$(awk -v k="$_kernel" 'BEGIN { printf "%.2f", k }')
		_early=$(awk -v k="$_kernel" -v p="$_pre_rcs" 'BEGIN { printf "%.2f", p - k }')
		tspi_boot_log "$(printf "%-28s %6ss  (dmesg -> init)" "kernel" "$_kernel")"
		tspi_boot_log "$(printf "%-28s %6ss  (init sysinit -> rcS)" "early_userspace" "$_early")"
		{
			echo "KERNEL=$_kernel"
			echo "EARLY=$_early"
			echo "PRE_RCS=$_pre_rcs"
		} > "$TSPI_BOOT_PHASES"
	else
		tspi_boot_log "$(printf "%-28s %6ss  (kernel+sysinit, dmesg N/A)" "pre_rcS" "$_pre_rcs")"
		{
			echo "KERNEL="
			echo "EARLY="
			echo "PRE_RCS=$_pre_rcs"
		} > "$TSPI_BOOT_PHASES"
	fi
}

# Run one init script with start, record duration to log/console.
tspi_run_one_svc() {
	_i=$1
	_name=${_i##*/}
	_t0=$(tspi_boot_uptime)

	case "$_i" in
	*.sh)
		(
			trap - INT QUIT TSTP
			set start
			. "$_i"
		)
		;;
	*)
		"$_i" start
		;;
	esac

	_t1=$(tspi_boot_uptime)
	_dur=$(awk -v a="$_t0" -v b="$_t1" 'BEGIN { printf "%.2f", b - a }')
	tspi_boot_log "$(printf "%-28s %6ss  (uptime %ss)" "$_name" "$_dur" "$_t1")"
}

# Timed replacement for the stock rcS loop.
tspi_rcs_start_all() {
	tspi_boot_log_init
	tspi_boot_capture_phases
	tspi_boot_skip_init
	_boot0=$(tspi_boot_uptime)

	for _i in /etc/init.d/S??*; do
		[ ! -f "$_i" ] && continue
		_name=${_i##*/}
		if tspi_should_skip "$_name"; then
			tspi_boot_log "$(printf "%-28s %6ss  (skipped)" "$_name" "0.00")"
			continue
		fi
		tspi_run_one_svc "$_i"
	done

	_boot1=$(tspi_boot_uptime)
	_total=$(awk -v a="$_boot0" -v b="$_boot1" 'BEGIN { printf "%.2f", b - a }')
	tspi_boot_log "---- rcS total ${_total}s (uptime ${_boot1}s) ----"
	echo "RCS_TOTAL=$_total" >> "$TSPI_BOOT_PHASES"
	echo "BOOT_READY=$_boot1" >> "$TSPI_BOOT_PHASES"
}

tspi_boot_print_summary() {
	_uptime_s=$(awk '{printf "%.2f", $1}' /proc/uptime)
	echo "boot ready: ${_uptime_s}s (from /proc/uptime)"
	logger -t boot_time "boot ready: ${_uptime_s}s" 2>/dev/null || true

	if [ -f "$TSPI_BOOT_PHASES" ]; then
		# shellcheck disable=SC1090
		. "$TSPI_BOOT_PHASES"
		echo "boot_svc: ----- phases -----"
		[ -n "$KERNEL" ] && echo "boot_svc: kernel                       ${KERNEL}s  (dmesg -> init)"
		[ -n "$EARLY" ] && echo "boot_svc: early_userspace              ${EARLY}s  (init sysinit -> rcS)"
		[ -n "$PRE_RCS" ] && echo "boot_svc: pre_rcS                      ${PRE_RCS}s  (kernel + early)"
		echo "boot_svc: ----------------------"
	elif [ -f /tmp/boot_phases.env ]; then
		. /tmp/boot_phases.env
		echo "boot_svc: ----- phases -----"
		[ -n "$KERNEL" ] && echo "boot_svc: kernel                       ${KERNEL}s  (dmesg -> init)"
		[ -n "$EARLY" ] && echo "boot_svc: early_userspace              ${EARLY}s  (init sysinit -> rcS)"
		[ -n "$PRE_RCS" ] && echo "boot_svc: pre_rcS                      ${PRE_RCS}s  (kernel + early)"
		echo "boot_svc: ----------------------"
	fi

	if [ -f "$TSPI_BOOT_LOG" ]; then
		echo "boot_svc: ===== per-service times ($TSPI_BOOT_LOG) ====="
		cat "$TSPI_BOOT_LOG"
		echo "boot_svc: ====================================="
	elif [ -f /tmp/boot_service_times.log ]; then
		echo "boot_svc: ===== per-service times (/tmp/boot_service_times.log) ====="
		cat /tmp/boot_service_times.log
		echo "boot_svc: ====================================="
	fi
}
