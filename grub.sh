#!/bin/bash
exit_missing() {
	printf "$_ must be installed\n" ; exit 1; 
}

which xorriso || exit_missing
which grub-mkrescue || exit_missing
mkdir -p build/iso/boot
cp build/bzImage build/iso/boot
grub-mkrescue -o build/kernel.iso build/iso
