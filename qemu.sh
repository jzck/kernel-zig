#!/bin/bash
# usage: ./qemu.sh start
#        ./qemu.sh quit

QEMU_SOCKET=/tmp/qemu.sock
QEMU_MONITOR="sudo socat - UNIX-CONNECT:${QEMU_SOCKET}"
QEMU_GDB_PORT=4242
KERNEL=build/kernel

qemu_start() {
	touch disk.img
	# sudo pkill -9 qemu-system-i386
	sudo qemu-system-i386 \
		-gdb tcp::${QEMU_GDB_PORT} \
		-monitor unix:${QEMU_SOCKET},server,nowait \
		-enable-kvm \
		-curses \
		-m 1341M \
		-hda disk.img \
		-kernel ${KERNEL}
		# -drive file=disk.img,if=virtio\
		# -no-reboot \
		# -device virtio-net,netdev=network0 -netdev tap,id=network0,ifname=tap0,script=no,downscript=no \
		# -S \
		# build/kernel.iso

		# this allows to monitor with ^a-c, but doesn't
		# play nice with irqs apparently...
		# -serial mon:stdio \
}

qemu_quit() { echo quit | sudo ${QEMU_MONITOR} >/dev/null; }
qemu_monitor() { sudo ${QEMU_MONITOR}; }

qemu_"$@"
