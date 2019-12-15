usingnamespace @import("index.zig");

pub var offset_us: u64 = 0;
pub fn increment(value: u32) void {
    offset_us += value;
}

pub fn uptime() void {
    var offset_ms: u64 = offset_us / 1000;
    const offset_s: u64 = offset_ms / 1000;
    offset_ms = @mod(offset_ms / 100, 10);
    print("{}.{:.3}", offset_s, offset_ms);
}
