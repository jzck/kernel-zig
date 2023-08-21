const std = @import("std");
const kernel = @import("kernel");
const x86 = @import("x86");

pub var allocator: std.mem.Allocator = undefined;

// TODO: make a better memory allocator
// stupid simple virtual memory allocator
//  - does 1:1 virtual/physical mapping
//  - no defragmentation
//  - no allocation bigger than a page

const stack_size: usize = (kernel.layout.HEAP_END - kernel.layout.HEAP) / kernel.x86.PAGE_SIZE;
var stack_index: usize = 0; // Index into the stack.
var stack: [stack_size]usize = undefined; // Stack of free virtual addresses

pub fn available() usize {
    return stack_index * x86.PAGE_SIZE;
}

fn free(addr: usize) void {
    x86.paging.unmap(addr);
    stack[stack_index] = addr;
    stack_index += 1;
}

// const Error = error{OutOfMemory};

fn alloc(
    ctx: *anyopaque,
    len: usize,
    ptr_align: u8,
    ret_addr: usize,
) ?[*]u8 {
    // new allocation
    std.debug.assert(len < x86.PAGE_SIZE); // this allocator only support 1:1 mapping
    if (available() == 0) return error.OutOfMemory;
    stack_index -= 1;
    var vaddr: usize = stack[stack_index];
    try x86.paging.mmap(vaddr, null);
    return @intToPtr([*]u8, vaddr)[0..len];
}

pub fn init() void {
    allocator = std.mem.Allocator{
        .ptr = undefined,
        .vtable = std.mem.Allocator.VTable{
            .alloc = alloc,
            .resize = undefined,
            .free = free,
        }
        // .reallocFn = realloc,
        // .shrinkFn = shrink,
    };
    var addr: usize = kernel.layout.HEAP;
    while (addr < kernel.layout.HEAP_END) : (addr += x86.PAGE_SIZE) {
        stack[stack_index] = addr;
        stack_index += 1;
    }
}
