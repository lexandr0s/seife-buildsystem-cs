###############################################################
# stuff needed to build kernel modules(very experimental...)  #
# DO NOT TRY TO USE THIS KERNEL, IT WILL MOST LIKELY NOT WORK #
#                                                             #
# ATTENTION: the modules will probably only work with a       #
#            crosstool-built arm-cx2450x-linux-gnueabi-gcc,   #
#            or to be more precise, with the same compiler    #
#            that also built the running kernel!              #
#                                                             #
# modules are installed in $(TARGETPREFIX)/mymodules and can  #
# be picked from there.                                       #
###############################################################

ifeq ($(PLATFORM), tripledragon)
KVERSION_FULL = 2.6.12
K_DEP = $(D)/tdkernel
endif
ifeq ($(PLATFORM), coolstream)
KVERSION = 2.6.26.8
KVERSION_FULL = $(KVERSION)-nevis
K_DEP = $(D)/cskernel
endif
ifeq ($(PLATFORM), spark)
KVERSION = 2.6.32.46
KVERSION_FULL = $(KVERSION)_stm24$(PATCH_STR)
endif
SOURCE_MODULE = $(TARGETPREFIX)/mymodules/lib/modules/$(KVERSION_FULL)
TARGET_MODULE = $(TARGETPREFIX)/lib/modules/$(KVERSION_FULL)

ifeq ($(PLATFORM), tripledragon)
############################################################
# stuff needed to build a td kernel (very experimental...) #
############################################################
K_GCC_PATH ?= $(CROSS_BASE)/gcc-3.4.1-glibc-2.3.2/powerpc-405-linux-gnu/bin

$(BUILD_TMP)/linux-2.6.12: $(ARCHIVE)/linux-2.6.12.tar.bz2 | $(TARGETPREFIX)
	tar -C $(BUILD_TMP) -xf $(ARCHIVE)/linux-2.6.12.tar.bz2
	set -e; cd $(BUILD_TMP)/linux-2.6.12; \
		tar xvpf $(TD_SVN)/ARMAS/linux-enviroment/kernel/td_patchset_2.6.12.tar.bz2; \
		patch -p1 < kdiff_00_all.diff; \
		patch -p1 < $(PATCHES)/kernel-fix-td-build.diff; \
		mkdir -p include/stb/; \
		cp $(TARGETPREFIX)/include/hardware/os/os-generic.h include/stb -av; \
		cp $(TARGETPREFIX)/include/hardware/os/registerio.h include/stb -av; \
		cp $(TARGETPREFIX)/include/hardware/os/pversion.h include/stb -av; \
		cp $(TARGETPREFIX)/include/hardware/os/os-types.h include/stb -av; \
		cp $(PATCHES)/kernel.config-td .config

$(SOURCE_DIR)/td-dvb-wrapper:
	git clone $(GITORIOUS)/seife/td-dvb-wrapper.git $@

# td-dvb-wrapper does not strictly need tdkernel to be built (the source directory
# with some preparation would be ok), but we'd be missing the module symbols.
td-dvb-wrapper: $(SOURCE_DIR)/td-dvb-wrapper $(D)/tdkernel
	PATH=$(K_GCC_PATH):$(PATH) make find-powerpc-405-linux-gnu-gcc
	set -e; cd $(BUILD_TMP)/linux-2.6.12; \
		export PATH=$(BASE_DIR)/ccache:$(K_GCC_PATH):$(PATH); \
		make ARCH=ppc CROSS_COMPILE=powerpc-405-linux-gnu- M=$(SOURCE_DIR)/td-dvb-wrapper ;\
		make ARCH=ppc CROSS_COMPILE=powerpc-405-linux-gnu- M=$(SOURCE_DIR)/td-dvb-wrapper \
			INSTALL_MOD_PATH=$(TARGETPREFIX)/mymodules modules_install

$(TARGET_MODULE)/extra/td-dvb-frontend.ko: td-dvb-wrapper
	install -m 644 -D $(SOURCE_MODULE)/extra/td-dvb-frontend.ko $@

