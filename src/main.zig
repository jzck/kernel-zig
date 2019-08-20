usingnamespace @import("kernel");

const x86 = @import("x86");

export var stack_bytes: [16 * 1024]u8 align(16) linksection(".bss") = undefined;
const stack_bytes_slice = stack_bytes[0..];

// linker.ld entrypoint
export nakedcc fn _start() noreturn {
    // ebx -> multiboot info
    const info: u32 = asm volatile (""
        : [result] "={ebx}" (-> u32)
    );
    // eax -> multiboot magic
    const magic: u32 = asm volatile (""
        : [result] "={eax}" (-> u32)
    );
    @newStackCall(stack_bytes_slice, kmain, magic, @intToPtr(*const multiboot.MultibootInfo, info));
    while (true) {}
}

// arch independant initialization
fn kmain(magic: u32, info: *const multiboot.MultibootInfo) noreturn {
    assert(magic == multiboot.MULTIBOOT_BOOTLOADER_MAGIC);

    clear();
    println("--- x86 initialization ---");
    x86.x86_main(info);
    println("--- core initialization ---");
    pci.scan();
    console.initialize();

    while (true) asm volatile ("hlt");
}
