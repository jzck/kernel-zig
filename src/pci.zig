const arch = @import("arch/x86/lib/index.zig");

const PCI_CONFIG_ADDRESS = 0xCF8;
const PCI_CONFIG_DATA = 0xCFC;
usingnamespace @import("vga.zig");
const virtio = @import("virtio.zig");

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
        var dev = PciDevice{
            .bus = bus,
            .slot = slot,
            .function = function,
        };
        dev.vendor = dev.config_read_word(0);
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
        print("{}:{}.{}", self.bus, self.slot, self.function);
        print(" {x},{x:2}(0x{x:4}): 0x{x} 0x{x}", self.class(), self.subclass(), self.subsystem(), self.vendor, self.device());
        if (self.driver()) |d|
            print(" {}", d.name);
        println("");
    }

    pub fn driver(self: PciDevice) ?Driver {
        var i: usize = 0;
        while (i < Drivers.len) : (i += 1) {
            var drv = Drivers[i];
            if (self.class() != drv.class or self.subclass() != drv.subclass)
                continue;
            if (drv.vendor) |v| if (self.vendor == v)
                continue;
            if (drv.subsystem) |ss| if (self.subsystem() == drv.subsystem.?)
                continue;
            return drv;
        }
        return null;
    }

    pub fn device(self: PciDevice) u16 {
        return self.config_read_word(2);
    }
    pub fn subclass(self: PciDevice) u16 {
        return self.config_read_byte(10);
    }
    pub fn class(self: PciDevice) u16 {
        return self.config_read_byte(11);
    }
    pub fn header_type(self: PciDevice) u16 {
        return self.config_read_byte(14);
    }
    pub fn subsystem(self: PciDevice) u16 {
        return self.config_read_word(0x2e);
    }

    pub fn access(self: PciDevice, offset: u8) void {
        arch.outl(PCI_CONFIG_ADDRESS, self.address(offset));
    }

    pub fn config_read_byte(self: PciDevice, offset: u8) u8 {
        self.access(offset);
        return (arch.inb(PCI_CONFIG_DATA));
    }

    pub fn config_read_word(self: PciDevice, offset: u8) u16 {
        self.access(offset);
        return (arch.inw(PCI_CONFIG_DATA));
    }

    pub fn config_read_long(self: PciDevice, offset: u8) u32 {
        self.access(offset);
        return (arch.inl(PCI_CONFIG_DATA));
    }
};

const Driver = struct {
    name: [*]u8,
    class: u8,
    subclass: u8,
    vendor: ?u16 = null,
    subsystem: ?u16 = null,
    init: fn (PciDevice) void,
};

const name = "virtio-blk";
pub var Drivers: [1]Driver = [_]Driver{Driver{ .name = &name, .class = 0x1, .subclass = 0x0, .vendor = 0x1af4, .subsystem = 0x2, .init = virtio.init }};

pub fn scan() void {
    var slot: u5 = 0;
    while (slot < 31) : (slot += 1) {
        if (PciDevice.init(0, slot, 0)) |device| {
            var function: u3 = 0;
            while (function < 8) : (function += 1) {
                if (PciDevice.init(0, slot, function)) |vf| {
                    if (vf.driver()) |d| d.init(vf);
                }
            }
        }
    }
}

pub fn lspci() void {
    var slot: u5 = 0;
    println("b:s.f c,s (ss)      v      d      drv");
    while (slot < 31) : (slot += 1) {
        if (PciDevice.init(0, slot, 0)) |device| {
            var function: u3 = 0;
            while (function < 8) : (function += 1) {
                if (PciDevice.init(0, slot, function)) |vf| {
                    vf.format();
                }
            }
        }
    }
}
