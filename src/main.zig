usingnamespace @import("kernel");
// const x86 = @import("x86");

// Place the header at the very beginning of the binary.
export const multiboot_header align(4) linksection(".multiboot") = multiboot: {
    const MAGIC = u32(0x1BADB002); // multiboot magic
    const ALIGN = u32(1 << 0); // Align loaded modules at 4k
    const MEMINFO = u32(1 << 1); // Receive a memory map from the bootloader.
    const ADDR = u32(1 << 16); // Load specific addr
    const FLAGS = ALIGN | MEMINFO; // Combine the flags.

    break :multiboot multiboot.MultibootHeader{
        .magic = MAGIC,
        .flags = FLAGS,
        .checksum = ~(MAGIC +% FLAGS) +% 1,
    };
};

// export var stack_bytes: [16 * 1024]u8 align(16) linksection(".bss") = undefined;
// const stack_bytes_slice = stack_bytes[0..];

// linker.ld entrypoint
// export nakedcc fn __start() noreturn {
//     // eax -> multiboot magic
//     // ebx -> multiboot info
//     const magic = asm volatile ("mov %[ret], %eax"
//         : [ret] "=" (-> u32)
//     );
//     const info = asm volatile (""
//         : [ret] "=" (-> u32)
//     );
//     clear();
//     println("--- {x} ---", magic);
//     println("--- {x} ---", info);
//     // @newStackCall(stack_bytes_slice, kmain, magic, @intToPtr(*const multiboot.MultibootInfo, info));
//     @newStackCall(stack_bytes_slice, kmain, magic);
//     // @newStackCall(stack_bytes_slice, kmain);
// }

// arch independant initialization
export fn kmain(magic: u32, info: *const multiboot.MultibootInfo) noreturn {
    assert(magic == multiboot.MULTIBOOT_BOOTLOADER_MAGIC);
    clear();
    println("--- x86 initialization ---");
    x86.x86_main(info);
    println("--- core initialization ---");
    pci.scan();
    console.initialize();

    while (true) asm volatile ("hlt");
}
