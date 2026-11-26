#!/bin/sh
# tspi action helpers. Sourced by S23tspiAction.
# Runtime dir holds logs and preview.sock; userdata dirs hold capture data.

TSPI_RUN_DIR=/var/run/tspi-action
TSPI_DATA_DIRS="/userdata/imu /userdata/firstFrame /userdata/picture /userdata/video"

export TSPI_PREVIEW_SOCK=/run/tspi-action/preview.sock
export QT_QPA_PLATFORM=tspi


# Create runtime and capture directories used by media-service / camera-ui.
tspi_action_prepare_dirs() {
	mkdir -p "$TSPI_RUN_DIR"
	if [ -d /userdata ]; then
		# shellcheck disable=SC2086
		mkdir -p $TSPI_DATA_DIRS
	fi
}

# Wait until rkaiq_3A_server is running. Returns 1 on timeout (~5s).
tspi_action_wait_rkaiq() {
	_i=0
	while ! pidof rkaiq_3A_server >/dev/null 2>&1; do
		_i=$((_i + 1))
		if [ "$_i" -ge 50 ]; then
			echo "rkaiq_3A_server not running, media-service not started"
			return 1
		fi
		sleep 0.1
	done
	sleep 0.1
	return 0
}

# Wait until preview.sock exists. Returns 1 on timeout (~10s).
tspi_action_wait_preview_sock() {
	_i=0
	while [ ! -S "$TSPI_PREVIEW_SOCK" ]; do
		_i=$((_i + 1))
		if [ "$_i" -ge 100 ]; then
			echo "preview.sock not ready, camera-ui not started"
			return 1
		fi
		sleep 0.1
	done
	return 0
}
