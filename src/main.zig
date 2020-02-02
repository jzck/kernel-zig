usingnamespace @import("kernel");

// Place the header at the very beginning of the binary.
export const multiboot_header align(4) linksection(".multiboot") = multiboot: {
    const MAGIC = @as(u32, 0x1BADB002); // multiboot magic
    const ALIGN = @as(u32, 1 << 0); // Align loaded modules at 4k
    const MEMINFO = @as(u32, 1 << 1); // Receive a memory map from the bootloader.
    const ADDR = @as(u32, 1 << 16); // Load specific addr
    const FLAGS = ALIGN | MEMINFO; // Combine the flags.

    break :multiboot multiboot.MultibootHeader{
        .magic = MAGIC,
        .flags = FLAGS,
        .checksum = ~(MAGIC +% FLAGS) +% 1,
    };
};

// arch independant initialization
export fn kmain(magic: u32, info: *const multiboot.MultibootInfo) noreturn {
    assert(magic == multiboot.MULTIBOOT_BOOTLOADER_MAGIC);
    clear();
    asm volatile ("movd %%edi, %%xmm0");
    println("--- x86 initialization ---", .{});
    x86.x86_main(info);
    println("--- core initialization ---", .{});
    vmem.init();
    pci.scan();
    println("--- finished booting --- ", .{});

    task.cleaner_task = task.new(@ptrToInt(task.cleaner_loop)) catch unreachable;
    _ = task.new(@ptrToInt(topbar)) catch unreachable;
    _ = task.new(@ptrToInt(console.loop)) catch unreachable;

    var buf = vmem.create([512]u8) catch unreachable;
    println("buf at 0x{x}", .{@ptrToInt(buf)});
    driver.ide.first_ide_drive.read(2, buf);

    const sig = buf[56..58];
    println("sig: {x}", .{sig});

    task.terminate();
}

pub fn panic(a: []const u8, b: ?*builtin.StackTrace) noreturn {
    println("{}", .{a});
    println("{}", .{b});
    while (true) asm volatile ("hlt");
}
