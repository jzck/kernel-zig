use @import("kernel").main;
use @import("kernel").multiboot;
const idt = @import("idt.zig");
const gdt = @import("gdt.zig");
const x86 = @import("lib/index.zig");
const assert = @import("std").debug.assert;

/// x86 specific intialization
/// first entry point (see linker.ld)
export nakedcc fn x86_main(magic: u32, info: *const MultibootInfo) noreturn {
    // assert(magic == MULTIBOOT_BOOTLOADER_MAGIC);
    gdt.initialize();
    idt.initialize();
    x86.sti();
    kmain(magic, info);
}
