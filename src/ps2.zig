usingnamespace @import("index.zig");
const x86 = @import("x86");

const PS2_DATA = 0x60;
const PS2_STATUS = 0x64;
const KEYMAP_US = [_][]const u8{
    "\x00\x00",
    "\x00\x00", //escape
    "1!",
    "2@",
    "3#",
    "4$",
    "5%",
    "6^",
    "7&",
    "8*",
    "9(",
    "0)",
    "-_",
    "=+",
    "\x08\x08", //backspace
    "\x00\x00", //tab
    "qQ",
    "wW",
    "eE",
    "rR",
    "tT",
    "yY",
    "uU",
    "iI",
    "oO",
    "pP",
    "[{",
    "]}",
    "\n\n",
    "\x00\x00", //left_control
    "aA",
    "sS",
    "dD",
    "fF",
    "gG",
    "hH",
    "jJ",
    "kK",
    "lL",
    ";:",
    "'\"",
    "`~",
    "\x00\x00", //left shift
    "\\|",
    "zZ",
    "xX",
    "cC",
    "vV",
    "bB",
    "nN",
    "mM",
    ",<",
    ".>",
    "/?",
    "\x00\x00", //right shift
    "**",
    "\x00\x00", //left alt
    "  ",
    "\x00\x00", //capslock
};

fn ps2_scancode() u8 {
    var scancode: u8 = 0;
    while (true) if (x86.io.inb(PS2_DATA) != scancode) {
        scancode = x86.io.inb(PS2_DATA);
        if (scancode > 0) return scancode;
    };
}

fn key_isrelease(scancode: u8) bool {
    return scancode & (1 << 7) != 0;
}

pub var keyboard_callback: fn (u8) void = undefined;

pub fn keyboard_handler() void {
    const scancode = ps2_scancode();
    if (scancode > KEYMAP_US.len) return;
    if (key_isrelease(scancode)) return; // don't process releases
    const shift = false; // don't know about modifiers yet
    const character = KEYMAP_US[scancode][if (shift) 1 else 0];
    if (keyboard_callback != undefined) keyboard_callback(character);
}
