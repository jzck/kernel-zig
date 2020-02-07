pub usingnamespace @import("index.zig");
pub var allocator: std.mem.Allocator = undefined;

// TODO: make a better memory allocator
// stupid simple virtual memory allocator
//  - does 1:1 virtual/physical mapping
//  - no defragmentation
//  - no allocation bigger than a page

const stack_size: usize = (layout.HEAP_END - layout.HEAP) / x86.PAGE_SIZE;
var stack_index: usize = 0; // Index into the stack.
var stack: [stack_size]usize = undefined; // Stack of free virtual addresses

pub fn available() usize {
    return stack_index * x86.PAGE_SIZE;
}

fn dealloc(addr: usize) void {
    x86.paging.unmap(addr);
    stack[stack_index] = addr;
    stack_index += 1;
}

const Error = error{OutOfMemory};

fn realloc(
    self: *std.mem.Allocator,
    old_mem: []u8,
    old_alignment: u29,
    new_byte_count: usize,
    new_alignment: u29,
) ![]u8 {
    if (old_mem.len == 0) {
        // new allocation
        assert(new_byte_count < x86.PAGE_SIZE); // this allocator only support 1:1 mapping
        if (available() == 0) return error.OutOfMemory;
        stack_index -= 1;
        var vaddr: usize = stack[stack_index];
        try x86.paging.mmap(vaddr, null);
        return @intToPtr([*]u8, vaddr)[0..new_byte_count];
    }
    // free
    if (new_byte_count == 0) {
        dealloc(@ptrToInt(&old_mem[0]));
        return &[_]u8{};
    }
    println("vmem: unsupported allocator operation", .{});
    x86.hang();
    // return undefined;
}

fn shrink(
    self: *std.mem.Allocator,
    old_mem: []u8,
    old_alignment: u29,
    new_byte_count: usize,
    new_alignment: u29,
) []u8 {
    // free
    if (new_byte_count == 0) {
        dealloc(@ptrToInt(&old_mem[0]));
        return &[_]u8{};
    }

    println("vmem doesn't support shrinking, {}, {}, {}, {}", .{
        old_mem,
        old_alignment,
        new_byte_count,
        new_alignment,
    });
    x86.hang();
    // return undefined;
}

pub fn init() void {
    allocator = std.mem.Allocator{
        .reallocFn = realloc,
        .shrinkFn = shrink,
    };
    var addr: usize = layout.HEAP;
    while (addr < layout.HEAP_END) : (addr += x86.PAGE_SIZE) {
        stack[stack_index] = addr;
        stack_index += 1;
    }
}
