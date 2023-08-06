const std = @import("std");
const kernel = @import("kernel");
const x86 = @import("x86");

var stack: [*]usize = undefined; // Stack of free physical page.
var stack_index: usize = 0; // Index into the stack.

// Boundaries of the frame stack.
pub var stack_size: usize = undefined;
pub var stack_end: usize = undefined;

pub inline fn pageAlign(address: u32) u32 {
    // 4095 -> 4096
    // 4096 -> 4096
    // 4097 -> 8192
    return (address + x86.PAGE_SIZE - 1) & (~x86.PAGE_SIZE +% 1);
}

// Return the amount of variable elements (in bytes).
//
pub fn available() usize {
    return stack_index * x86.PAGE_SIZE;
}

pub inline fn available_MiB() usize {
    return available() / (1024 * 1024);
}

// Request a free physical page and return its address.
//
pub fn allocate() !usize {
    if (available() == 0) {
        kernel.println("out of memory", .{});
        return error.OutOfMemory;
    }
    stack_index -= 1;
    return stack[stack_index];
}

// Free a previously allocated physical page.
//
// Arguments:
//     address: Address of the page to be freed.
//
pub fn free(address: usize) void {
    stack[stack_index] = address;
    stack_index += 1;
}

// Scan the memory map to index all available memory.
//
// Arguments:
//     info: Information structure from bootloader.
//
pub fn initialize(info: *const kernel.multiboot.MultibootInfo) void {
    // Ensure the bootloader has given us the memory map.
    std.debug.assert((info.flags & kernel.multiboot.MULTIBOOT_INFO_MEMORY) != 0);
    std.debug.assert((info.flags & kernel.multiboot.MULTIBOOT_INFO_MEM_MAP) != 0);

    // TODO: WHAT WHY WHAAAAT, must check back here later
    // Place stack at 0x200000 so that in the future I trigger a
    // random bug and I won't ever know where it came from, great.
    stack = @intToPtr([*]usize, 0x200000); // 2 MiB

    // Place the stack of free pages after the last Multiboot module.
    // stack = @intToPtr([*]usize, pageAlign(info.mods_addr));

    // Calculate the approximate size of the stack based on the amount of total upper memory.
    stack_size = ((info.mem_upper * 1024) / x86.PAGE_SIZE) * @sizeOf(usize);
    stack_end = pageAlign(@ptrToInt(stack) + stack_size);

    var map: usize = info.mmap_addr;
    while (map < info.mmap_addr + info.mmap_length) {
        var entry = @intToPtr(*kernel.multiboot.MultibootMMapEntry, map);

        // Calculate the start and end of this memory area.
        var start = @truncate(usize, entry.addr);
        var end = @truncate(usize, start + entry.len);
        // Anything that comes before the end of the stack of free pages is reserved.
        start = if (start >= stack_end) start else stack_end;

        // Flag all the pages in this memory area as free.
        if (entry.type == kernel.multiboot.MULTIBOOT_MEMORY_AVAILABLE) while (start < end) : (start += x86.PAGE_SIZE)
            free(start);

        // Go to the next entry in the memory map.
        map += entry.size + @sizeOf(@TypeOf(entry.size));
    }

    kernel.vga.println("available memory: {d} MiB ", .{available() / 1024 / 1024});
}

pub fn format() void {
    kernel.vga.println("physframes left: {d} ({d} MiB)", .{ stack_index, available_MiB() });
}
