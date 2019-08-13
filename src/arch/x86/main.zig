usingnamespace @import("kernel").main;
usingnamespace @import("kernel").multiboot;
const console = @import("../console.zig");
const println = @import("../../vga.zig").println;

const idt = @import("idt.zig");
const memory = @import("memory.zig");
const paging = @import("paging.zig");
const gdt = @import("gdt.zig");
const x86 = @import("lib/index.zig");

/// x86 specific intialization
/// first entry point (see linker.ld)
pub fn x86_main(info: *const MultibootInfo) void {
    // set up the physical frame allocator
    memory.initialize(info);

    println("{}", memory.allocator.allocate(1));
    // println("{}", memory.allocator.allocate(1));
    // println("{}", memory.allocator.allocate(1));
    // println("{}", memory.allocator.allocate(1));

    // setup memory segmentation
    gdt.initialize();

    // setup interrupts
    idt.initialize();

    // enable interrupts
    x86.sti();

    // set up the virtual page mapper
    paging.initialize();

    // test breakpoint
    // x86.int3();
}
