use @import("multiboot.zig");
const pci = @import("pci.zig");
const arch = @import("arch/x86/lib/index.zig");
const console = @import("console.zig");

// platform independant initialization
pub fn kmain() noreturn {
    console.initialize();
    while (true) {}
}
