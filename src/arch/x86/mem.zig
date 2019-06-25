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

    var map: usize = info.mmap_addr;
    while (map < info.mmap_addr + info.mmap_length) {
        var entry = @intToPtr(*MultibootMMapEntry, map);
        if (entry.type == MULTIBOOT_MEMORY_AVAILABLE) {
            vga.printf("AVAILABLE: ");
        } else {
            vga.printf("NOT AVAILABLE: ");
        }
        vga.printf("{x} ", entry.addr);
        if (entry.len / (1024 * 1024) > 0) {
            vga.printf("({} MB)\n", entry.len / (1024 * 1024));
        } else {
            vga.printf("({} kB)\n", entry.len / (1024));
        }
        map += entry.size + @sizeOf(@typeOf(entry.size));
    }
}
