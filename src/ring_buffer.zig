usingnamespace @import("index.zig");

pub fn Ring(comptime T: type) type {
    return struct {
        const Self = @This();
        const Size = u10; // 0-1024
        const size = @import("std").math.maxInt(Size);
        buffer: *[size]T,
        task: ?*task.TaskNode = null,
        read_index: Size = 0,
        write_index: Size = 0,

        //TODO: allocator argument and remove the namespace
        pub fn init(ring: *Self) !void {
            ring.buffer = try vmem.create(@typeOf(ring.buffer.*));
        }

        pub fn write(ring: *Self, elem: T) void {
            ring.buffer[ring.write_index] = elem;
            ring.write_index +%= 1;
            if (ring.task) |t| task.unblock(t);
        }

        pub fn read(ring: *Self) ?T {
            if (ring.write_index == ring.read_index) return null;
            const id = ring.read_index;
            ring.read_index +%= 1;
            return ring.buffer[id];
        }
    };
}
