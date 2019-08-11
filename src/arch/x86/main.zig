usingnamespace @import("kernel").main;
usingnamespace @import("kernel").multiboot;
const idt = @import("idt.zig");
const mem = @import("mem.zig");
const gdt = @import("gdt.zig");
const x86 = @import("lib/index.zig");
const console = @import("../console.zig");
const printf = @import("../../vga.zig").printf;

/// x86 specific intialization
/// first entry point (see linker.ld)
pub fn x86_main(info: *const MultibootInfo) void {
    var allocator = mem.initialize(info);

    // gdt.initialize();
    idt.initialize();
    x86.sti();
}
