usingnamespace @import("index.zig");

pub fn init(dev: kernel.pci.PciDevice) void {
    kernel.println("-- virtio-block init --");
    dev.format();
    assert(dev.header_type() == 0x0); // mass storage device
    assert(dev.subsystem() == 0x2); // virtio-block

    const intr_line = dev.config_read(u8, 0x3c);
    const intr_pin = dev.config_read(u8, 0x3d);
    const min_grant = dev.config_read(u8, 0x3e);
    const max_lat = dev.config_read(u8, 0x3f);
    kernel.println("{x} {} {} {}", intr_line, intr_pin, min_grant, max_lat);

    // all virtio
    // 0                   1                   2                   3
    //  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
    // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    // |                          dev features                         |
    // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    // |                         guest features                        |
    // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    // |                         queue address                         |
    // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    // |           queue size          |          queue notify         |
    // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    // | device status |   isr status  |
    // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

    // println("dev feats    =0x{x}", dev.config_read(u32, 0x10));
    // println("guest feats  =0x{x}", dev.config_read(u32, 0x14));
    // println("queue addr   =0x{x}", dev.config_read(u32, 0x18));
    // println("queue size   =0x{x}", dev.config_read(u16, 0x1c));
    // println("queue select =0x{x}", dev.config_read(u16, 0x1e));
    // println("queue notify =0x{x}", dev.config_read(u16, 0x20));
    // println("device status=0x{x}", dev.config_read(u8, 0x22));
    // println("isr status   =0x{x}", dev.config_read(u8, 0x23));

    // all virtio-block
    // println("Total Sector Count={}", dev.config_read(u32, 0x24));
    // println("Total Sector Count={}", dev.config_read(u32, 0x28));
    // println("Maximum Seg Size  ={}", dev.config_read(u16, 0x2c));
    // println("Maximum Seg Count ={}", dev.config_read(u32, 0x30));
    // println("Cylinder Count    ={}", dev.config_read(u16, 0x34));
    // println("Head Count        ={}", dev.config_read(u8, 0x36));
    // println("Sector Count      ={}", dev.config_read(u8, 0x37));
    // println("Block Length      ={}", dev.config_read(u8, 0x38));
}
