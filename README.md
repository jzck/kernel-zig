# hobby kernel in zig

### features

 - 80x25 frame buffer
 - ps2 keyboard driver
 - terminal console
 - lspci
 - x86
   - MMU
   - interrupts

### dependencies

  - [ziglang](https://github.com/ziglang/zig) 0.5.0

# How to

## compile

`zig build` compiles and links the multiboot kernel (without a bootloader)

## test

 - `./qemu.sh start`
 - `./qemu.sh monitor`
 - `./qemu.sh gdb`

# Notes

## interrupt call chain

`interrupt` -> `idt[n]` -> `isrN` -> `isrDispatch` -> `handlers[n]` (default `unhandled()`)
