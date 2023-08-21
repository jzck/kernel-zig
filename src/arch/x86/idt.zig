// https://wiki.osdev.org/IDT

const kernel = @import("kernel");
const x86 = @import("x86");

// Types of gates.
pub const INTERRUPT_GATE = 0x8E;
pub const SYSCALL_GATE = 0xEE;

// Interrupt Descriptor Table.
var idt_table: [256]IDTEntry = undefined;

// IDT descriptor register pointing at the IDT.
const idtr = IDTRegister{
    .limit = @as(u16, @sizeOf(@TypeOf(idt_table))),
    .base = &idt_table,
};

// Structure representing an entry in the IDT.
const IDTEntry = packed struct {
    offset_low: u16,
    selector: u16,
    zero: u8,
    flags: u8,
    offset_high: u16,
};

// IDT descriptor register.
const IDTRegister = packed struct {
    limit: u16,
    base: *[256]IDTEntry,
};

// Setup an IDT entry.
//
// Arguments:
//     n: Index of the gate.
//     flags: Type and attributes.
//     offset: Address of the ISR.
//
pub fn setGate(n: u8, flags: u8, offset: anytype) void {
    const intOffset = @ptrToInt(&offset);
    // const intOffset = offset;

    idt_table[n].offset_low = @truncate(u16, intOffset);
    idt_table[n].offset_high = @truncate(u16, intOffset >> 16);
    idt_table[n].flags = flags;
    idt_table[n].zero = 0;
    idt_table[n].selector = x86.gdt.KERNEL_CODE;
}

// Initialize the Interrupt Descriptor Table.
pub fn initialize() void {
    // configure PIC
    x86.interrupt.remapPIC();
    x86.interrupt.configPIT();
    // install ISRs
    x86.isr.install_exceptions();
    x86.isr.install_irqs();
    x86.isr.install_syscalls();
    // x86.interrupt.registerIRQ(0, kernel.time.increment);
    // x86.interrupt.registerIRQ(1, kernel.ps2.keyboard_handler);
    // x86.interrupt.register(1, debug_trap);
    // x86.interrupt.register(13, general_protection_fault);
    // x86.interrupt.register(14, page_fault);

    // load IDT
    x86.instr.lidt(@ptrToInt(&idtr));
}

fn general_protection_fault() void {
    kernel.vga.println("general protection fault", .{});
    x86.instr.hang();
}

fn debug_trap() void {
    kernel.vga.println("debug fault/trap", .{});
    kernel.vga.println("dr7: 0b{b}", .{x86.instr.dr7()});
}

fn page_fault() void {
    const vaddr = x86.instr.cr2();
    kernel.vga.println("cr2: 0x{x}", .{vaddr});
    kernel.vga.println("phy: 0x{x}", .{x86.paging.translate(vaddr)});
    kernel.vga.println("pde: 0x{x} ({})", .{ x86.paging.pde(vaddr), vaddr >> 22 });
    kernel.vga.println("pte: 0x{x} ({})", .{ x86.paging.pte(vaddr), vaddr >> 12 });
    // paging.format();
    x86.instr.hang();
}