ifeq ($(TD_COMPILER), new)
TDK_DEPS = $(K_GCC_PATH)/powerpc-405-linux-gnu-gcc
endif
$(D)/tdkernel: $(TDK_DEPS) | $(BUILD_TMP)/linux-2.6.12
	set -e; cd $(BUILD_TMP)/linux-2.6.12; \
		export PATH=$(BASE_DIR)/ccache:$(K_GCC_PATH):$(PATH); \
		make	ARCH=ppc CROSS_COMPILE=powerpc-405-linux-gnu- oldconfig; \
		$(MAKE)	ARCH=ppc CROSS_COMPILE=powerpc-405-linux-gnu- modules; \
		make	ARCH=ppc CROSS_COMPILE=powerpc-405-linux-gnu- \
			INSTALL_MOD_PATH=$(TARGETPREFIX)/mymodules modules_install
	$(MAKE) fuse-driver
	touch $@

# 2.7.5 is the last version which has a kernel module packaged...
fuse-driver: $(ARCHIVE)/fuse-2.7.5.tar.gz
	$(UNTAR)/fuse-2.7.5.tar.gz
	set -e; cd $(BUILD_TMP)/fuse-2.7.5/; \
		$(PATCH)/fuse-kernel-add-devfs.diff ; \
		cd kernel; \
		export PATH=$(BASE_DIR)/ccache:$(K_GCC_PATH):$(PATH); \
		./configure --with-kernel=$(BUILD_TMP)/linux-2.6.12 --enable-kernel-module; \
		$(MAKE) ARCH=ppc CROSS_COMPILE=powerpc-405-linux-gnu- \
			DESTDIR=$(TARGETPREFIX)/mymodules install
	$(REMOVE)/fuse-2.7.5

kernelmenuconfig: $(BUILD_TMP)/linux-2.6.12 $(TDK_DEPS)
	set -e; cd $(BUILD_TMP)/linux-2.6.12; \
		export PATH=$(BASE_DIR)/ccache:$(K_GCC_PATH):$(PATH); \
		make	ARCH=ppc CROSS_COMPILE=powerpc-405-linux-gnu- menuconfig

# try to build a compiler that's similar to the one that built the kernel...
# this should be only needed if you are using e.g. an external toolchain with gcc4
kernelgcc: $(K_GCC_PATH)/powerpc-405-linux-gnu-gcc

# powerpc-405-linux-gnu-gcc is the "marker file" for crosstool
$(K_GCC_PATH)/powerpc-405-linux-gnu-gcc: | $(ARCHIVE)/crosstool-0.43.tar.gz
	@if test "$(shell basename $(shell readlink /bin/sh))" != bash; then \
		echo "crosstool needs bash as /bin/sh!. Please fix."; false; fi
	tar -C $(BUILD_TMP) -xzf $(ARCHIVE)/crosstool-0.43.tar.gz
	cp $(PATCHES)/glibc-2.3.3-allow-gcc-4.0-configure.patch $(BUILD_TMP)/crosstool-0.43/patches/glibc-2.3.2
	cp $(PATCHES)/glibc-2.3.6-new_make.patch                $(BUILD_TMP)/crosstool-0.43/patches/glibc-2.3.2
	set -e; unset CONFIG_SITE; cd $(BUILD_TMP)/crosstool-0.43; \
		NUM_CPUS=$$(expr `grep -c ^processor /proc/cpuinfo` \* 2); \
		MEM_512M=$$(awk '/MemTotal/ {M=int($$2/1024/512); print M==0?1:M}' /proc/meminfo); \
		test $$NUM_CPUS -gt $$MEM_512M && NUM_CPUS=$$MEM_512M; \
		test $$NUM_CPUS = 0 && NUM_CPUS=1; \
		$(PATCH)/crosstool-0.43-fix-build-with-FORTIFY_SOURCE-default.diff; \
		export TARBALLS_DIR=$(ARCHIVE); \
		export RESULT_TOP=$(CROSS_BASE); \
		export GCC_LANGUAGES="c"; \
		export PARALLELMFLAGS="-j $$NUM_CPUS"; \
		export QUIET_EXTRACTIONS=y; \
		eval `cat powerpc-405.dat gcc-3.4.1-glibc-2.3.2.dat` LINUX_DIR=linux-2.6.12 sh all.sh --notest
	$(REMOVE)/crosstool-0.43
endif

