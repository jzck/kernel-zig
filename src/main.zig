const std = @import("std");
const builtin = std.builtin;
const kernel = @import("index.zig");

// Place the header at the very beginning of the binary.
export const multiboot_header align(4) linksection(".multiboot") = multiboot: {
    const MAGIC = @as(u32, 0x1BADB002); // multiboot magic
    const ALIGN = @as(u32, 1 << 0); // Align loaded modules at 4k
    const MEMINFO = @as(u32, 1 << 1); // Receive a memory map from the bootloader.
    // const ADDR = @as(u32, 1 << 16); // Load specific addr
    const FLAGS = ALIGN | MEMINFO; // Combine the flags.

    break :multiboot kernel.multiboot.MultibootHeader{
        .magic = MAGIC,
        .flags = FLAGS,
        .checksum = ~(MAGIC +% FLAGS) +% 1,
    };
};

// arch independant initialization
export fn kmain(magic: u32, info: *const kernel.multiboot.MultibootInfo) noreturn {
    std.debug.assert(magic == kernel.multiboot.MULTIBOOT_BOOTLOADER_MAGIC);
    kernel.vga.clear();
    kernel.vga.println("--- x86 initialization ---", .{});
    kernel.x86.x86_main(info);
    kernel.vga.println("--- core initialization ---", .{});
    kernel.vmem.init();
    kernel.pci.scan();
    kernel.vga.println("--- finished booting --- ", .{});

    // kernel.task.cleaner_task = kernel.task.new(@ptrToInt(kernel.task.cleaner_loop)) catch unreachable;
    // _ = kernel.task.new(@ptrToInt(kernel.vga.topbar)) catch unreachable;
    // _ = kernel.task.new(@ptrToInt(kernel.console.loop)) catch unreachable;

    // var buf = kernel.vmem.allocator.create([512]u8) catch unreachable;
    // kernel.vga.println("buf at 0x{x}", .{@ptrToInt(buf)});
    // kernel.driver.ide.first_ide_drive.read(2, buf);

    // const sig = buf[56..58];
    // kernel.vga.println("sig: {x}", .{sig});

    // kernel.task.terminate();
}

// pub fn panic(a: []const u8, b: ?*builtin.StackTrace) noreturn {
//     kernel.vga.println("{}", .{a});
//     kernel.vga.println("{}", .{b});
//     while (true) asm volatile ("hlt");
// }
