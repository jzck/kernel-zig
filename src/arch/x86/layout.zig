//https://wiki.osdev.org/Memory_Map_(x86)

pub const KSTACK = 0x80000; // todo: move to .bss
pub const KERNEL = 0x100000;
pub const IDENTITY = 0x400000; // 0->4MiB
pub const HEAP = 0x800000;
