usingnamespace @import("vga.zig");
usingnamespace @import("pci.zig");
const assert = @import("std").debug.assert;

pub fn init(pci: PciDevice) void {
    println("-- virtio-block init --");
    pci.format();
    assert(pci.header_type() == 0x0); // mass storage device
    assert(pci.subsystem() == 0x2); // virtio-block
    const intr_line = pci.config_read(u8, 0x3c);
    const intr_pin = pci.config_read(u8, 0x3d);
    const min_grant = pci.config_read(u8, 0x3e);
    const max_lat = pci.config_read(u8, 0x3f);
    println("{x} {} {} {}", intr_line, intr_pin, min_grant, max_lat);
    println("bar0=0x{x}", pci.config_read(u32, 0x10));
    println("bar1=0x{x}", pci.config_read(u32, 0x14));
    println("bar2=0x{x}", pci.config_read(u32, 0x18));
    println("bar3=0x{x}", pci.config_read(u32, 0x1c));
    println("bar4=0x{x}", pci.config_read(u32, 0x20));
    println("bar5=0x{x}", pci.config_read(u32, 0x24));
}
