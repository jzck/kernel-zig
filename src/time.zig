usingnamespace @import("index.zig");

pub var offset_s: u32 = 0;
pub var offset_us: u32 = 0;
pub fn increment(value: u32) void {
    const sum = offset_us + value;
    offset_s += sum / 1000000;
    offset_us = sum % 1000000;
}

pub fn uptime() void {
    const offset_ms = offset_us / 1000;
    println("uptime: {}.{:.3}", offset_s, offset_ms);
}
