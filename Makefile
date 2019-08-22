
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

patch:
	@echo "-- Patching Linux Kernel $(KERNEL)"
	(cd $(KERNEL); git checkout -- drivers/*.c drivers/*.h)
	(cd $(KERNEL); git apply ../patch-linux-nvme.diff)
	(cd $(KERNEL); git apply ../patch-linux-bcm5974.diff)
	(cd $(KERNEL); git apply ../patch-linux-hid.diff)
	(cd $(KERNEL); git apply ../patch-linux-brcmfmac.diff)

bce:
	@echo "-- Fetching BCE Module"
	git clone https://github.com/MCMrARM/mbp2018-bridge-drv $@
	(cd $@; git checkout 65a09949c2d7343a073d92e4d4c24c5effa420c5)

config: $(KERNEL)
	(cd $(KERNEL); make menuconfig)

build: $(KERNEL) patch bce
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
