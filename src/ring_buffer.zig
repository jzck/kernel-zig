usingnamespace @import("index.zig");

pub fn Ring(comptime T: type) type {
    return struct {
        const Self = @This();
        const Size = u10; // 0-1023
        const size = @import("std").math.maxInt(Size);
        allocator: std.mem.Allocator = undefined,
        buffer: *[size]T,
        task: ?*task.TaskNode = null,
        read_index: Size = 0,
        write_index: Size = 0,

        pub fn init(ring: *Self, alloc: std.mem.Allocator) !void {
            ring.allocator = alloc;
            ring.buffer = try ring.allocator.create(@TypeOf(ring.buffer.*));
        }

        pub fn write(ring: *Self, elem: T) void {
            ring.buffer[ring.write_index] = elem;
            ring.write_index +%= 1;
            if (ring.task) |t| task.unblock(t);
        }

        pub fn read(ring: *Self) ?T {
            if (ring.write_index == ring.read_index) return null;
            const id = ring.read_index;
            ring.read_index +%= 1; // add with overflow to loop the ring
            return ring.buffer[id];
        }
    };
}
