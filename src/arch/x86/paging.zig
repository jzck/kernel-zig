const x86 = @import("lib/index.zig");
const allocator = @import("memory.zig").allocator;
const assert = @import("std").debug.assert;
const println = @import("../../vga.zig").println;

extern fn setupPaging(phys_pd: usize) void;

pub var mapper: Mapper = undefined;
pub const PAGE_SIZE = 4096;

pub fn initialize() void {
    const empty_page = PageDirectoryEntry{};
    // var p2 = allocator.allocate(1);
    var p2 = [_]PageDirectoryEntry{empty_page} ** 1024;
    // var p2 = [_]u32{0} ** 1024;

    // identity map 0 -> 4MB
    p2[0].pageTable = 0x0;
    p2[0].present = true;
    p2[0].read_write = true;
    p2[0].huge = true;
    // p2[0] = @bitReverse(u32, 0b10000011);

    println("p2[0] {b}", p2[0]);
    println("p2[0] {b}", @bitCast(u32, p2[0]));
    // x86.hang();
    // paging.s
    // setupPaging(@ptrToInt(&p2));

    // mapper = Mapper{
    //     .p2 = p2,
    // };
    const addr = mapper.translate(0xfffff000);
}

const builtin = @import("builtin");
const Mapper = struct {
    p2: PageDirectory,

    // virt to phys
    pub fn translate(self: Mapper, virt: u32) ?u32 {
        const map = @bitCast(VirtAddr, virt);
        println("{}", builtin.endian);
        println("virt {x} -> {}-{}-{x}", virt, map.page_directory, map.page_table, map.offset);
        return null;
    }
};

pub const VirtAddr = packed struct {
    page_directory: u10,
    page_table: u10,
    offset: u12,
};

pub const PageDirectoryEntry = packed struct {
    pageTable: u20 = 0,
    available: u3 = 0,
    ignored: bool = false,
    huge: bool = false,
    zero: bool = false,
    accessed: bool = false,
    cache_disabled: bool = false,
    write_thru: bool = false,
    supervisor: bool = false,
    read_write: bool = false,
    present: bool = false,
};

pub const PageTableEntry = packed struct {
    addr: u20 = 0,
    available: u3 = 0,
    global: bool = false,
    zero: bool = false,
    dirty: bool = false,
    accessed: bool = false,
    cache_disabled: bool = false,
    write_thru: bool = false,
    supervisor: bool = false,
    read_write: bool = false,
    present: bool = false,
};

pub const PageTable = [1024]PageTableEntry;
pub const PageDirectory = [1024]PageDirectoryEntry;

comptime {
    assert(@sizeOf(PageDirectoryEntry) == 4); //32 bits
    assert(@sizeOf(PageTableEntry) == 4); //32 bits
}
