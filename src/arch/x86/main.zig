usingnamespace @import("index.zig");

/// x86 specific intialization
pub fn x86_main(info: *const kernel.multiboot.MultibootInfo) void {
    gdt.initialize();
    idt.initialize();
    pmem.initialize(info);
    paging.initialize();
    sti();
}
