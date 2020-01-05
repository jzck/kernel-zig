usingnamespace @import("pci.zig");

const IDE_ATA = 0x00;
const IDE_ATAPI = 0x01;

const ATA_MASTER = 0x00;
const ATA_SLAVE = 0x01;

// Channels:
const ATA_PRIMARY = 0x00;
const ATA_SECONDARY = 0x01;

// Directions:
const ATA_READ = 0x00;
const ATA_WRITE = 0x01;

// Commands
const ATA_CMD_READ_PIO = 0x20;
const ATA_CMD_READ_PIO_EXT = 0x24;
const ATA_CMD_READ_DMA = 0xC8;
const ATA_CMD_READ_DMA_EXT = 0x25;
const ATA_CMD_WRITE_PIO = 0x30;
const ATA_CMD_WRITE_PIO_EXT = 0x34;
const ATA_CMD_WRITE_DMA = 0xCA;
const ATA_CMD_WRITE_DMA_EXT = 0x35;
const ATA_CMD_CACHE_FLUSH = 0xE7;
const ATA_CMD_CACHE_FLUSH_EXT = 0xEA;
const ATA_CMD_PACKET = 0xA0;
const ATA_CMD_IDENTIFY_PACKET = 0xA1;
const ATA_CMD_IDENTIFY = 0xEC;

// Status:
const ATA_SR_BSY = 0x80; // Busy
const ATA_SR_DRDY = 0x40; // Drive ready
const ATA_SR_DF = 0x20; // Drive write fault
const ATA_SR_DSC = 0x10; // Drive seek complete
const ATA_SR_DRQ = 0x08; // Data request ready
const ATA_SR_CORR = 0x04; // Corrected data
const ATA_SR_IDX = 0x02; // Index
const ATA_SR_ERR = 0x01; // Error

// Registers:
const ATA_REG_DATA = 0x00;
const ATA_REG_ERROR = 0x01;
const ATA_REG_FEATURES = 0x01;
const ATA_REG_SECCOUNT0 = 0x02;
const ATA_REG_LBA0 = 0x03;
const ATA_REG_LBA1 = 0x04;
const ATA_REG_LBA2 = 0x05;
const ATA_REG_HDDEVSEL = 0x06;
const ATA_REG_COMMAND = 0x07;
const ATA_REG_STATUS = 0x07;
const ATA_REG_SECCOUNT1 = 0x08;
const ATA_REG_LBA3 = 0x09;
const ATA_REG_LBA4 = 0x0A;
const ATA_REG_LBA5 = 0x0B;
const ATA_REG_CONTROL = 0x0C;
const ATA_REG_ALTSTATUS = 0x0C;
const ATA_REG_DEVADDRESS = 0x0D;

// Identification space
const ATA_IDENT_DEVICETYPE = 0;
const ATA_IDENT_CYLINDERS = 2;
const ATA_IDENT_HEADS = 6;
const ATA_IDENT_SECTORS = 12;
const ATA_IDENT_SERIAL = 20;
const ATA_IDENT_MODEL = 54;
const ATA_IDENT_CAPABILITIES = 98;
const ATA_IDENT_FIELDVALID = 106;
const ATA_IDENT_MAX_LBA = 120;
const ATA_IDENT_COMMANDSETS = 164;
const ATA_IDENT_MAX_LBA_EXT = 200;

const ide_buf: [2048]u8 = [1]u8{0} ** 2048;
const atapi_packet: [12]u8 = [1]u8{0xA8} ++ [1]u8{0} ** 11;
const ide_irq_invoked = false;

const IDEDevice = struct {
    reserved: u8, // 0 (Empty) or 1 (This Drive really exists).
    channel: u8, // 0 (Primary Channel) or 1 (Secondary Channel).
    drive: u8, // 0 (Master Drive) or 1 (Slave Drive).
    idetype: u16, // 0: ATA, 1:ATAPI.
    signature: u16, // Drive Signature
    capabilities: u16, // Features.
    commandsets: usize, // Command Sets Supported.
    size: usize, // Size in Sectors.
    model: [41]u8, // Model in string.
};

var ide_devices: [4]IDEDevice = undefined;

