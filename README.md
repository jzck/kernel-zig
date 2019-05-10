## hobby kernel in zig

slowly porting from rust.

### features

 - vga frame buffer
 - interrupts
 - todo: terminal console
 - todo: memory mapping
 - todo: cfs scheduler

### dependencies

`ziglang` compiler

### compile

`zig build` compile and links a multiboot kernel, without a bootloader.

### test

`./run.sh qemu start`
`./run.sh qemu monitor`
`./run.sh gdb`
