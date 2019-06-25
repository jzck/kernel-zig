usingnamespace @import("multiboot.zig");
const pci = @import("pci.zig");
const arch = @import("arch/x86/lib/index.zig");
const console = @import("console.zig");
const vga = @import("vga.zig");
const x86 = @import("arch/x86/main.zig");
const assert = @import("std").debug.assert;

// arch independant initialization
export fn kmain(magic: u32, info: *const MultibootInfo) noreturn {
    assert(magic == MULTIBOOT_BOOTLOADER_MAGIC);
    console.initialize();

    vga.printf("--- x86_main ---\n");

    x86.x86_main(info);

    vga.printf("--- arch indepent boot ---\n");

    while (true) {}
}
