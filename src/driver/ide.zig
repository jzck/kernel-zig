usingnamespace @import("index.zig");

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
var ide_irq_invoked = false;

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

inline fn ide_polling(channel: u8, comptime advanced_check: bool) ?u8 {
    // (I) Delay 400 nanosecond for BSY to be set:
    for ([_]u8{ 0, 1, 2, 3 }) |_| _ = ide_read(channel, ATA_REG_ALTSTATUS); // wate 100ns per call
    while (ide_read(channel, ATA_REG_STATUS) & ATA_SR_BSY != 0) {} // Wait for BSY to be zero.
    if (advanced_check) {
        const state = ide_read(channel, ATA_REG_STATUS); // Read Status Register.
        if (state & ATA_SR_ERR != 0) return u8(2); // Error.
        if (state & ATA_SR_DF != 0) return 1; // Device Fault.
        if ((state & ATA_SR_DRQ) == 0) return 3; // DRQ should be set
    }
    return null; // No Error.
}

fn ide_ata_access(direction: u8, drive: u8, lba: u64, numsects: u8, selector: u16, edi: usize) u8 {
    var dma = false; // 0: No DMA, 1: DMA
    var cmd: u8 = 0;
    var lba_io = [1]u8{0} ** 8;
    const channel = ide_devices[drive].channel; // Read the Channel.
    const slavebit = ide_devices[drive].drive; // Read the Drive [Master/Slave]
    const bus: usize = channels[channel].base; // Bus Base, like 0x1F0 which is also data port.
    var words: usize = 256; // Almost every ATA drive has a sector-size of 512-byte.

    ide_irq_invoked = false;
    channels[channel].nIEN = 0x02;
    ide_write(channel, ATA_REG_CONTROL, channels[channel].nIEN);

    var lba_mode: u8 = undefined;
    var head: u8 = undefined;

    // (I) Select one from LBA28, LBA48 or CHS;
    if (lba >= 0x10000000) {
        // Sure Drive should support LBA in this case, or you are giving a wrong LBA.
        // LBA48:
        lba_io = @bitCast([8]u8, lba);
        head = 0; // Lower 4-bits of HDDEVSEL are not used here.
        lba_mode = 2;
    } else if (ide_devices[drive].capabilities & 0x200 != 0) { // Drive supports LBA?
        // LBA28:
        lba_io = @bitCast([8]u8, lba);
        assert(lba_io[3] == 0);
        head = @intCast(u8, (lba & 0xF000000) >> 24);
        lba_mode = 1;
    } else {
        // CHS:
        const sect = @intCast(u8, (lba % 63) + 1);
        const cyl = (lba + 1 - sect) / (16 * 63);
        lba_io[0] = sect;
        lba_io[1] = @intCast(u8, (cyl >> 0) & 0xFF);
        lba_io[2] = @intCast(u8, (cyl >> 8) & 0xFF);
        lba_io[3] = 0;
        lba_io[4] = 0;
        lba_io[5] = 0;
        head = @intCast(u8, (lba + 1 - sect) % (16 * 63) / (63)); // Head number is written to HDDEVSEL lower 4-bits.
        lba_mode = 0;
    }

    // (III) Wait if the drive is busy;
    while (ide_read(channel, ATA_REG_STATUS) & ATA_SR_BSY != 0) {} // Wait if busy.)

    // (IV) Select Drive from the controller;
    if (lba_mode == 0) ide_write(channel, ATA_REG_HDDEVSEL, 0xA0 | (slavebit << 4) | head); // Drive & CHS.
    if (lba_mode != 0) ide_write(channel, ATA_REG_HDDEVSEL, 0xE0 | (slavebit << 4) | head); // Drive & LBA

    // (V) Write Parameters;
    if (lba_mode == 2) {
        ide_write(channel, ATA_REG_SECCOUNT1, 0);
        ide_write(channel, ATA_REG_LBA3, lba_io[3]);
        ide_write(channel, ATA_REG_LBA4, lba_io[4]);
        ide_write(channel, ATA_REG_LBA5, lba_io[5]);
    }
    ide_write(channel, ATA_REG_SECCOUNT0, numsects);
    ide_write(channel, ATA_REG_LBA0, lba_io[0]);
    ide_write(channel, ATA_REG_LBA1, lba_io[1]);
    ide_write(channel, ATA_REG_LBA2, lba_io[2]);

    // (VI) Select the command and send it;
    if (lba_mode == 0 and direction == 0 and !dma) cmd = ATA_CMD_READ_PIO;
    if (lba_mode == 1 and direction == 0 and !dma) cmd = ATA_CMD_READ_PIO;
    if (lba_mode == 2 and direction == 0 and !dma) cmd = ATA_CMD_READ_PIO_EXT;
    if (lba_mode == 0 and direction == 0 and dma) cmd = ATA_CMD_READ_DMA;
    if (lba_mode == 1 and direction == 0 and dma) cmd = ATA_CMD_READ_DMA;
    if (lba_mode == 2 and direction == 0 and dma) cmd = ATA_CMD_READ_DMA_EXT;
    if (lba_mode == 0 and direction == 1 and !dma) cmd = ATA_CMD_WRITE_PIO;
    if (lba_mode == 1 and direction == 1 and !dma) cmd = ATA_CMD_WRITE_PIO;
    if (lba_mode == 2 and direction == 1 and !dma) cmd = ATA_CMD_WRITE_PIO_EXT;
    if (lba_mode == 0 and direction == 1 and dma) cmd = ATA_CMD_WRITE_DMA;
    if (lba_mode == 1 and direction == 1 and dma) cmd = ATA_CMD_WRITE_DMA;
    if (lba_mode == 2 and direction == 1 and dma) cmd = ATA_CMD_WRITE_DMA_EXT;
    ide_write(channel, ATA_REG_COMMAND, cmd); // Send the Command.

    if (dma) {
        //TODO: dma
        // if (direction == 0);
        //    // DMA Read.
        // else;
        //    // DMA Write.
    }
    if (!dma and direction == 0) {
        // PIO Read.
        var i: u8 = 0;
        var iedi = edi;
        while (i < numsects) : (i = i + 1) {
            iedi = edi + i * (words * 2);
            if (ide_polling(channel, true)) |err| return err; // Polling, set error and exit if there is.
            asm volatile ("pushw %%es");
            asm volatile ("mov %[a], %%es"
                :
                : [a] "{eax}" (selector)
            );
            asm volatile ("rep insw"
                :
                : [words] "{ecx}" (words),
                  [bus] "{dx}" (bus),
                  [iedi] "{edi}" (iedi)
            ); // Receive Data.
            asm volatile ("popw %%es");
        }
    }
    if (!dma and direction == 1) {
        // PIO Write.
        var i: u8 = 0;
        var iedi = edi;
        while (i < numsects) : (i = i + 1) {
            iedi = edi + i * (words * 2);
            _ = ide_polling(channel, false); // Polling.
            asm volatile ("pushw %%ds");
            asm volatile ("mov %%ax, %%ds"
                :
                : [selector] "{eax}" (selector)
            );
            asm volatile ("rep outsw"
                :
                : [words] "{ecx}" (words),
                  [bus] "{dx}" (bus),
                  [iedi] "{esi}" (iedi)
            ); // Send Data
            asm volatile ("popw %%ds");
        }
        if (lba_mode == 2) ide_write(channel, ATA_REG_COMMAND, ATA_CMD_CACHE_FLUSH_EXT);
        if (lba_mode != 2) ide_write(channel, ATA_REG_COMMAND, ATA_CMD_CACHE_FLUSH);
        _ = ide_polling(channel, true); // Polling.
    }

    return 0;
}

