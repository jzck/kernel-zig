use @import("multiboot.zig");
const console = @import("console.zig");
const arch = @import("arch/x86/lib/index.zig");

// platform independant initialization
pub fn kmain() noreturn {
    console.initialize();
    while (true) {}
}
