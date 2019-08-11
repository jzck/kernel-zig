usingnamespace @import("multiboot.zig");
usingnamespace @import("vga.zig");
const pci = @import("pci.zig");
const arch = @import("arch/x86/lib/index.zig");
const console = @import("console.zig");
const x86 = @import("arch/x86/main.zig");
const assert = @import("std").debug.assert;

// arch independant initialization
export fn kmain(magic: u32, info: *const MultibootInfo) noreturn {
    assert(magic == MULTIBOOT_BOOTLOADER_MAGIC);
    console.initialize();

    printf("--- hello x86_main ---\n");

    x86.x86_main(info);

    // pagefault_test(0xfeffc000);

    printf("\n--- arch indepent boot ---\n");

    while (true) {}
}

fn pagefault_test(addr: u32) void {
    const ptr = @intToPtr(*volatile u8, addr);
    var a: u8 = ptr.*;
    printf("a = {}\n", a);

    ptr.* += 1;

    printf("a = {}\n", ptr.*);
}
