usingnamespace @import("index.zig");
// usingnamespace @import("x86");

extern fn setupPaging(phys_pd: usize) void;

const PageEntry = usize;
pub const PAGE_SIZE = 4096;
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

fn pageFault() void {
    println("pagefault");
    while (true) asm volatile ("hlt");
}

fn pageBase(addr: usize) usize {
    return addr & (~PAGE_SIZE +% 1);
}
fn pde(addr: usize) *PageEntry {
    return &PD[addr >> 22];
}
fn pte(addr: usize) *PageEntry {
    return &PT[addr >> 12];
}

// virtual to physical
pub fn translate(virt: usize) ?usize {
    if (pde(virt).* == 0) return null;
    return pageBase(pte(virt).*);
}

pub fn unmap(virt: usize) void {
    if (translate(virt)) |phys| {
        memory.free(translate(virt));
    } else {
        println("can't unmap 0x{x}, map is empty.", addr);
    }
}

pub fn mmap(virt: usize, phys: ?usize) void {
    var pde: *PageEntry = pde(virt);
    if (pde.* == 0) pde.* = memory.allocate() | WRITE | PRESENT;
    var pte: *PageEntry = pte(virt);
    pte.* = if (phys) |p| p else allocate() | PRESENT;
}

pub fn addrspace() void {
    var i: usize = 1;
    i = 0;
    while (i < 1024) : (i += 1) {
        if (PD[i] == 0) continue;
        println("p2[{}] -> 0x{x}", i, PD[i]);
        if (PD[i] & HUGE != 0) continue;
        var j: usize = 0;
        while (j < 1024) : (j += 1) {
            var entry: PageEntry = PT[i * 1024 + j];
            if (entry != 0) println("p2[{}]p1[{}] -> 0x{x}", i, j, entry);
        }
    }
}

pub fn initialize() void {
    var p2 = pageDirectory[0..];

    // identity map 0 -> 4MB
    p2[0] = 0x000000 | PRESENT | WRITE | HUGE;
    // recursive mapping
    p2[1023] = @ptrToInt(&p2[0]) | PRESENT | WRITE;

    assert(memory.stack_end < 0x400000);

    interrupt.register(14, pageFault);
    setupPaging(@ptrToInt(&pageDirectory[0]));
}
