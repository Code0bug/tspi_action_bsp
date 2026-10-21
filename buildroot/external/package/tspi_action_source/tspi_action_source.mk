################################################################################
#
# tspi_action_source
#
################################################################################

TSPI_ACTION_SOURCE_VERSION = edd10610cb9ef7f7bcaf06b00b0311e8aed80485
TSPI_ACTION_SOURCE_SITE = git@gitee.com:lzp1733149755/tspi_action_source.git
TSPI_ACTION_SOURCE_SITE_METHOD = git
TSPI_ACTION_SOURCE_LICENSE = Proprietary

TSPI_ACTION_SOURCE_DEPENDENCIES = \
	qt5base \
	opencv4 \
	ffmpeg \
	rockchip-rga

define TSPI_ACTION_SOURCE_CONFIGURE_CMDS
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
