usingnamespace @import("kernel");
usingnamespace @import("x86");

/// x86 specific intialization
pub fn x86_main(info: *const MultibootInfo) void {
    gdt.initialize();
    idt.initialize();
    memory.initialize(info);
    paging.initialize();

    // enable interrupts
    x86.sti();
}