const IDEChannelRegister = struct {
    base: u16, // I/O Base.
    ctrl: u16, // Control Base
    bmide: u16, // Bus Master IDE
    nIEN: u8, // nIEN (No Interrupt);
};

var channels: [2]IDEChannelRegister = undefined;

pub inline fn ide_read(channel: u8, comptime reg: u8) u8 {
    if (reg > 0x07 and reg < 0x0C) ide_write(channel, ATA_REG_CONTROL, 0x80 | channels[channel].nIEN);
    defer if (reg > 0x07 and reg < 0x0C) ide_write(channel, ATA_REG_CONTROL, channels[channel].nIEN);
    return switch (reg) {
        0x0...0x7 => x86.inb(channels[channel].base + reg - 0x0),
        0x8...0xb => x86.inb(channels[channel].base + reg - 0x6),
        0xc...0xd => x86.inb(channels[channel].ctrl + reg - 0xa),
        0xe...0x16 => x86.inb(channels[channel].bmide + reg - 0xe),
        else => @compileError("bad IDE register."),
    };
}

pub inline fn ide_read_buffer(channel: u8, comptime reg: u8, buf: var, cnt: usize) void {
    if (reg > 0x07 and reg < 0x0C) ide_write(channel, ATA_REG_CONTROL, 0x80 | channels[channel].nIEN);
    defer if (reg > 0x07 and reg < 0x0C) ide_write(channel, ATA_REG_CONTROL, channels[channel].nIEN);
    switch (reg) {
        0x0...0x7 => x86.insl(channels[channel].base + reg - 0x0, buf, cnt),
        0x8...0xb => x86.insl(channels[channel].base + reg - 0x6, buf, cnt),
        0xc...0xd => x86.insl(channels[channel].ctrl + reg - 0xa, buf, cnt),
        0xe...0x16 => x86.insl(channels[channel].bmide + reg - 0xe, buf, cnt),
        else => @compileError("bad IDE register."),
    }
}

pub inline fn ide_write(channel: u8, comptime reg: u8, data: u8) void {
    if (reg > 0x07 and reg < 0x0C) ide_write(channel, ATA_REG_CONTROL, 0x80 | channels[channel].nIEN);
    defer if (reg > 0x07 and reg < 0x0C) ide_write(channel, ATA_REG_CONTROL, channels[channel].nIEN);
    switch (reg) {
        0x0...0x7 => x86.outb(channels[channel].base + reg - 0x0, data),
        0x8...0xb => x86.outb(channels[channel].base + reg - 0x6, data),
        0xc...0xd => x86.outb(channels[channel].ctrl + reg - 0xa, data),
        0xe...0x16 => x86.outb(channels[channel].bmide + reg - 0xe, data),
        else => @compileError("bad IDE register."),
    }
}

