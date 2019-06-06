usingnamespace @import("multiboot.zig");
const pci = @import("pci.zig");
const arch = @import("arch/x86/lib/index.zig");
const console = @import("console.zig");
const vga = @import("vga.zig");

// platform independant initialization
pub fn kmain(magic: u32, info: *const MultibootInfo) noreturn {
    console.initialize();
    vga.printf("magic 0x{x}\n", magic);
    while (true) {}
}
