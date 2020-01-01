pub usingnamespace @import("index.zig");
pub const allocator: std.mem.Allocator = undefined;

// TODO: make a better memory allocator
// stupid simple virtual memory allocator
//  - does 1:1 virtual/physical mapping
//  - no defragmentation
//  - no allocation bigger than a page

const stack_size: usize = (layout.HEAP_END - layout.HEAP) / x86.PAGE_SIZE;
var stack: [stack_size]usize = undefined; // Stack of free virtual addresses
var stack_index: usize = 0; // Index into the stack.

pub fn available() usize {
    return stack_index * x86.PAGE_SIZE;
}

pub fn malloc(size: usize) !usize {
    if (available() == 0) {
        return error.OutOfMemory;
    }
    stack_index -= 1;
    var vaddr: usize = stack[stack_index];
    try x86.paging.mmap(vaddr, null);
    return vaddr;
}

pub fn create(comptime T: type) !*T {
    assert(@sizeOf(T) < x86.PAGE_SIZE); // this allocator only support 1:1 mapping
    return @intToPtr(*T, try malloc(@sizeOf(T)));
}

pub fn destroy(O: var) void {
    vmem.free(@ptrToInt(O));
}

pub fn free(address: usize) void {
    x86.paging.unmap(address);
    stack[stack_index] = address;
    stack_index += 1;
}

pub fn init() void {
    var addr: usize = layout.HEAP;
    while (addr < layout.HEAP_END) : (addr += x86.PAGE_SIZE) {
        // println("addr {x}", addr);
        stack[stack_index] = addr;
        stack_index += 1;
        // return;
    }
}
