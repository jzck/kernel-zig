QEMU_SOCKET=/tmp/qemu.sock
QEMU_MONITOR="socat - UNIX-CONNECT:${QEMU_SOCKET}"
QEMU_GDB_PORT=4242
KERNEL=build/kernel

start() {
    sudo qemu-system-i386 \
        -gdb tcp::${QEMU_GDB_PORT} \
        -monitor unix:${QEMU_SOCKET},server,nowait \
        -enable-kvm \
        -m 50M \
        -serial mon:stdio \
        -curses \
        -kernel ${KERNEL}
        # -cdrom ${KERNEL}.iso
        # -append "Hello" \
        # -S
        # -device virtio-net,netdev=network0 -netdev tap,id=network0,ifname=tap0,script=no,downscript=no \
        # build/kernel.iso
        "$@"
}

monitor() {
    [ "$1" == "" ] && sudo ${QEMU_MONITOR} || echo "$1" | sudo ${QEMU_MONITOR} >/dev/null
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
