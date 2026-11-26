TARGET := iphone:clang:latest:15.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CCiOS18
CCiOS18_FILES = Tweak.xm
CCiOS18_CFLAGS = -fobjc-arc
CCiOS18_FRAMEWORKS = UIKit CoreFoundation CFNetwork QuartzCore CoreImage
CCiOS18_PRIVATE_FRAMEWORKS = ControlCenterServices SpringBoardUIServices

include $(THEOS_MAKE_PATH)/tweak.mk
