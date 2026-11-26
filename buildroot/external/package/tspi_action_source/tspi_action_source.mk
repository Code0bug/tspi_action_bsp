################################################################################
#
# tspi_action_source
#
################################################################################

TSPI_ACTION_SOURCE_VERSION = 1ee67dc64303f13fe18b2b38c4529ec34a14ba80
TSPI_ACTION_SOURCE_SITE = git@gitee.com:lzp1733149755/tspi_action_source.git
TSPI_ACTION_SOURCE_SITE_METHOD = git
TSPI_ACTION_SOURCE_LICENSE = Proprietary

TSPI_ACTION_SOURCE_DEPENDENCIES = \
	qt5base \
	opencv4 \
	ffmpeg \
	rockchip-rga \
	rockchip-mpp \
	libdrm \
	alsa-lib \
	dbus

# Upstream is a CMake project. Buildroot's toolchain file already
# cross-compiles for this output; do not pass cmake/toolchains/rk3566-buildroot.cmake.
# Install layout follows the project: /usr/bin/camera-ui, /usr/bin/media-service,
# /usr/lib/libmedia_hal.so, /usr/lib/qt/plugins/platforms/libqtspi.so,
# /etc/dbus-1/system.d/com.tspi.MediaService.conf.
TSPI_ACTION_SOURCE_SUPPORTS_IN_SOURCE_BUILD = NO
TSPI_ACTION_SOURCE_CONF_OPTS = \
	-DCMAKE_INSTALL_LIBDIR=lib \
	-DCMAKE_INSTALL_SYSCONFDIR=/etc

$(eval $(cmake-package))
