QEMU_SOCKET=/tmp/qemu.sock
QEMU_MONITOR="socat - UNIX-CONNECT:${QEMU_SOCKET}"
QEMU_GDB_PORT=4242
KERNEL=build/bzImage

start() {
    sudo pkill -9 qemu
    sudo qemu-system-i386 \
        -gdb tcp::${QEMU_GDB_PORT} \
        -monitor unix:${QEMU_SOCKET},server,nowait \
        -enable-kvm \
        -display curses \
        -device virtio-net,netdev=network0 -netdev tap,id=network0,ifname=tap0,script=no,downscript=no \
        -kernel ${KERNEL}
	# build/kernel.iso
        "$@"
}

monitor() {
    if [ "$1" == "" ]; then
        sudo ${QEMU_MONITOR}
    else
        echo "$1" | sudo ${QEMU_MONITOR} >/dev/null
    fi
}

reload() {
    monitor stop
    # monitor "change ide1-cd0 ${KERNEL}"
    monitor system_reset
    monitor cont
}

gdb() {
    gdb -q \
        -symbols "${KERNEL}" \
        -ex "target remote :${QEMU_GDB_PORT}" \
        -ex "set arch i386"
}

"$@"
