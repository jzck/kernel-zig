const arch = @import("arch/x86/lib/index.zig");

const PCI_CONFIG_ADDRESS = 0xCF8;
const PCI_CONFIG_DATA = 0xCFC;
usingnamespace @import("vga.zig");

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
    device: u16 = undefined,
    vendor: u16 = undefined,
    class: u8 = undefined,
    subclass: u8 = undefined,
    header_type: u8 = undefined,
    driver: ?Driver = null,

    pub fn init(bus: u8, slot: u5, function: u3) ?PciDevice {
        var dev = PciDevice{
            .bus = bus,
            .slot = slot,
            .function = function,
        };
        dev.vendor = dev.pci_config_read_word(0);
        if (dev.vendor == 0xffff)
            return null;
        dev.device = dev.pci_config_read_word(2);
        dev.subclass = dev.pci_config_read_byte(10);
        dev.class = dev.pci_config_read_byte(11);
        dev.header_type = dev.pci_config_read_byte(14);
        dev.driver = dev.get_driver();
        return (dev);
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
        return (@bitCast(u32, addr));
    }

    pub fn format(self: PciDevice) void {
        print("{}:{}.{}", self.bus, self.slot, self.function);
        print(" {x},{x}: {x} {x}", self.class, self.subclass, self.vendor, self.device);
        if (self.driver) |d|
            print(" {}", d.name);
        println("");
    }

    pub fn access(self: PciDevice, offset: u8) void {
        arch.outl(PCI_CONFIG_ADDRESS, self.address(offset));
    }

    pub fn pci_config_read_byte(self: PciDevice, offset: u8) u8 {
        self.access(offset);
        return (arch.inb(PCI_CONFIG_DATA));
    }

    pub fn pci_config_read_word(self: PciDevice, offset: u8) u16 {
        self.access(offset);
        return (arch.inw(PCI_CONFIG_DATA));
    }

    pub fn pci_config_read_long(self: PciDevice, offset: u8) u32 {
        self.access(offset);
        return (arch.inl(PCI_CONFIG_DATA));
    }

    pub fn get_driver(self: PciDevice) ?Driver {
        var i: usize = 0;
        while (i < Drivers.len) : (i += 1) {
            var driver = Drivers[i];
            if (self.class == driver.class and self.subclass == driver.subclass and (driver.vendor == null or self.vendor == driver.vendor.?)) {
                return driver;
            }
        }
        return null;
    }
};

const Driver = struct {
    name: [*]u8,
    class: u8,
    subclass: u8,
    vendor: ?u16 = null,
};

const name = "virtio-blk";
pub var Drivers: [1]Driver = [_]Driver{Driver{ .name = &name, .class = 0x1, .subclass = 0x0, .vendor = 0x1af4 }};

pub fn lspci() void {
    var slot: u5 = 0;
    while (true) {
        if (PciDevice.init(0, slot, 0)) |device| {
            var function: u3 = 0;
            while (true) {
                if (PciDevice.init(0, slot, function)) |vf|
                    vf.format();
                if (function == 7) break else function += 1;
            }
        }
        if (slot == 31) break else slot += 1;
    }
}
