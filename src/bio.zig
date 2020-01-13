// Block Device
// Glue code between Driver and FS

pub fn BlockDev(comptime sector_size: usize) type {
    return struct {
        const sector_size;
        read: fn (u64, *[sector_size]u8) void, //TODO: inferred !void or var (issue 447)
        write: ?fn (u64, *[sector_size]u8) void,
    };
}
