////
// Load a new Task Register.
//
// Arguments:
//     desc: Segment selector of the TSS.
//
pub inline fn ltr(desc: u16) void {
    asm volatile ("ltr %[desc]"
        :
        : [desc] "r" (desc)
    );
}

////
// Completely stop the computer.
//
pub inline fn hang() noreturn {
    asm volatile ("cli");
    while (true) {
        asm volatile ("hlt");
    }
}

pub inline fn sti() void {
    asm volatile ("sti");
}
pub inline fn int3() void {
    asm volatile ("int3");
}

////
// Load a new Interrupt Descriptor Table.
//
// Arguments:
//     idtr: Address of the IDTR register.
//
pub inline fn lidt(idtr: usize) void {
    asm volatile ("lidt (%[idtr])"
        :
        : [idtr] "r" (idtr)
    );
}
