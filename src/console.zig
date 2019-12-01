usingnamespace @import("index.zig");

var command: [10]u8 = undefined;
var command_len: usize = 0;

fn execute(input: []u8) void {
    const eql = std.mem.eql;
    if (eql(u8, input, "x86paging")) return x86.paging.introspect();
    if (eql(u8, input, "x86memory")) return x86.pmem.introspect();
    if (eql(u8, input, "tasks")) return task.introspect();
    if (eql(u8, input, "lspci")) return pci.lspci();
    if (eql(u8, input, "uptime")) return time.uptime();
    if (eql(u8, input, "topbar")) return topbar();
    println("{}: command not found", input);
}

pub fn keypress(char: u8) void {
    // this is a custom "readline" capped at 10 characters
    switch (char) {
        '\n' => {
            print("\n");
            if (command_len > 0) execute(command[0..command_len]);
            print("> ");
            command_len = 0;
        },
        '\x00' => return,
        '\x08' => {
            // backspace
            if (command_len == 0) return;
            vga.writeChar(char);
            command_len -= 1;
            command[command_len] = '\x00';
        },
        else => {
            // general case
            if (command_len == 10) return;
            vga.writeChar(char);
            command[command_len] = char;
            command_len += 1;
        },
    }
}

pub fn initialize() void {
    ps2.keyboard_callback = keypress;
    print("> ");
}
