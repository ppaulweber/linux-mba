
VERSION=5.1.5
PREFIX=linux
POSTFIX=mba
KERNEL=$(PREFIX)-$(VERSION)-$(POSTFIX)+
MODULE=/lib/modules/$(VERSION)-$(POSTFIX)

default: build

$(KERNEL):
	@echo "-- Fetching Linux Kernel $(KERNEL)"
	git clone --depth=1 -b v$(VERSION) git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux $(KERNEL)
	(cd $(KERNEL); git checkout -b $(VERSION))
	cp setup-linux-mba.config $(KERNEL)/.config
	@echo "-- Patching Linux Kernel $(KERNEL)"
	(cd $@; git apply ../patch-linux-nvme.diff)

bce:
	@echo "-- Fetching BCE Module"
	git clone https://github.com/MCMrARM/mbp2018-bridge-drv $@
	(cd $@; git checkout 398566a6bab692fba03634de9b46e27bdb4e4356)

config: $(KERNEL)
	(cd $(KERNEL); make menuconfig)

build: $(KERNEL) bce
	@echo "-- Compiling Linux Kernel"
	(cd $(KERNEL); make)
	@echo "-- Compiling BCE Module"
	make -C $(PWD)/$(KERNEL) M=$(PWD)/bce modules

install: /boot/$(PREFIX)-$(POSTFIX) /boot/$(PREFIX)-$(POSTFIX)/vmlinuz-linux /etc/mkinitcpio.d/linux-mba.preset /etc/modules-load.d/bce.conf
	@echo "-- Installing Linux Kernel Modules"
	(cd $(KERNEL); make modules_install)
	@echo "-- Installing Linux Kernel Image"
	cp $(KERNEL)/arch/x86/boot/bzImage /boot/$(PREFIX)-$(POSTFIX)/vmlinuz-linux
	@echo "-- Installing Linux Kernel Initramfs"
	mkinitcpio -p linux-mba
	@echo "-- Installing BCE Module"
	mkdir -p /kernel/extra
	cp bce/bce.ko $(SOURCES)/kernel/extra/
	depmod -a

/boot/$(PREFIX)-$(POSTFIX):
	mkdir -p $@

/boot/$(PREFIX)-$(POSTFIX)/vmlinuz-linux: $(KERNEL)/arch/x86/boot/bzImage
	cp $^ $@

/etc/modules-load.d/bce.conf: setup-etc-modules-load.d-bce.conf
	cp $^ $@

/etc/mkinitcpio.d/linux-mba.preset: setup-etc-mkinitcpio.d-linux-mba.preset
	cp $^ $@
