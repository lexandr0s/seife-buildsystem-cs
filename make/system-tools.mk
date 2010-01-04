#Makefile to build system tools

$(DEPDIR)/rsync:
	$(UNTAR)/rsync-3.0.6.tar.gz
	pushd $(BUILD_TMP)/rsync-3.0.6 && \
		$(CONFIGURE) --prefix= --build=$(BUILD) --host=$(TARGET) --mandir=$(BUILD_TMP)/.remove && \
		$(MAKE) all && \
		make install prefix=$(TARGETPREFIX)
	$(REMOVE)/rsync-3.0.6
	$(REMOVE)/.remove
	touch $@

$(DEPDIR)/procps: libncurses
	$(UNTAR)/procps-3.2.7.tar.gz
	pushd $(BUILD_TMP)/procps-3.2.7 && \
		$(PATCH)/procps-3.2.7-avoid-ICE-with-gcc-4.3.2-arm.diff && \
		make CC=$(TARGET)-gcc LDFLAGS="$(LD_FLAGS)" \
			CPPFLAGS="-pipe -O2 -g -I$(TARGETPREFIX)/include -I$(TARGETPREFIX)/include/ncurses -D__GNU_LIBRARY__" \
			top ps/ps && \
		rm -f $(TARGETPREFIX)/bin/ps && \
		mkdir -p $(TARGETPREFIX)/bin && \
		install -m 755 top ps/ps $(TARGETPREFIX)/bin && \
		install -m 755 proc/libproc-3.2.7.so $(TARGETPREFIX)/lib
	$(REMOVE)/procps-3.2.7
	touch $@

$(DEPDIR)/busybox:
	$(UNTAR)/busybox-1.15.2.tar.bz2
	pushd $(BUILD_TMP)/busybox-1.15.2 && \
		cp $(PATCHES)/busybox-hd1.config .config && \
		sed -i -e 's#^CONFIG_PREFIX.*#CONFIG_PREFIX="$(TARGETPREFIX)"#' .config && \
		$(MAKE) all  CROSS_COMPILE=$(TARGET)- CFLAGS_EXTRA="$(TARGET_CFLAGS)" && \
		make install CROSS_COMPILE=$(TARGET)- CFLAGS_EXTRA="$(TARGET_CFLAGS)"
	$(REMOVE)/busybox-1.15.2
	touch $@

$(DEPDIR)/strace:
	$(UNTAR)/strace-4.5.19.tar.bz2
	pushd $(BUILD_TMP)/strace-4.5.19 && \
		CFLAGS="-W -Wall $(TARGET_CFLAGS)" \
		CPPFLAGS="-I$(TARGETPREFIX)/include" \
		CXXFLAGS="-W -Wall $(TARGET_CXXFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS)" \
		./configure --prefix= --build=$(BUILD) --host=$(TARGET) --mandir=$(BUILD_TMP)/.remove && \
		$(MAKE) all && \
		make install prefix=$(TARGETPREFIX)
	$(REMOVE)/strace-4.5.19
	$(REMOVE)/.remove
	touch $@

$(DEPDIR)/e2fsprogs:
	$(UNTAR)/e2fsprogs-1.41.9.tar.gz
	cd $(BUILD_TMP)/e2fsprogs-1.41.9 && \
		ln -sf /bin/true ./ldconfig && \
		CC=$(TARGET)-gcc \
		RANLIB=$(TARGET)-ranlib \
		CFLAGS="-Os -msoft-float" \
		LDFLAGS="$(TARGET_LDFLAGS)" \
		PATH=$(BUILD_TMP)/e2fsprogs-1.41.9:$(PATH) \
		./configure \
			--build=$(BUILD) \
			--host=$(TARGET) \
			--target=$(TARGET) \
			--prefix=$(TARGETPREFIX) \
			--mandir=$(BUILD_TMP)/.remove \
			--with-cc=$(TARGET)-gcc \
			--with-linker=$(TARGET)-ld \
			--disable-evms \
			--enable-elf-shlibs \
			--enable-htree \
			--disable-profile \
			--disable-e2initrd-helper \
			--disable-swapfs \
			--disable-debugfs \
			--disable-imager \
			--disable-resizer \
			--disable-uuidd \
			--enable-dynamic-e2fsck \
			--enable-fsck \
			--with-gnu-ld \
			--disable-nls && \
		$(MAKE) libs progs && \
		$(MAKE) install-libs && \
		$(MAKE) install-progs-recursive
	$(REMOVE)/e2fsprogs-1.41.9
	$(REMOVE)/.remove
	touch $@

#  NOTE:
#  gdb built for target or local-PC
$(DEPDIR)/gdb:
	$(UNTAR)/gdb-7.0.tar.bz2
	pushd $(BUILD_TMP)/gdb-7.0 && \
		$(BUILDENV) \
		./configure \
			--nfp --disable-werror \
			--prefix= \
			--mandir=$(BUILD_TMP)/.remove \
			--infodir=$(BUILD_TMP)/.remove \
			--build=$(BUILD) --host=$(TARGET) && \
		$(MAKE) all-gdb && \
		make install-gdb prefix=$(TARGETPREFIX) && \
	$(REMOVE)/gdb-7.0
	$(REMOVE)/.remove
	touch $@

#  NOTE:
#  gdb-remote built for local-PC or target
$(DEPDIR)/gdb-remote:
	$(UNTAR)/gdb-7.0.tar.bz2
	pushd $(BUILD_TMP)/gdb-7.0 && \
		./configure \
			--nfp --disable-werror \
			--prefix=$(HOSTPREFIX) \
			--build=$(BUILD) --host=$(BUILD) --target=$(TARGET) && \
		$(MAKE) all-gdb && \
		make install-gdb && \
	$(REMOVE)/gdb-7.0
	touch $@

$(DEPDIR)/skeleton:
	cp -a skel-root/* $(TARGETPREFIX)/
