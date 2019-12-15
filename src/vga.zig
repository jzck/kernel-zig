usingnamespace @import("index.zig");
// const time = @import("time.zig");
// const x86 = @import("arch/x86/index.zig");
// const std = @import("std");
// Screen size.
pub const VGA_WIDTH = 80;
pub const VGA_HEIGHT = 25;
pub const VGA_SIZE = VGA_WIDTH * VGA_HEIGHT;
pub var vga = VGA{
    .vram = @intToPtr([*]VGAEntry, 0xb8000)[0..0x4000],
    .cursor = 80 * 2,
    .foreground = Color.Black,
    .background = Color.Green,
};

// Color codes.
pub const Color = enum(u4) {
    Black = 0,
    Blue = 1,
    Green = 2,
    Cyan = 3,
    Red = 4,
    Magenta = 5,
    Brown = 6,
    LightGrey = 7,
    DarkGrey = 8,
    LightBlue = 9,
    LightGreen = 10,
    LightCyan = 11,
    LightRed = 12,
    LightMagenta = 13,
    LightBrown = 14,
    White = 15,
};

// Character with attributes.
pub const VGAEntry = packed struct {
    char: u8,
    foreground: Color,
    background: Color,
};

// Enable hardware cursor.
pub fn enableCursor() void {
    outb(0x3D4, 0x0A);
    outb(0x3D5, 0x00);
}

// Disable hardware cursor.
pub fn disableCursor() void {
    outb(0x3D4, 0x0A);
    outb(0x3D5, 1 << 5);
}

const Errors = error{};
pub fn print(comptime format: []const u8, args: ...) void {
    var a = std.fmt.format({}, Errors, printCallback, format, args);
}
pub fn println(comptime format: []const u8, args: ...) void {
    var a = print(format ++ "\n", args);
}
pub fn clear() void {
    vga.clear();
}
pub fn topbar() void {
    const bg = vga.background;
    while (true) {
        if (time.offset_us / 1000000 == 4) task.usleep(2 * 1000 * 1000) catch unreachable;
        const cursor = vga.cursor;
        vga.cursor = 0;
        vga.background = Color.Red;
        vga.cursor_enabled = false;

        time.uptime();

        vga.cursor_enabled = true;
        vga.cursor = cursor;
        vga.background = bg;

        task.lock_scheduler();
        task.schedule();
    }
}

fn printCallback(context: void, string: []const u8) Errors!void {
    vga.writeString(string);
}

// VGA status.
const VGA = struct {
    vram: []VGAEntry,
    cursor: usize,
    cursor_enabled: bool = true,
    foreground: Color,
    background: Color,

    ////
    // Clear the screen.
    pub fn clear(self: *VGA) void {
        std.mem.set(VGAEntry, self.vram[0..VGA_SIZE], self.entry(' '));

        self.cursor = 80; // skip 1 line for topbar
        self.updateCursor();
    }

    ////
    // Print a character to the screen.
    //
    // Arguments:
    //     char: Character to be printed.
    //
    fn writeChar(self: *VGA, char: u8) void {
        if (self.cursor == VGA_WIDTH * VGA_HEIGHT - 1) {
            self.scrollDown();
        }

        switch (char) {
            // Newline.
            '\n' => {
                self.writeChar(' ');
                while (self.cursor % VGA_WIDTH != 0)
                    self.writeChar(' ');
            },
            // Tab.
            '\t' => {
                self.writeChar(' ');
                while (self.cursor % 4 != 0)
                    self.writeChar(' ');
            },
            // Backspace.
            '\x08' => {
                self.cursor -= 1;
                self.vram[self.cursor] = self.entry(' ');
            },
            // Any other character.
            else => {
                self.vram[self.cursor] = self.entry(char);
                self.cursor += 1;
            },
        }
        if (self.cursor_enabled) self.updateCursor();
    }

    ////
    // Print a string to the screen.
    //
    // Arguments:
    //     string: String to be printed.
    //
    pub fn writeString(self: *VGA, string: []const u8) void {
        for (string) |char| self.writeChar(char);
        if (self.cursor_enabled) self.updateCursor();
    }

    ////
    // Scroll the screen one line down.
    //
    fn scrollDown(self: *VGA) void {
        const first = VGA_WIDTH; // Index of first line.
        const second = 2 * VGA_WIDTH; // Index of first line.
        const last = VGA_SIZE - VGA_WIDTH; // Index of last line.

        // Copy all the screen (apart from the first line) up one line.
        // std.mem.copy(VGAEntry, self.vram[0..last], self.vram[first .. VGA_SIZE]); // whole screen
        std.mem.copy(VGAEntry, self.vram[first..last], self.vram[second..VGA_SIZE]); // skip topbar
        // Clean the last line.
        std.mem.set(VGAEntry, self.vram[last..VGA_SIZE], self.entry(' '));

        // Bring the cursor back to the beginning of the last line.
        self.cursor -= VGA_WIDTH;
    }

    ////
    // Update the position of the hardware cursor.
    // Use the software cursor as the source of truth.
    //
    pub fn updateCursor(self: *const VGA) void {
        x86.outb(0x3D4, 0x0F);
        x86.outb(0x3D5, @truncate(u8, self.cursor));
        x86.outb(0x3D4, 0x0E);
        x86.outb(0x3D5, @truncate(u8, self.cursor >> 8));
    }

    ////
    // Update the position of the software cursor.
    // Use the hardware cursor as the source of truth.
    //
    pub fn fetchCursor(self: *VGA) void {
        var cursor: usize = 0;

        x86.outb(0x3D4, 0x0E);
        cursor |= usize(x86.inb(0x3D5)) << 8;

        x86.outb(0x3D4, 0x0F);
        cursor |= x86.inb(0x3D5);

        self.cursor = cursor;
    }

    ////
    // Build a VGAEntry with current foreground and background.
    //
    // Arguments:
    //     char: The character of the entry.
    //
    // Returns:
    //     The requested VGAEntry.
    //
    fn entry(self: *VGA, char: u8) VGAEntry {
        return VGAEntry{
            .char = char,
            .foreground = self.foreground,
            .background = self.background,
        };
    }
};
