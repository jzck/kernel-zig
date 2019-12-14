pub inline fn ltr(desc: u16) void {
    asm volatile ("ltr %[desc]"
        :
        : [desc] "r" (desc)
    );
}

pub inline fn hang() noreturn {
    cli();
    while (true) asm volatile ("hlt");
}

//TODO: inline this
pub fn cli() void {
    asm volatile ("cli");
}

//TODO: inline this
pub fn sti() void {
    asm volatile ("sti");
}

pub inline fn int3() void {
    asm volatile ("int3");
}

pub inline fn lidt(idtr: usize) void {
    asm volatile ("lidt (%[idtr])"
        :
        : [idtr] "r" (idtr)
    );
}
