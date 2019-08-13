const interrupt = @import("arch/x86/interrupt.zig");
const x86 = @import("arch/x86/lib/index.zig");
const ps2 = @import("ps2.zig");
const pci = @import("pci.zig");
const std = @import("std");
const mem = std.mem;
usingnamespace @import("vga.zig");

var command: [10]u8 = undefined;
var command_len: usize = 0;

fn execute(com: []u8) void {
    if (mem.eql(u8, com, "lspci")) pci.lspci();
}

pub fn keypress(char: u8) void {
    // this is a custom "readline" capped at 10 characters
    switch (char) {
        '\n' => {
            vga.writeChar('\n');
            execute(command[0..command_len]);
            vga.writeString("> ");
            command_len = 0;
        },
        else => {
            if (command_len == 10)
                return;
            vga.writeChar(char);
            command[command_len] = char;
            command_len += 1;
        },
    }
}

pub fn initialize() void {
    // vga.clear();
    interrupt.registerIRQ(1, ps2.keyboard_handler);
    vga.writeString("> ");
}
