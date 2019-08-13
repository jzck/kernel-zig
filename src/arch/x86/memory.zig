usingnamespace @import("kernel").multiboot;
usingnamespace @import("../../vga.zig");
const assert = @import("std").debug.assert;
const std = @import("std");

pub var allocator: bumpAllocator = undefined;

pub fn initialize(info: *const MultibootInfo) void {
    assert((info.flags & MULTIBOOT_INFO_MEMORY) != 0);
    assert((info.flags & MULTIBOOT_INFO_MEM_MAP) != 0);

    format_multibootinfo(info);
    allocator = bumpAllocator.new(info);
}

fn format_multibootentry(entry: *MultibootMMapEntry) void {
    if (entry.type == MULTIBOOT_MEMORY_AVAILABLE) {
        print("    AVAILABLE: ");
    } else {
        print("NOT AVAILABLE: ");
    }
    print("{x} ", entry.addr);
    if (entry.len / (1024 * 1024) > 0) {
        println("({} MB)", entry.len / (1024 * 1024));
    } else {
        println("({} kB)", entry.len / (1024));
    }
}

fn format_multibootinfo(info: *const MultibootInfo) void {
    var cmdline_ptr = @intToPtr([*c]const u8, info.cmdline);
    var cmdline = @ptrCast([*c]const u8, cmdline_ptr);
    // var cmdline = std.cstr.toSliceConst(info.cmdline);
    println("flags: {b}", info.flags);
    println("lower: {x}", info.mem_lower);
    println("upper: {x}", info.mem_upper);
    println("mmap_l: {}", info.mmap_length);
    println("mmap_a: {x}", info.mmap_addr);
    println("cmdline: {x}", cmdline_ptr);
    println("cmdline: {}", cmdline);

    var map: usize = info.mmap_addr;
    while (map < info.mmap_addr + info.mmap_length) {
        var entry = @intToPtr(*MultibootMMapEntry, map);
        format_multibootentry(entry);
        map += entry.size + @sizeOf(@typeOf(entry.size));
    }
}

// returns each available physical frame one by one in order
pub const bumpAllocator = struct {
    next_free_frame: PhysFrame,
    current_area: ?*MultibootMMapEntry,
    info: *const MultibootInfo,

    pub fn new(info: *const MultibootInfo) bumpAllocator {
        const first_area = @intToPtr(*MultibootMMapEntry, info.mmap_addr);
        var allocato = bumpAllocator{
            .current_area = first_area,
            .next_free_frame = PhysFrame.from_addr(@intCast(u32, first_area.addr)),
            .info = info,
        };
        return allocato;
    }

    pub fn allocate(self: var, count: u32) ?PhysFrame {
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
        // <4MB identity mapped kernel, lazy trick
        if (PhysFrame.start_addr(self.next_free_frame) < 0x400000) {
            self.next_free_frame.number += 1;
            return self.allocate(count);
        }

        const start_frame = self.next_free_frame;
        const end_frame = self.next_free_frame.add(count - 1);
        const current_area_last_frame = PhysFrame.from_addr(@intCast(u32, self.current_area.?.addr + self.current_area.?.len));
        if (end_frame.number > current_area_last_frame.number) {
            self.choose_next_area();
            return self.allocate(count);
        }
        self.next_free_frame.number += count;
        return start_frame;
    }

    pub fn choose_next_area(self: var) void {
        println("choosing next area");
        const current = self.current_area.?;
        var next_area = @ptrToInt(current) + current.size + @sizeOf(@typeOf(current));
        if (next_area >= self.info.mmap_addr + self.info.mmap_length) {
            self.current_area = null;
        } else {
            self.current_area = @intToPtr(*MultibootMMapEntry, next_area);
            format_multibootentry(self.current_area.?);
            self.next_free_frame = PhysFrame.from_addr(@intCast(u32, self.current_area.?.addr));
        }
    }
};

pub const PAGE_SIZE = 4096;

pub const PhysFrame = struct {
    number: u32,

    pub fn from_addr(addr: u32) PhysFrame {
        return PhysFrame{ .number = @divTrunc(addr, PAGE_SIZE) };
    }

    pub fn add(self: PhysFrame, count: u32) PhysFrame {
        return PhysFrame{ .number = self.number + count };
    }

    pub fn start_addr(self: PhysFrame) u32 {
        return (self.number * PAGE_SIZE);
    }
};
