

VERSION=5.1.5
PREFIX=linux
POSTFIX=mba
UNAME=$(VERSION)-$(POSTFIX)+
KERNEL=$(PREFIX)-$(UNAME)
MODULE=/lib/modules/$(UNAME)

BCE_SOURCES=https://github.com/MCMrARM/mbp2018-bridge-drv
BCE_VERSION=master

SPI_SOURCES=https://github.com/roadrunner2/macbook12-spi-driver
SPI_VERSION=mbp15

default: build

clean:
	rm -rf linux-module*

clean-all:
	rm -rf linux-*

$(KERNEL):
	@echo "-- Fetching Linux Kernel $(KERNEL)"
	git clone --depth=1 -b v$(VERSION) git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux $(KERNEL)
	(cd $(KERNEL); git checkout -b $(VERSION))
	cp setup-linux-mba.config $(KERNEL)/.config

config: $(KERNEL)
	(cd $(KERNEL); make menuconfig)

patch:
	@echo "-- Patching Linux Kernel $(KERNEL)"
	(cd $(KERNEL); git checkout -- drivers/*.c drivers/*.h)
	(cd $(KERNEL); git apply ../patch-linux-nvme.diff)
	(cd $(KERNEL); git apply ../patch-linux-bcm5974.diff)
	(cd $(KERNEL); git apply ../patch-linux-hid.diff)
	(cd $(KERNEL); git apply ../patch-linux-brcmfmac.diff)

linux-module-bce:
	@echo "-- Fetching BCE Module"
	git clone $(BCE_SOURCES) $@
	(cd $@; git checkout $(BCE_VERSION))

linux-module-applespi:
	@echo "-- Fetching SPI Module"
	git clone $(SPI_SOURCES) $@
	(cd $@; git checkout $(SPI_VERSION))


build: $(KERNEL) patch linux-module-bce linux-module-applespi
	@echo "-- Compiling Linux Kernel"
	(cd $(KERNEL); make)

build-module-bce: linux-module-bce
	@echo "-- Compiling BCE Module"
	make -C $(PWD)/$(KERNEL) M=$(PWD)/$^ modules

build-module-applespi: linux-module-applespi
	@echo "-- Compiling SPI Module"
	make -C $(PWD)/$(KERNEL) M=$(PWD)/$^ modules


install: install-kernel install-modules install-systemd

install-kernel: /boot/$(PREFIX)-$(POSTFIX) /etc/mkinitcpio.d/linux-mba.preset
	@echo "-- Installing Linux kernel modules"
	(cd $(KERNEL); make modules_install)
	@echo "-- Installing Linux kernel image"
	cp -f $(KERNEL)/arch/x86/boot/bzImage /boot/$(PREFIX)-$(POSTFIX)/vmlinuz-linux
	@echo "-- Installing Linux kernel initramfs"
	mkinitcpio -p linux-mba

install-modules: $(MODULE)/kernel/extra
	@echo "-- Installing bce module"
	cp -f linux-module-bce/bce.ko $(MODULE)/kernel/extra/
	@echo "-- Installing applespi module"
	cp -f linux-module-applespi/apple-ibridge.ko $(MODULE)/kernel/extra/
	cp -f linux-module-applespi/apple-ib-tb.ko   $(MODULE)/kernel/extra/
	cp -f linux-module-applespi/apple-ib-als.ko  $(MODULE)/kernel/extra/
	@echo "-- Updating Linux kernel module dependencies"
	depmod -a $(UNAME)

install-systemd:
	@echo "-- Installing systemd configuration"
	cp -f setup-etc-modules-load.d-bce.conf              /etc/modules-load.d/bce.conf
	cp -f setup-etc-modules-load.d-applespi.conf         /etc/modules-load.d/applespi.conf
	cp -f setup-usr-share-alsa-cards-apple_t2.conf       /usr/share/alsa/cards/AppleT2.conf
	cp -f setup-usr-lib-systemd-system-brcmfmac.service  /usr/lib/systemd/system/brcmfmac.service

systemd:
	@echo "-- Updating systemd environment"
	systemctl daemon-reload
	systemctl start brcmfmac
	systemctl enable brcmfmac
	systemctl restart iwd

/boot/$(PREFIX)-$(POSTFIX):
	mkdir -p $@

$(MODULE)/kernel/extra:
	mkdir -p $@

/etc/mkinitcpio.d/linux-mba.preset: setup-etc-mkinitcpio.d-linux-mba.preset
	cp -f $^ $@
