//https://wiki.osdev.org/Memory_Map_(x86)
// virtual memory layout of the kernel

const kiB = 1024;
const MiB = 1024 * kiB;
const GiB = 1024 * MiB;

// zig fmt: off
pub const KSTACK            = 0x80000; // todo: move to .bss
pub const KERNEL            = 1 * MiB;
pub const IDENTITY          = 4 * MiB; // 0->4MiB

pub const HEAP              = 8 * MiB;
pub const HEAP_END          = 0x01000000;
pub const USER_STACKS       = 0x01000000;
pub const USER_STACKS_END   = 0x02000000;
// zig fmt: on