pub const blockdev = kernel.bio.BlockDev{ .read = ide_block_read };
pub const sectorbuffer = [1]u8{0} ** 512;
pub fn ide_block_read(lba: u64) void {
    _ = ide_read_sectors(0, 1, lba, 0x8, @ptrToInt(&sectorbuffer[0]));
}

pub fn ide_read_sectors(drive: u8, numsects: u8, lba: u64, es: u8, edi: usize) u8 {
    // 1: Check if the drive presents:
    if (drive > 3 or ide_devices[drive].reserved == 0) {
        return 0x1; // Drive Not Found!
    } else if (((lba + numsects) > ide_devices[drive].size) and (ide_devices[drive].idetype == IDE_ATA)) {
        // 2: Check if inputs are valid:
        return 0x2; // Seeking to invalid position.
    } else {
        // 3: Read in PIO Mode through Polling & IRQs:
        var err: u8 = 0;
        if (ide_devices[drive].idetype == IDE_ATA) {
            err = ide_ata_access(ATA_READ, drive, lba, numsects, es, edi);
        } else if (ide_devices[drive].idetype == IDE_ATAPI) {
            var i: u8 = 0;
            while (i < numsects) : (i = i + 1) {
                // err = ide_atapi_read(drive, lba + i, 1, es, edi + (i * 2048));
            }
        }
        // ide_print_error(drive, err);
        return err;
    }
}

pub fn init(dev: kernel.pci.PciDevice) void {
    kernel.println("-- ide init --");
    kernel.print("[ide] ");
    dev.format();
    assert(dev.header_type() == 0x0); // mass storage device

    dev.config_write(@intCast(u8, 0xfe), 0x3c);
    if (dev.intr_line() == 0xfe) {
        kernel.println("[ide] detected ATA device");
    } else {
        kernel.println("Potential SATA device, aborting.");
        x86.hang();
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
            kernel.task.usleep(1000) catch unreachable; // Wait 1ms for drive select to work.

            // (II) Send ATA Identify Command:
            ide_write(i, ATA_REG_COMMAND, ATA_CMD_IDENTIFY);
            kernel.task.usleep(1000) catch unreachable;

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
                kernel.task.usleep(1000) catch unreachable;
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
            kernel.println(
                "[ide] drive {} {} ({}GB) - {}",
                i,
                if (ide_devices[i].idetype == 0) "ATA" else "ATAPI",
                ide_devices[i].size,
                ide_devices[i].model,
            );
        }
    }
}
