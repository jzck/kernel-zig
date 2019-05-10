use @import("kernel").main;
const idt = @import("idt.zig");
const gdt = @import("gdt.zig");
const x86 = @import("lib/index.zig");

/// x86 specific intialization
/// first entry point (see linker.ld)
export nakedcc fn _start() noreturn {
    gdt.initialize();
    idt.initialize();
    x86.sti();
    kmain();
}
