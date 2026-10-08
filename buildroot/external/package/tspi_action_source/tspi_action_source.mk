################################################################################
#
# tspi_action_source
#
################################################################################

TSPI_ACTION_SOURCE_VERSION = master
TSPI_ACTION_SOURCE_SITE = git@gitee.com:lzp1733149755/tspi_action_source.git
TSPI_ACTION_SOURCE_SITE_METHOD = git
TSPI_ACTION_SOURCE_LICENSE = Proprietary

TSPI_ACTION_SOURCE_DEPENDENCIES = \
	qt5base \
	opencv4 \
	ffmpeg \
	rockchip-rga

# .pro 里写死了本机 sysroot，编包时改成当前 STAGING_DIR
define TSPI_ACTION_SOURCE_CONFIGURE_CMDS
	$(SED) 's|/home/lzp/linux_sdk/buildroot/output/rockchip_rk3566/host/aarch64-buildroot-linux-gnu/sysroot|$(STAGING_DIR)|g' \
		$(@D)/ai-cam-ui-widget.pro
	cd $(@D); $(TARGET_MAKE_ENV) $(HOST_DIR)/bin/qmake ai-cam-ui-widget.pro
endef

define TSPI_ACTION_SOURCE_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)
endef

define TSPI_ACTION_SOURCE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/ai-cam-ui-widget \
		$(TARGET_DIR)/root/ai-cam-ui-widget
endef

$(eval $(generic-package))
