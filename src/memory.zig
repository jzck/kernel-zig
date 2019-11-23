pub usingnamespace @import("index.zig");

pub fn allocate(comptime T: type) !*type {}

pub fn free(address: usize) void {}

pub fn initialize() void {}
