usingnamespace @import("index.zig");

var input_ring: Ring(u8) = undefined;

var command: [10]u8 = undefined;
var command_len: usize = 0;

fn sleep2() void {
    task.usleep(2 * 1000 * 1000) catch unreachable;
}

fn t_sleep2() void {
    _ = task.new(@ptrToInt(sleep2)) catch unreachable;
}

const Command = struct {
    name: []const u8,
    f: fn () void,
};

const commands = [_]Command{
    Command{ .name = "clear", .f = clear },
    Command{ .name = "paging", .f = x86.paging.format },
    Command{ .name = "memory", .f = x86.pmem.format },
    Command{ .name = "tasks", .f = task.format },
    Command{ .name = "lspci", .f = pci.lspci },
    Command{ .name = "sleep2", .f = sleep2 },
    Command{ .name = "t-sleep2", .f = t_sleep2 },
    Command{ .name = "uptime", .f = time.uptime },
};

fn execute(input: []u8) void {
    for (commands) |c| if (std.mem.eql(u8, input, c.name)) return c.f();
    println("{}: command not found, list of available commands:", .{input});
    for (commands) |c| println("{}", .{c.name});
}

pub fn keypress(char: u8) void {
    // this is a custom "readline" capped at 10 characters
    switch (char) {
        '\n' => {
            print("\n", .{});
            if (command_len > 0) execute(command[0..command_len]);
            print("> ", .{});
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
    input_ring.init(vmem.allocator) catch unreachable;
    input_ring.task = task.current_task;
    ps2.keyboard_callback = keyboard_callback;
    print("> ", .{});
    while (true) {
        while (input_ring.read()) |c| keypress(c);
        task.block(.IOWait);
    }
}
