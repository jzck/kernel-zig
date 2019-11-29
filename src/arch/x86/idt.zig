// https://wiki.osdev.org/IDT
// usingnamespace @import("kernel");
// usingnamespace @import("x86");
usingnamespace @import("index.zig");

// Types of gates.
pub const INTERRUPT_GATE = 0x8E;
pub const SYSCALL_GATE = 0xEE;

// Interrupt Descriptor Table.
var idt_table: [256]IDTEntry = undefined;

// IDT descriptor register pointing at the IDT.
const idtr = IDTRegister{
    .limit = u16(@sizeOf(@typeOf(idt_table))),
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
pub fn setGate(n: u8, flags: u8, offset: extern fn () void) void {
    const intOffset = @ptrToInt(offset);

    idt_table[n].offset_low = @truncate(u16, intOffset);
    idt_table[n].offset_high = @truncate(u16, intOffset >> 16);
    idt_table[n].flags = flags;
    idt_table[n].zero = 0;
    idt_table[n].selector = gdt.KERNEL_CODE;
}

// Initialize the Interrupt Descriptor Table.
pub fn initialize() void {
    // configure PIC
    interrupt.remapPIC();
    interrupt.configPIT();
    // install ISRs
    isr.install_exceptions();
    isr.install_irqs();
    isr.install_syscalls();
    interrupt.registerIRQ(0, interrupt.pit_handler);
    interrupt.registerIRQ(1, kernel.ps2.keyboard_handler);

    // load IDT
    lidt(@ptrToInt(&idtr));
}
