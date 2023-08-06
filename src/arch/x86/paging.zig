const std = @import("std");
const kernel = @import("kernel");
const x86 = @import("x86");

extern fn setupPaging(phys_pd: usize) void;

const PageEntry = usize;
pub const PT = @intToPtr([*]PageEntry, 0xFFC00000);
pub const PD = @intToPtr([*]PageEntry, 0xFFFFF000);
const PRESENT = 0x1;
const WRITE = 0x2;
const USER = 0x4;
const WRITE_THRU = 0x8;
const NOCACHE = 0x10;
const ACCESSED = 0x20;
const HUGE = 0x80;

pub var pageDirectory: [1024]PageEntry align(4096) linksection(".bss") = [_]PageEntry{0} ** 1024;

// TODO: inline these
fn pageBase(virt: usize) usize {
    return virt & (~x86.PAGE_SIZE +% 1);
}
pub fn pde(virt: usize) *PageEntry {
    return &PD[virt >> 22]; //relies on recursive mapping
}
pub fn pte(virt: usize) *PageEntry {
    return &PT[virt >> 12]; //relies on recursive mapping
}

// virtual to physical
pub fn translate(virt: usize) ?usize {
    if (pde(virt).* == 0) return null;
    return pageBase(pte(virt).*);
}

pub fn unmap(virt: usize) void {
    if (translate(virt)) |phys| {
        x86.pmem.free(phys);
    } else {
        kernel.vga.println("can't unmap 0x{x} because it is not mapped.", .{virt});
    }
}

pub fn mmap(virt: usize, phys: ?usize) !void {
    //TODO: support hugepages
    // allocate a page directory if there is none
    if (pde(virt).* == 0) pde(virt).* = (try x86.pmem.allocate()) | WRITE | PRESENT;
    // allocate a frame if phys isn't specified
    pte(virt).* = (if (phys) |p| p else try x86.pmem.allocate()) | PRESENT;
}

pub fn initialize() void {
    var p2 = pageDirectory[0..];

    // identity map 0 -> 4MB
    p2[0] = 0x000000 | PRESENT | WRITE | HUGE;
    // recursive mapping
    p2[1023] = @ptrToInt(&p2[0]) | PRESENT | WRITE;

    // TODO: verify is this a hack?
    std.debug.assert(x86.pmem.stack_end < kernel.layout.IDENTITY);

    setupPaging(@ptrToInt(&pageDirectory[0])); //asm routine
}

pub fn format() void {
    var i: usize = 1;
    i = 0;
    while (i < 1024) : (i += 1) {
        if (PD[i] == 0) continue;
        kernel.vga.println("p2[{}] -> 0x{x}", .{ i, PD[i] });
        if (PD[i] & HUGE != 0) continue;
        var j: usize = 0;
        while (j < 1024) : (j += 1) {
            var entry: PageEntry = PT[i * 1024 + j];
            if (entry != 0) kernel.vga.println("p2[{}]p1[{}] -> 0x{x}", .{ i, j, entry });
        }
    }
}
