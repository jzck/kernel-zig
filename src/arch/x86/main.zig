// usingnamespace @import("kernel");
usingnamespace @import("index.zig");
// const multiboot = @import("../../multiboot.zig");

/// x86 specific intialization
pub fn x86_main(info: *const multiboot.MultibootInfo) void {
    gdt.initialize();
    idt.initialize();
    memory.initialize(info);
    paging.initialize();

    // enable interrupts
    sti();
}
