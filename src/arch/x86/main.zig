const std = @import("std");
const kernel = @import("kernel");
const x86 = @import("x86");

/// x86 specific intialization
pub fn x86_main(info: *const kernel.multiboot.MultibootInfo) void {
    x86.gdt.initialize();
    x86.idt.initialize();
    x86.pmem.initialize(info);
    x86.paging.initialize();
    x86.instr.sti();
}
