const interrupt = @import("arch/x86/interrupt.zig");
const x86 = @import("arch/x86/lib/index.zig");
const ps2 = @import("ps2.zig");
use @import("vga.zig");

var vga = VGA.init(VRAM_ADDR);

pub fn keypress(char: u8) void {
    vga.writeChar(char);
    if (char == '\n')
        vga.writeString("> ");
}

pub fn initialize() void {
    vga.clear();
    vga.writeString("> ");
    interrupt.registerIRQ(1, ps2.keyboard_handler);
}
