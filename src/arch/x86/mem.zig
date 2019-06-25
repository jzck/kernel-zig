usingnamespace @import("kernel").multiboot;
const assert = @import("std").debug.assert;
const vga = @import("../../vga.zig");

pub fn initialize(info: *const MultibootInfo) void {
    assert((info.flags & MULTIBOOT_INFO_MEMORY) != 0);
    assert((info.flags & MULTIBOOT_INFO_MEM_MAP) != 0);

    vga.printf("lower: {x}\n", info.mem_lower);
    vga.printf("upper: {x}\n", info.mem_upper);
    vga.printf("mmap_l: {}\n", info.mmap_length);
    vga.printf("mmap_a: {x}\n", info.mmap_addr);
}
