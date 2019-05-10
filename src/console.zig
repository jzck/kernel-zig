const interrupt = @import("arch/x86/interrupt.zig");
use @import("vga.zig");

var vga = VGA.init(VRAM_ADDR);

pub fn keyboard_handler() void {
    vga.writeString("hello");
}

pub fn initialize() void {
    vga.clear();
    vga.writeString("zzzzzzzzzzzzzzzz");
    interrupt.registerIRQ(1, keyboard_handler);
    vga.writeString("aaaa");
}