pub fn init(dev: PciDevice) void {
    println("-- ide init --");
    print("[ide] ");
    dev.format();
    assert(dev.header_type() == 0x0); // mass storage device

    dev.config_write(@intCast(u8, 0xfe), 0x3c);
    if (dev.intr_line() == 0xfe) {
        println("[ide] needs IRQ assignement");
    } else {
        println("The device doesn't use IRQs");
    }

    const BAR0 = @intCast(u16, dev.bar(0));
    const BAR1 = @intCast(u16, dev.bar(1));
    const BAR2 = @intCast(u16, dev.bar(2));
    const BAR3 = @intCast(u16, dev.bar(3));
    const BAR4 = @intCast(u16, dev.bar(4));
    channels[ATA_PRIMARY].base = if (BAR0 == 0) 0x1f0 else BAR0;
    channels[ATA_PRIMARY].ctrl = if (BAR1 == 0) 0x3F6 else BAR1;
    channels[ATA_SECONDARY].base = if (BAR2 == 0) 0x170 else BAR2;
    channels[ATA_SECONDARY].ctrl = if (BAR3 == 0) 0x376 else BAR3;
    channels[ATA_PRIMARY].bmide = (BAR4 & 0xFFFC); // Bus Master IDE
    channels[ATA_SECONDARY].bmide = (BAR4 & 0xFFFC) + 8; // Bus Master IDE

    // turn off irqs
    ide_write(ATA_PRIMARY, ATA_REG_CONTROL, 2);
    ide_write(ATA_SECONDARY, ATA_REG_CONTROL, 2);

    // parse identification space
    var count: usize = 0;
    var err: u8 = 0;
    var status: u8 = 0;
    for ([_]u8{ 0, 1 }) |i| {
        for ([_]u8{ 0, 1 }) |j| {
            var idetype: u8 = IDE_ATA;
            ide_devices[count].reserved = 0; // Assuming that no drive here.

            // (I) Select Drive:
            ide_write(i, ATA_REG_HDDEVSEL, 0xA0 | (j << 4)); // Select Drive.
            task.usleep(1000) catch unreachable; // Wait 1ms for drive select to work.

            // (II) Send ATA Identify Command:
            ide_write(i, ATA_REG_COMMAND, ATA_CMD_IDENTIFY);
            task.usleep(1000) catch unreachable;

            if (ide_read(i, ATA_REG_STATUS) == 0) continue; // If Status = 0, No Device.
            while (true) {
                status = ide_read(i, ATA_REG_STATUS);
                if (status & ATA_SR_ERR != 0) {
                    err = 1;
                    break;
                } // If Err, Device is not ATA.
                if ((status & ATA_SR_BSY == 0) and (status & ATA_SR_DRQ != 0)) break; // Everything is right.
            }

            // (IV) Probe for ATAPI Devices:)
            if (err != 0) {
                // Device is not ATA
                const cl = ide_read(i, ATA_REG_LBA1);
                const ch = ide_read(i, ATA_REG_LBA2);

                if (cl == 0x14 and ch == 0xEB) idetype = IDE_ATAPI;
                if (cl == 0x69 and ch == 0x96) idetype = IDE_ATAPI;
                if (idetype != IDE_ATAPI) continue; // Unknown Type (may not be a device).

                ide_write(i, ATA_REG_COMMAND, ATA_CMD_IDENTIFY_PACKET);
                task.usleep(1000) catch unreachable;
            }

            // (V) Read Identification Space of the Device:
            ide_read_buffer(i, ATA_REG_DATA, &ide_buf, 128);

            ide_devices[count].reserved = 1;
            ide_devices[count].idetype = idetype;
            ide_devices[count].channel = i;
            ide_devices[count].drive = j;
            ide_devices[count].signature = @ptrCast(*const u8, &ide_buf[ATA_IDENT_DEVICETYPE]).*;
            ide_devices[count].capabilities = @ptrCast(*const u8, &ide_buf[ATA_IDENT_CAPABILITIES]).*;
            ide_devices[count].commandsets = @ptrCast(*const usize, &ide_buf[ATA_IDENT_COMMANDSETS]).*;

            // (VII) Get Size:
            if (ide_devices[count].commandsets & (1 << 26) != 0) {
                // Device uses 48-Bit Addressing:
                ide_devices[count].size = @ptrCast(*const usize, &ide_buf[ATA_IDENT_MAX_LBA_EXT]).*;
            } else {
                // Device uses CHS or 28-bit Addressing:
                ide_devices[count].size = @ptrCast(*const usize, &ide_buf[ATA_IDENT_MAX_LBA]).*;
            }

            // (VIII) String indicates model of device (like Western Digital HDD and SONY DVD-RW...):
            var k: u16 = 0;
            while (k < 40) : (k = k + 2) {
                ide_devices[count].model[k] = ide_buf[ATA_IDENT_MODEL + k + 1];
                ide_devices[count].model[k + 1] = ide_buf[ATA_IDENT_MODEL + k];
            }
            ide_devices[count].model[40] = 0; // Terminate String.

            count = count + 1;
        }
    }
    // 4- Print Summary:
    for ([_]u8{ 0, 1, 2, 3 }) |i| {
        if (ide_devices[i].reserved == 1) {
            println(
                "[ide] found {} Drive {}GB - {}",
                if (ide_devices[i].idetype == 0) "ATA" else "ATAPI",
                ide_devices[i].size / 1024 / 1024 / 2,
                ide_devices[i].model,
            );
        }
    }
}