ifeq ($(PLATFORM), coolstream)
$(BUILD_TMP)/linux-$(KVERSION): $(PATCHES)/linux-2.6.26.8-new-make.patch \
			$(PATCHES)/coolstream/linux-2.6.26.8-cnxt.diff
	tar -C $(BUILD_TMP) -xf $(ARCHIVE)/linux-$(KVERSION).tar.bz2
	set -e; cd $@ ; \
		$(PATCH)/coolstream/linux-2.6.26.8-cnxt.diff ; \
		for i in $(PATCHES)/cskernel/*; do \
			echo "applying $$i..." ;patch -p4 -i $$i; \
		done ; \
		for i in $(PATCHES)/cskernel-extra/*; do \
			echo "applying $$i..." ;patch -p1 -i $$i; \
		done

# this would be a way to build custom configs, but it is not nice, so not used yet.
# CS_K_Y = CONFIG_HID_SUPPORT
# CS_K_M = CONFIG_HID
# CS_K_N = CONFIG_HID_DEBUG
# CS_K_N += CONFIG_HIDRAW
# CS_K_M += CONFIG_USB_HID
# CS_K_N += CONFIG_USB_HIDINPUT_POWERBOOK
# CS_K_N += CONFIG_HID_FF
# CS_K_N += CONFIG_USB_HIDDEV
# CS_K_N += CONFIG_USB_KBD
# CS_K_N += CONFIG_USB_MOUSE
# CS_K_Y += CONFIG_USB_EZUSB
# CS_K_Y += CONFIG_USB_SERIAL_GENERIC
# CS_K_M += CONFIG_USB_SERIAL_BELKIN
# CS_K_M += CONFIG_USB_SERIAL_CP2101
# CS_K_M += CONFIG_USB_SERIAL_KEYSPAN_PDA
# CS_K_M += CONFIG_USB_SERIAL_MCT_U232
# CS_K_M += CONFIG_AUTOFS4_FS
# CS_K_M += CONFIG_ISO9660_FS
# CS_K_Y += CONFIG_JOLIET
# CS_K_N += CONFIG_ZISOFS
# CS_K_M += CONFIG_UDF_FS
# CS_K_Y += CONFIG_UDF_NLS
# CS_K_M += CONFIG_NFSD
# CS_K_Y += CONFIG_NFSD_V3
# CS_K_N += CONFIG_NFSD_V3_ACL
# CS_K_N += CONFIG_NFSD_V4
# CS_K_M += CONFIG_EXPORTFS
# 		for i in $(CS_K_Y); do sed -i "/^\(# \)*$$i[= ]/d" .config; done && \
# 		for i in $(CS_K_Y); do echo "$$i=y" >> .config; done && \
# 		for i in $(CS_K_M); do sed -i "/^\(# \)*$$i[= ]/d" .config; done && \
# 		for i in $(CS_K_M); do echo "$$i=m" >> .config; done && \
# 		for i in $(CS_K_N); do sed -i "/^\(# \)*$$i[= ]/d" .config; done && \
# 		for i in $(CS_K_N); do echo "# $$i is not set" >> .config; done && \

$(HOSTPREFIX)/bin/mkimage: cs-uboot

K_SRCDIR ?= $(SOURCE_DIR)/linux
K_OBJ = $(BUILD_TMP)/kobj

$(K_SRCDIR):
	@echo
	@echo "you need to create "$(subst $(BASE_DIR)/,"",$(K_SRCDIR))" first."
	@echo "there are several ways to do this:"
	@echo "* 'make kernel-svn'   downloads the kernel from the Coolstream SVN"
	@echo "                      and creates a symlink"
	@echo "* 'make kernel-patch' extracts a tarball and patches it with the"
	@echo "                      patches from archive-patches"
	@echo "note that kernel-svn is usually safer and more current."
	@echo
	@false

kernel-svn: $(SOURCE_DIR)/svn/THIRDPARTY/kernel
	rm -f $(SOURCE_DIR)/linux
	ln -s svn/THIRDPARTY/kernel/linux-2.6.26.8-cnxt $(SOURCE_DIR)/linux

kernel-patch: $(BUILD_TMP)/linux-$(KVERSION)
	rm -f $(SOURCE_DIR)/linux
	ln -s $(BUILD_TMP)/linux-$(KVERSION) $(SOURCE_DIR)/linux

$(K_OBJ)/.config: $(PATCHES)/kernel.config
	mkdir -p $(K_OBJ)
	cp $(PATCHES)/kernel.config $@

$(D)/cskernel: $(K_SRCDIR) $(K_OBJ)/.config | $(HOSTPREFIX)/bin/mkimage
ifeq ($(K_SRCDIR), $(SOURCE_DIR)/linux)
	# we need this to build out of tree - kbuild complains otherwise
	# whoever sets K_SRCDIR to something else should better know what he's doing anyway
	rm -f $(SOURCE_DIR)/linux/.config
endif
	set -e; cd $(SOURCE_DIR)/linux; \
		make ARCH=arm CROSS_COMPILE=$(TARGET)- silentoldconfig O=$(K_OBJ)/; \
		$(MAKE) ARCH=arm CROSS_COMPILE=$(TARGET)- O=$(K_OBJ)/; \
		make ARCH=arm CROSS_COMPILE=$(TARGET)- INSTALL_MOD_PATH=$(TARGETPREFIX)/mymodules \
			modules_install O=$(K_OBJ)/
	cd $(BUILD_TMP) && \
		mkimage -A arm -O linux -T kernel -a 0x17048000 -e 0x17048000 -C none \
			-n "Coolstream HDx Kernel (zImage)" -d $(K_OBJ)/arch/arm/boot/zImage zImage.img
	cd $(BUILD_TMP) && \
		mkimage -A arm -O linux -T kernel -a 0x17048000 -e 0x17048000 -C none \
			-n "Coolstream HDx Kernel" -d $(K_OBJ)/arch/arm/boot/Image Image.img
	: touch $@

kernelmenuconfig: $(K_SRCDIR) $(K_OBJ)/.config
ifeq ($(K_SRCDIR), $(SOURCE_DIR)/linux)
	rm -f $(SOURCE_DIR)/linux/.config
endif
	cd $(SOURCE_DIR)/linux && \
		make ARCH=arm CROSS_COMPILE=$(TARGET)- menuconfig O=$(K_OBJ)/

# yes, it's not the kernel. but it's not enough to warrant an extra file
$(D)/cs-uboot: $(ARCHIVE)/u-boot-2009.03.tar.bz2 $(PATCHES)/coolstream/u-boot-2009.3-CST.diff
	$(REMOVE)/u-boot-2009.03
	$(UNTAR)/u-boot-2009.03.tar.bz2
	set -e; cd $(BUILD_TMP)/u-boot-2009.03; \
		$(PATCH)/coolstream/u-boot-2009.3-CST.diff; \
		make coolstream_hdx_config; \
		$(MAKE)
	cp -a $(BUILD_TMP)/u-boot-2009.03/tools/mkimage $(HOSTPREFIX)/bin
	touch $@
endif

ifeq ($(PLATFORM), spark)
TMP_KDIR=$(BUILD_TMP)/linux-2.6.32
TDT_PATCHES=$(SOURCE_DIR)/pingulux-git/tdt/cvs/cdk/Patches

$(BUILD_TMP)/linux-$(KVERSION_FULL): \
		$(STL_ARCHIVE)/stlinux24-host-kernel-source-sh4-2.6.32.46_stm24_0209-209.src.rpm \
		$(PATCHES)/linux-2.6.26.8-new-make.patch \
		$(PATCHES)/coolstream/linux-2.6.26.8-cnxt.diff
	rpm $(DRPM) --nosignature --ignorearch --force --nodeps -Uhv --noscripts \
		$(STL_ARCHIVE)/stlinux24-host-kernel-source-sh4-2.6.32.46_stm24_0209-209.src.rpm
	tar -C $(BUILD_TMP) -xf $(STLINUX_DIR)/SOURCES/linux-2.6.32.tar.bz2; \
	set -e; cd $(TMP_KDIR); \
		bzcat $(STLINUX_DIR)/SOURCES/linux-2.6.32.46.patch.bz2 | patch -p1 ;\
		bzcat $(STLINUX_DIR)/SOURCES/linux-2.6.32.46_stm24_sh4_0209.patch.bz2 | patch -p1; \
		for i in $(SPARK_PATCHES_24); do \
			echo "==> Applying Patch: $$i"; \
			patch -p1 -i $(TDT_PATCHES)/$$i; \
		done; \
		cp $(TDT_PATCHES)/linux-sh4-2.6.32.46-0209_spark.config .config;
	$(MAKE) -C $(TMP_KDIR) ARCH=sh oldconfig
	$(MAKE) -C $(TMP_KDIR) ARCH=sh include/asm
	$(MAKE) -C $(TMP_KDIR) ARCH=sh include/linux/version.h
	cd $(BUILD_TMP) && mv linux-2.6.32 linux-$(KVERSION_FULL)


sparkkernel: $(BUILD_TMP)/linux-$(KVERSION_FULL)
	set -e; cd $(BUILD_TMP)/linux-$(KVERSION_FULL); \
		export PATH=$(CROSS_BASE)/host/bin:$(PATH); \
		cp $(TDT_PATCHES)/linux-sh4-2.6.32.46-0209_spark.config .config; \
		sed -i "s#^\(CONFIG_EXTRA_FIRMWARE_DIR=\).*#\1\"$(SOURCE_DIR)/pingulux-git/tdt/cvs/cdk/integrated_firmware\"#" .config; \
		$(MAKE) ARCH=sh CROSS_COMPILE=$(TARGET)- uImage modules

$(TARGETPREFIX)/include/linux/dvb:
	mkdir -p $@

$(BUILD_TMP)/driver: $(TARGETPREFIX)/include/linux/dvb
	cp -a $(SOURCE_DIR)/pingulux-git/tdt/cvs/driver $(BUILD_TMP)
	set -e; cd $(BUILD_TMP)/driver; \
		rm -f player2 multicom; \
		ln -s player2_191 player2; \
		ln -s multicom-3.2.4_rc3 multicom; \
		rm -f .config; printf "export CONFIG_PLAYER_191=y\nexport CONFIG_MULTICOM324=y\n" > .config; \
		cp player2/linux/include/linux/dvb/stm_ioctls.h $(TARGETPREFIX)/include/linux/dvb; \
		cd include; \
		rm -f stmfb player2 multicom; \
		ln -s stmfb-3.1_stm24_0102 stmfb; \
		ln -s player2_179 player2; \
		ln -s ../multicom-3.2.4_rc3/include multicom; \
		cd ../stgfb; \
		rm -f stmfb; \
		ln -s stmfb-3.1_stm24_0102 stmfb; \
		cp -a stmfb/linux/drivers/video/stmfb.h $(TARGETPREFIX)/include/linux
	# disable wireless build
	sed -i 's/^\(obj-y.*+= wireless\)/# \1/' $(BUILD_TMP)/driver/Makefile

sparkdriver: $(BUILD_TMP)/driver
	$(MAKE) -C $(BUILD_TMP)/driver ARCH=sh \
		KERNEL_LOCATION=$(BUILD_TMP)/linux-$(KVERSION_FULL) \
		SPARK=spark \
		PLAYER191=player191 \
		CROSS_COMPILE=$(TARGET)-

endif

# rule for the autofs4 module - needed by the automounter
# installs the already built module into the "proper" path
$(TARGET_MODULE)/kernel/fs/autofs4/autofs4.ko: $(K_DEP)
	install -m 644 -D $(SOURCE_MODULE)/kernel/fs/autofs4/autofs4.ko $@
	make depmod

# input drivers: usbhid, evdev
inputmodules: $(D)/cskernel
	mkdir -p $(TARGET_MODULE)/kernel/drivers
	cp -a	$(SOURCE_MODULE)/kernel/drivers/input $(SOURCE_MODULE)/kernel/drivers/hid \
		$(TARGET_MODULE)/kernel/drivers/
	make depmod

# helper target...
depmod:
	PATH=$(PATH):/sbin:/usr/sbin depmod -b $(TARGETPREFIX) $(KVERSION_FULL)
	mv $(TARGET_MODULE)/modules.dep $(TARGET_MODULE)/.modules.dep
	rm $(TARGET_MODULE)/modules.*
	mv $(TARGET_MODULE)/.modules.dep $(TARGET_MODULE)/modules.dep
