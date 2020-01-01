usingnamespace @import("index.zig");

var input_ring: Ring(u8) = undefined;

var command: [10]u8 = undefined;
var command_len: usize = 0;

fn sleep_for_2() void {
    task.usleep(2 * 1000 * 1000) catch unreachable;
}

fn execute(input: []u8) void {
    const eql = std.mem.eql;
    if (eql(u8, input, "clear")) return vga.clear();
    if (eql(u8, input, "x86paging")) return x86.paging.format();
    if (eql(u8, input, "x86memory")) return x86.pmem.format();
    if (eql(u8, input, "tasks")) return task.format();
    if (eql(u8, input, "tasks")) return task.format_short();
    if (eql(u8, input, "lspci")) return pci.lspci();
    if (eql(u8, input, "sleep2")) return sleep_for_2();
    if (eql(u8, input, "uptime")) return time.uptime();
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

pub fn keyboard_callback(char: u8) void {
    input_ring.write(char);
}

pub fn loop() void {
    input_ring.init() catch unreachable;
    input_ring.task = task.current_task;
    ps2.keyboard_callback = keyboard_callback;
    print("> ");
    while (true) {
        while (input_ring.read()) |c| keypress(c);
        task.block(.IOWait);
    }
}
