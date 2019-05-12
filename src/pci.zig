const arch = @import("arch/x86/lib/index.zig");

const PCI_CONFIG_ADDRESS = 0xCF8;
const PCI_CONFIG_DATA = 0xCFC;
const vga = @import("vga.zig");

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
    device: u16,
    vendor: u16,
    class: u8,
    subclass: u8,
    header_type: u8,

    pub fn init(bus: u8, slot: u5, function: u3) ?PciDevice {
        var pcidevice = PciDevice{
            .bus = bus,
            .slot = slot,
            .function = function,
            .device = undefined,
            .class = undefined,
            .subclass = undefined,
            .header_type = undefined,
            .vendor = undefined,
        };
        pcidevice.vendor = pci_config_read_word(pcidevice, 0);
        if (pcidevice.vendor == 0xffff)
            return null;
        pcidevice.device = pci_config_read_word(pcidevice, 2);
        pcidevice.subclass = pci_config_read_byte(pcidevice, 10);
        pcidevice.class = pci_config_read_byte(pcidevice, 11);
        pcidevice.header_type = pci_config_read_byte(pcidevice, 14);
        return (pcidevice);
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
        vga.printf("{}:{}.{} {x},{x}: {x} {x}\n", self.bus, self.slot, self.function, self.class, self.subclass, self.vendor, self.device);
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
};

pub fn lspci() void {
    var slot: u5 = 0;
    while (true) {
        if (PciDevice.init(0, slot, 0)) |device| {
            device.format();
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
