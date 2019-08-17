usingnamespace @import("kernel").multiboot;
usingnamespace @import("kernel").vga;
const assert = @import("std").debug.assert;

var stack: [*]usize = undefined; // Stack of free physical page.
var stack_index: usize = 0; // Index into the stack.

// Boundaries of the frame stack.
pub var stack_size: usize = undefined;
pub var stack_end: usize = undefined;

pub const PAGE_SIZE: usize = 4096;
// 4095 -> 4096
// 4096 -> 4096
// 4097 -> 8192
pub fn pageAlign(address: u32) u32 {
    return (address + PAGE_SIZE - 1) & (~PAGE_SIZE +% 1);
}

////
// Return the amount of variable elements (in bytes).
//
pub fn available() usize {
    return stack_index * PAGE_SIZE;
}

////
// Request a free physical page and return its address.
//
pub fn allocate() ?usize {
    if (available() == 0) {
        println("out of memory");
        return null;
    }
    stack_index -= 1;
    return stack[stack_index];
}

////
// Free a previously allocated physical page.
//
// Arguments:
//     address: Address of the page to be freed.
//
pub fn free(address: usize) void {
    stack[stack_index] = address;
    stack_index += 1;
}

////
// Scan the memory map to index all available memory.
//
// Arguments:
//     info: Information structure from bootloader.
//
pub fn initialize(info: *const MultibootInfo) void {
    // Ensure the bootloader has given us the memory map.
    assert((info.flags & MULTIBOOT_INFO_MEMORY) != 0);
    assert((info.flags & MULTIBOOT_INFO_MEM_MAP) != 0);

    // Place the stack of free pages after the last Multiboot module.
    stack = @intToPtr([*]usize, 0x200000);
    // stack = @intToPtr([*]usize, pageAlign(info.mods_addr));
    // Calculate the approximate size of the stack based on the amount of total upper memory.
    stack_size = ((info.mem_upper * 1024) / PAGE_SIZE) * @sizeOf(usize);
    stack_end = pageAlign(@ptrToInt(stack) + stack_size);

    var map: usize = info.mmap_addr;
    while (map < info.mmap_addr + info.mmap_length) {
        var entry = @intToPtr(*MultibootMMapEntry, map);

        // Calculate the start and end of this memory area.
        var start = @truncate(usize, entry.addr);
        var end = @truncate(usize, start + entry.len);
        // Anything that comes before the end of the stack of free pages is reserved.
        start = if (start >= stack_end) start else stack_end;

        // Flag all the pages in this memory area as free.
        if (entry.type == MULTIBOOT_MEMORY_AVAILABLE) while (start < end) : (start += PAGE_SIZE)
            free(start);

        // Go to the next entry in the memory map.
        map += entry.size + @sizeOf(@typeOf(entry.size));
    }

    println("available memory: {d} MiB ", available() / 1024 / 1024);
}
