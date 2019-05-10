QEMU_SOCKET=/tmp/qemu.sock
QEMU_MONITOR="socat - unix-connect:${QEMU_SOCKET}"
QEMU_GDB_PORT=4242
KERNEL=build/bzImage

qemu() {
    start() {
        sudo qemu-system-i386\
            -kernel ${KERNEL}\
            -gdb tcp::${QEMU_GDB_PORT}\
            -monitor unix:${QEMU_SOCKET},server,nowait\
            -display curses\
            -enable-kvm\
            $*
    }

    monitor() {
        sudo ${QEMU_MONITOR}
    }

    reload() {
        echo "stop" | ${QEMU_MONITOR} &>/dev/null
        echo "change ide1-cd0 ${KERNEL}" | ${QEMU_MONITOR} &>/dev/null
        echo "system_reset" | ${QEMU_MONITOR} &>/dev/null
    }

    "$@"
}

gdb() {
    gdb\
        -q\
        -symbols "${KERNEL}" \
        -ex "target remote :${QEMU_GDB_PORT}"\
        -ex "set arch i386"
}

"$@"
