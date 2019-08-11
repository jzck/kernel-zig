usingnamespace @import("kernel").multiboot;
const assert = @import("std").debug.assert;
const vga = @import("../../vga.zig");
const std = @import("std");
const printf = @import("../../vga.zig").printf;

pub fn initialize(info: *const MultibootInfo) bumpAllocator {
    assert((info.flags & MULTIBOOT_INFO_MEMORY) != 0);
    assert((info.flags & MULTIBOOT_INFO_MEM_MAP) != 0);

    format_multibootinfo(info);
    return bumpAllocator.new(info);
}

pub fn format_multibootentry(entry: *MultibootMMapEntry) void {
    if (entry.type == MULTIBOOT_MEMORY_AVAILABLE) {
        vga.printf("AVAILABLE: ");
    } else {
        vga.printf("NOT AVAILABLE: ");
    }
    vga.printf("{x} ", entry.addr);
    if (entry.len / (1024 * 1024) > 0) {
        vga.printf("({} MB)\n", entry.len / (1024 * 1024));
    } else {
        vga.printf("({} kB)\n", entry.len / (1024));
    }
}

pub fn format_multibootinfo(info: *const MultibootInfo) void {
    var cmdline_ptr = @intToPtr([*c]const u8, info.cmdline);
    var cmdline = @ptrCast([*c]const u8, cmdline_ptr);
    // var cmdline = std.cstr.toSliceConst(info.cmdline);
    vga.printf("lower: {x}\n", info.mem_lower);
    vga.printf("upper: {x}\n", info.mem_upper);
    vga.printf("mmap_l: {}\n", info.mmap_length);
    vga.printf("mmap_a: {x}\n", info.mmap_addr);
    vga.printf("cmdline: {x}\n", cmdline_ptr);
    vga.printf("cmdline: {}\n", cmdline);

    var map: usize = info.mmap_addr;
    while (map < info.mmap_addr + info.mmap_length) {
        var entry = @intToPtr(*MultibootMMapEntry, map);
        format_multibootentry(entry);
        map += entry.size + @sizeOf(@typeOf(entry.size));
    }
}

// returns each available physical frame one by one in order
pub const bumpAllocator = struct {
    next_free_frame: physFrame,
    current_area: ?*MultibootMMapEntry,
    info: *const MultibootInfo,

    pub fn new(info: *const MultibootInfo) bumpAllocator {
        const first_area = @intToPtr(*MultibootMMapEntry, info.mmap_addr);
        var allocator = bumpAllocator{
            .current_area = first_area,
            .next_free_frame = physFrame.from_addr(first_area.addr),
            .info = info,
        };
        // allocator.choose_next_area();
        return allocator;
    }

    pub fn allocate(self: var, count: u64) ?physFrame {
        if (count == 0) {
            return null;
        }
        if (self.current_area == null) {
            return null;
        }
        if (self.current_area.?.type != MULTIBOOT_MEMORY_AVAILABLE) {
            self.choose_next_area();
            return self.allocate(count);
        }

        const start_frame = self.next_free_frame;
        const end_frame = self.next_free_frame.add(count - 1);
        const current_area_last_frame = physFrame.from_addr(self.current_area.?.addr + self.current_area.?.len);
        if (end_frame.number > current_area_last_frame.number) {
            self.choose_next_area();
            return self.allocate(count);
        }
        self.next_free_frame.number += count;
        return start_frame;
    }

    pub fn choose_next_area(self: var) void {
        printf("choosing next area\n");
        const current = self.current_area.?;
        var next_area = @ptrToInt(current) + current.size + @sizeOf(@typeOf(current));
        if (next_area >= self.info.mmap_addr + self.info.mmap_length) {
            self.current_area = null;
        } else {
            format_multibootentry(self.current_area.?);
            self.current_area = @intToPtr(*MultibootMMapEntry, next_area);
            format_multibootentry(self.current_area.?);
            self.next_free_frame = physFrame.from_addr(self.current_area.?.addr);
        }
    }
};

pub const PAGE_SIZE = 4096;

pub const physFrame = struct {
    number: u64,

    pub fn from_addr(addr: u64) physFrame {
        return physFrame{ .number = @divTrunc(addr, PAGE_SIZE) };
    }

    pub fn add(self: physFrame, count: u64) physFrame {
        return physFrame{ .number = self.number + count };
    }

    pub fn start_addr(self: physFrame) u64 {
        return (self.number * PAGE_SIZE);
    }
};

const PageDirectory = packed struct {
    entries: [1024]PageDirectoryEntry,
};

const PageDirectoryEntry = packed struct {
    address: u21,
    available: u2,
    ignored: u1,
    size: u1,
    zero: u1,
    accessed: u1,
    cache_disabled: u1,
    write_through: u1,
    user: u1,
    writeable: u1,
    present: u1,
};

const PageTable = packed struct {
    entries: [1024]PageTableEntry,
};

const PageTableEntry = packed struct {
    address: u21,
    available: u2,
    global: u1,
    zero: u1,
    dirty: u1,
    accessed: u1,
    cache_disabled: u1,
    write_through: u1,
    user: u1,
    writeable: u1,
    present: u1,
};

// assert(@sizeOf(PageTableEntry) == 32);
