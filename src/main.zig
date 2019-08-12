usingnamespace @import("multiboot2.zig");
usingnamespace @import("vga.zig");

const arch = @import("arch/x86/lib/index.zig");
const x86 = @import("arch/x86/main.zig");
const multiboot = @import("multiboot2.zig");

const assert = @import("std").debug.assert;
const pci = @import("pci.zig");
const console = @import("console.zig");

// arch independant initialization
export fn kmain(magic: u32, info_addr: u32) noreturn {
    println("--- hello x86_main ---");
    assert(magic == MULTIBOOT2_BOOTLOADER_MAGIC);

    const info = multiboot.load(info_addr);
    console.initialize();

    println("--- hello x86_main ---");

    x86.x86_main(&info);

    // pagefault_test(0xfeffc000);

    println("--- end ---");
    while (true) {}
}

fn pagefault_test(addr: u32) void {
    const ptr = @intToPtr(*volatile u8, addr);
    var a: u8 = ptr.*;
    printf("a = {}\n", a);

    ptr.* += 1;

    printf("a = {}\n", ptr.*);
}
