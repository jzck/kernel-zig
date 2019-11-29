usingnamespace @import("index.zig");

// PIC ports.
const PIC1_CMD = 0x20;
const PIC1_DATA = 0x21;
const PIC2_CMD = 0xA0;
const PIC2_DATA = 0xA1;
// PIC commands:
const ISR_READ = 0x0B; // Read the In-Service Register.
const ACK = 0x20; // Acknowledge interrupt.
// Initialization Control Words commands.
const ICW1_INIT = 0x10;
const ICW1_ICW4 = 0x01;
const ICW4_8086 = 0x01;
// write 0 to wait
const WAIT_PORT = 0x80;
// PIT Channels
const PIT_CHAN0 = 0x40;
const PIT_CHAN1 = 0x41;
const PIT_CHAN2 = 0x42;
const PIT_CMD = 0x43;
// Interrupt Vector offsets of exceptions.
const EXCEPTION_0 = 0;
const EXCEPTION_31 = EXCEPTION_0 + 31;
// Interrupt Vector offsets of IRQs.
const IRQ_0 = EXCEPTION_31 + 1;
const IRQ_15 = IRQ_0 + 15;
// Interrupt Vector offsets of syscalls.
const SYSCALL = 128;

// Registered interrupt handlers. (see isr.s)
var handlers = [_]fn () void{unhandled} ** 48;
// Registered IRQ subscribers. (see isr.s)
// var irq_subscribers = []MailboxId{MailboxId.Kernel} ** 16;

fn unhandled() noreturn {
    const n = isr.context.interrupt_n;
    kernel.print("unhandled interrupt number {d}", n);
    if (n < IRQ_0) {
        kernel.println(" (exception)");
    } else {
        kernel.println(" (IRQ number {d})", n - IRQ_0);
    }
    hang();
}

inline fn picwait() void {
    outb(WAIT_PORT, 0);
}

////
// Call the correct handler based on the interrupt number.
//
export fn interruptDispatch() void {
    const n = @intCast(u8, isr.context.interrupt_n);

    switch (n) {
        // Exceptions.
        EXCEPTION_0...EXCEPTION_31 => {
            handlers[n]();
        },

        // IRQs.
        IRQ_0...IRQ_15 => {
            const irq = n - IRQ_0;
            // if (spuriousIRQ(irq)) return;

            startOfInterrupt(irq);
            handlers[n]();
            endOfInterrupt(irq);
        },

        // Syscalls.
        // SYSCALL => {
        //     const syscall_n = isr.context.registers.eax;
        //     if (syscall_n < syscall.handlers.len) {
        //         syscall.handlers[syscall_n]();
        //     } else {
        //         syscall.invalid();
        //     }
        // },

        else => unreachable,
    }

    // If no user thread is ready to run, halt here and wait for interrupts.
    // if (scheduler.current() == null) {
    //     sti();
    //     hlt();
    // }
}

inline fn spuriousIRQ(irq: u8) bool {
    // Only IRQ 7 and IRQ 15 can be spurious.
    if (irq != 7) return false;
    // TODO: handle spurious IRQ15.

    // Read the value of the In-Service Register.
    outb(PIC1_CMD, ISR_READ);
    const in_service = inb(PIC1_CMD);

    // Verify whether IRQ7 is set in the ISR.
    return (in_service & (1 << 7)) == 0;
}

inline fn startOfInterrupt(irq: u8) void {
    // mask the irq and then ACK
    if (irq >= 8) {
        maskIRQ(irq, true);
        outb(PIC1_CMD, ACK);
        outb(PIC2_CMD, ACK);
    } else {
        maskIRQ(irq, true);
        outb(PIC1_CMD, ACK);
    }
}

inline fn endOfInterrupt(irq: u8) void {
    // unmask the irq and then ACK
    if (irq >= 8) {
        maskIRQ(irq, false);
        outb(PIC2_CMD, ACK);
    } else {
        maskIRQ(irq, false);
        outb(PIC1_CMD, ACK);
    }
}

pub fn register(n: u8, handler: fn () void) void {
    handlers[n] = handler;
}

pub fn registerIRQ(irq: u8, handler: fn () void) void {
    register(IRQ_0 + irq, handler);
    maskIRQ(irq, false); // Unmask the IRQ.
}

pub fn remapPIC() void {
    // ICW1: start initialization sequence.
    outb(PIC1_CMD, ICW1_INIT | ICW1_ICW4);
    picwait();
    outb(PIC2_CMD, ICW1_INIT | ICW1_ICW4);
    picwait();

    // ICW2: Interrupt Vector offsets of IRQs.
    outb(PIC1_DATA, IRQ_0); // IRQ 0..7  -> Interrupt 32..39
    picwait();
    outb(PIC2_DATA, IRQ_0 + 8); // IRQ 8..15 -> Interrupt 40..47
    picwait();

    // ICW3: IRQ line 2 to connect master to slave PIC.
    outb(PIC1_DATA, 1 << 2);
    picwait();
    outb(PIC2_DATA, 2);
    picwait();

    // ICW4: 80x86 mode.
    outb(PIC1_DATA, ICW4_8086);
    picwait();
    outb(PIC2_DATA, ICW4_8086);
    picwait();

    // Mask all IRQs.
    outb(PIC1_DATA, 0xFF);
    picwait();
    outb(PIC2_DATA, 0xFF);
    picwait();
}

pub fn maskIRQ(irq: u8, mask: bool) void {
    if (irq > 15) return;
    // Figure out if master or slave PIC owns the IRQ.
    const port = if (irq < 8) u16(PIC1_DATA) else u16(PIC2_DATA);
    const old = inb(port); // Retrieve the current mask.

    // Mask or unmask the interrupt.
    const shift = @intCast(u3, irq % 8);
    if (mask) outb(port, old | (u8(1) << shift));
    if (!mask) outb(port, old & ~(u8(1) << shift));
    const new = inb(port); // Retrieve the current mask.
}

// configures the chan0 with a rate generator, which will trigger irq0
pub fn configPIT() void {
    const chanNum = 0;
    const chan = PIT_CHAN0;
    const divisor = 2685;
    const LOHI = 0b11; // bit4 | bit5
    const PITMODE_RATE_GEN = 0x2;
    outb(PIT_CMD, chanNum << 6 | LOHI << 4 | PITMODE_RATE_GEN << 1);
    outb(PIT_CHAN0, divisor & 0xff);
    outb(PIT_CHAN0, divisor >> 8);
}

pub fn pit_handler() void {
    // pit freq = 1.193182 MHz
    // chan0 divisor = 2685
    // PIT_RATE in us
    kernel.time.increment(2251);
}
