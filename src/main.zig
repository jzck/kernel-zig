usingnamespace @import("kernel");
const x86 = @import("x86");

// arch independant initialization
export fn kmain(magic: u32, info: *const MultibootInfo) noreturn {
    assert(magic == MULTIBOOT_BOOTLOADER_MAGIC);

    clear();
    println("--- x86 initialization ---");
    x86.x86_main(info);
    println("--- core initialization ---");
    pci.scan();
    console.initialize();

    while (true) asm volatile ("hlt");
}
