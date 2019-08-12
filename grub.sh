#!/bin/bash
exit_missing() {
	printf "$_ must be installed\n" ; exit 1; 
}

which xorriso || exit_missing
which grub-mkrescue || exit_missing
mkdir -p build/iso/boot/grub
cp build/kernel build/iso/boot
>build/iso/boot/grub/grub.cfg <<EOF
set timeout=0
set default=0

menuentry "OS" {
    multiboot2 /boot/kernel
    boot
}
EOF

grub-mkrescue -o build/kernel.iso build/iso
