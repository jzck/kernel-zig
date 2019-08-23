usingnamespace @import("pci.zig");

pub fn init(dev: PciDevice) void {
    println("-- virtio-block init --");
    dev.format();
    assert(dev.header_type() == 0x0); // mass storage device
    assert(dev.subsystem() == 0x2); // virtio-block

    const intr_line = dev.config_read(u8, 0x3c);
    const intr_pin = dev.config_read(u8, 0x3d);
    const min_grant = dev.config_read(u8, 0x3e);
    const max_lat = dev.config_read(u8, 0x3f);
    println("{x} {} {} {}", intr_line, intr_pin, min_grant, max_lat);

    println("dev features  =0x{x}", dev.config_read(u32, 0x10));
    println("guest features=0x{x}", dev.config_read(u32, 0x14));
    println("queue addr    =0x{x}", dev.config_read(u32, 0x18));
    println("queue size    =0x{x}", dev.config_read(u16, 0x1c));
    println("queue select  =0x{x}", dev.config_read(u16, 0x1e));
    println("queue notify  =0x{x}", dev.config_read(u16, 0x20));
    println("device status =0x{x}", dev.config_read(u8, 0x22));
    println("isr status    =0x{x}", dev.config_read(u8, 0x23));
}
