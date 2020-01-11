// Block Device
// Glue code between Driver and FS

pub const BlockDev = struct {
    read: fn (u64) void,
};
