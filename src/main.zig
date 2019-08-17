usingnamespace @import("multiboot.zig");
usingnamespace @import("vga.zig");
const pci = @import("pci.zig");
const arch = @import("arch/x86/lib/index.zig");
const console = @import("console.zig");
const x86 = @import("arch/x86/main.zig");
const assert = @import("std").debug.assert;

// arch independant initialization
export fn kmain(magic: u32, info: *const MultibootInfo) noreturn {
    clear();
    assert(magic == MULTIBOOT_BOOTLOADER_MAGIC);
    println("--- x86 initialization ---");

    x86.x86_main(info);

    println("--- core initialization ---");
    pci.scan();
    console.initialize();
    while (true) {
        asm volatile ("hlt");
    }
}
