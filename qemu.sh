#!/bin/bash

QEMU_SOCKET=/tmp/qemu.sock
QEMU_MONITOR="sudo socat - UNIX-CONNECT:${QEMU_SOCKET}"
QEMU_GDB_PORT=4242
KERNEL=build/kernel

start() {
	touch disk.img
	sudo pkill -9 qemu
	sudo qemu-system-i386 \
		-gdb tcp::${QEMU_GDB_PORT} \
		-monitor unix:${QEMU_SOCKET},server,nowait \
		-enable-kvm \
		-m 1341M \
		-curses \
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

monitor() { sudo ${QEMU_MONITOR}; }
monitor-exec() { echo "$1" | sudo ${QEMU_MONITOR} >/dev/null; }

quit() { monitor-exec quit; }

reload() {
	monitor-exec stop
	# monitor "change ide1-cd0 ${KERNEL}"
	monitor-exec system_reset
	monitor-exec cont
}

"$@"
