pub const std = @import("std");

pub const kernel = @import("index.zig");
pub const x86 = @import("x86.zig");
pub const driver = @import("driver/index.zig");

const PCI_CONFIG_ADDRESS = 0xCF8;
const PCI_CONFIG_DATA = 0xCFC;

// https://wiki.osdev.org/Pci
pub const PciAddress = packed struct {
    offset: u8,
    function: u3,
    slot: u5,
    bus: u8,
    reserved: u7,
    enable: u1,
};

pub const PciDevice = struct {
    bus: u8,
    slot: u5,
    function: u3,
    vendor: u16 = undefined,

    pub fn init(bus: u8, slot: u5, function: u3) ?PciDevice {
        var dev = PciDevice{ .bus = bus, .slot = slot, .function = function };
        dev.vendor = dev.vendor_id();
        if (dev.vendor == 0xffff) return null;
        return dev;
    }

    pub fn address(self: PciDevice, offset: u8) u32 {
        var addr = PciAddress{
            .enable = 1,
            .reserved = 0,
            .bus = self.bus,
            .slot = self.slot,
            .function = self.function,
            .offset = offset,
        };
        return @bitCast(u32, addr);
    }

    pub fn format(self: PciDevice) void {
        kernel.vga.print("{}:{}.{}", .{ self.bus, self.slot, self.function });
        kernel.vga.print(" {x},{x:2}", .{ self.class(), self.subclass() });
        kernel.vga.print(" 0x{x} 0x{x}", .{ self.vendor, self.device() });
        kernel.vga.println(" {}", .{if (self.driver()) |d| d.name else " (none)"});
    }

    pub fn driver(self: PciDevice) ?Driver {
        var i: usize = 0;
        while (i < Drivers.len) : (i += 1) {
            var drv = Drivers[i];
            if (self.class() != drv.class or self.subclass() != drv.subclass)
                continue;
            if (drv.vendor) |v|
                if (self.vendor != v)
                    continue;
            if (drv.subsystem) |ss|
                if (self.subsystem() != ss)
                    continue;
            return drv;
        }
        return null;
    }

    // 0                   1                   2                   3
    // 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
    // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    // |           vendor ID           |           device ID           |
    // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    // |            command            |             status            |
    // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    // |  revision ID  |    prog IF    |    subclass   |     class     |
    // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    // |cache line size| latency timer |   header type |      bist     |
    // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    pub fn vendor_id(self: PciDevice) u16 {
        return self.config_read(u16, 0x0);
    }
    pub fn device(self: PciDevice) u16 {
        return self.config_read(u16, 0x2);
    }
    pub fn subclass(self: PciDevice) u8 {
        return self.config_read(u8, 0xa);
    }
    pub fn class(self: PciDevice) u8 {
        return self.config_read(u8, 0xb);
    }
    pub fn header_type(self: PciDevice) u8 {
        return self.config_read(u8, 0xe);
    }
    pub fn intr_line(self: PciDevice) u8 {
        return self.config_read(u8, 0x3c);
    }
    pub fn bar(self: PciDevice, comptime n: usize) u32 {
        std.debug.assert(n <= 5);
        return self.config_read(u32, 0x10 + 4 * n);
    }
    // only for header_type == 0
    pub fn subsystem(self: PciDevice) u16 {
        return self.config_read(u8, 0x2e);
    }

    pub inline fn config_write(self: PciDevice, value: anytype, comptime offset: u8) void {
        // ask for access before writing config
        x86.outl(PCI_CONFIG_ADDRESS, self.address(offset));
        switch (@TypeOf(value)) {
            // read the correct size
            u8 => return x86.outb(PCI_CONFIG_DATA, value),
            u16 => return x86.outw(PCI_CONFIG_DATA, value),
            u32 => return x86.outl(PCI_CONFIG_DATA, value),
            else => @compileError("pci config space only supports writing u8, u16, u32."),
        }
    }

    pub inline fn config_read(self: PciDevice, comptime size: type, comptime offset: u8) size {
        // ask for access before reading config
        x86.outl(PCI_CONFIG_ADDRESS, self.address(offset));
        switch (size) {
            // read the correct size
            u8 => return x86.inb(PCI_CONFIG_DATA),
            u16 => return x86.inw(PCI_CONFIG_DATA),
            u32 => return x86.inl(PCI_CONFIG_DATA),
            else => @compileError("pci config space only supports reading u8, u16, u32."),
        }
    }
};

const Driver = struct {
    name: []const u8,
    class: u8,
    subclass: u8,
    vendor: ?u16 = null,
    subsystem: ?u16 = null,
    init: fn (PciDevice) void,
};

const Drivers = [_]Driver{
    Driver{
        .name = "virtio-blk",
        .class = 0x1,
        .subclass = 0x0,
        .vendor = 0x1af4,
        .subsystem = 0x2,
        .init = driver.virtio.init,
    },
    Driver{
        .name = "ide-ata",
        .class = 0x1,
        .subclass = 0x1,
        .init = driver.ide.init,
    },
};

// TODO: factor 2 functions with a closure or a generator when released
pub fn scan() void {
    var slot: u5 = 0;
    // 0..31
    while (slot < 31) : (slot += 1) {
        if (PciDevice.init(0, slot, 0)) |dev| {
            var function: u3 = 0;
            // 0..7
            while (function < 7) : (function += 1) {
                if (PciDevice.init(0, slot, function)) |vf| {
                    if (vf.driver()) |d| d.init(vf);
                }
            }
        }
    }
}

pub fn lspci() void {
    var slot: u5 = 0;
    kernel.vga.println("b:s.f c, s vendor device driver", .{});
    while (slot < 31) : (slot += 1) {
        if (PciDevice.init(0, slot, 0)) |dev| {
            var function: u3 = 0;
            // 0..7
            while (function < 7) : (function += 1) {
                if (PciDevice.init(0, slot, function)) |vf| {
                    vf.format();
                }
            }
        }
    }
}
