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
const ATA_SR_BUSY = 0x80;
const ATA_SR_DRDY = 0x40; // Drive ready
const ATA_SR_DF = 0x20; // Drive write fault
const ATA_SR_DSC = 0x10; // Drive seek complete
const ATA_SR_DRQ = 0x08; // Data request ready
const ATA_SR_CORR = 0x04; // Corrected data
const ATA_SR_IDX = 0x02;
const ATA_SR_ERR = 0x01;

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

const atapi_packet: [12]u8 = [1]u8{0xA8} ++ [1]u8{0} ** 11;
var ide_buf: [2048]u8 = [1]u8{0} ** 2048;

const IDEDevice = struct {
    reserved: u8, // 0 (Empty) or 1 (This Drive really exists).
    channel: IDEChannelRegister,
    drive: u8, // 0 (Master Drive) or 1 (Slave Drive).
    idetype: u16, // 0: ATA, 1:ATAPI.
    signature: u16, // Drive Signature
    capabilities: u16, // Features.
    commandsets: usize, // Command Sets Supported.
    size: usize, // Size in Sectors.
    model: [41]u8, // Model in string.
    ide_irq_invoked: bool = false,

    pub fn init(channel: IDEChannelRegister, drive: u8) !?*IDEDevice {
        var idetype: u8 = IDE_ATA;
        var err: u8 = 0;
        var status: u8 = 0;

        // TODO: make this nicer
        var self = try kernel.vmem.allocator.create(IDEDevice);
        errdefer kernel.vmem.allocator.destroy(self);
        self.reserved = 1;
        self.channel = channel;
        self.drive = drive;

        // (0) Turn off irqs
        self.write(ATA_REG_CONTROL, 2);

        // (I) Select Drive:
        self.write(ATA_REG_HDDEVSEL, 0xA0 | (drive << 4)); // Select Drive.
        try kernel.task.usleep(1000); // Wait 1ms for drive select to work.

        // (II) Send ATA Identify Command:
        self.write(ATA_REG_COMMAND, ATA_CMD_IDENTIFY);
        try kernel.task.usleep(1000);

        if (self.read(ATA_REG_STATUS) == 0) return null; // If Status = 0, No Device.

        while (true) {
            status = self.read(ATA_REG_STATUS);
            if (status & ATA_SR_ERR != 0) {
                err = 1;
                break;
            } // If Err, Device is not ATA.
            if ((status & ATA_SR_BUSY == 0) and (status & ATA_SR_DRQ != 0)) break; // Everything is right.
        }

        // (IV) Probe for ATAPI Devices:)
        if (err != 0) {
            // Device is not ATA
            const cl = self.read(ATA_REG_LBA1);
            const ch = self.read(ATA_REG_LBA2);

            if (cl == 0x14 and ch == 0xEB) idetype = IDE_ATAPI;
            if (cl == 0x69 and ch == 0x96) idetype = IDE_ATAPI;
            if (idetype != IDE_ATAPI) {
                return null; // Unknown Type (may not be a device).
            }

            self.write(ATA_REG_COMMAND, ATA_CMD_IDENTIFY_PACKET);
            try kernel.task.usleep(1000);
        }
        self.idetype = idetype;

        // (V) Read Identification Space of the Device:
        self.read_buffer(ATA_REG_DATA, &ide_buf, 128);
        self.signature = @ptrCast(*const u8, &ide_buf[ATA_IDENT_DEVICETYPE]).*;
        self.capabilities = @ptrCast(*const u8, &ide_buf[ATA_IDENT_CAPABILITIES]).*;
        self.commandsets = @ptrCast(*const usize, &ide_buf[ATA_IDENT_COMMANDSETS]).*;

        // (VII) Get Size:
        if (self.commandsets & (1 << 26) != 0) {
            // Device uses 48-Bit Addressing:
            self.size = @ptrCast(*const usize, &ide_buf[ATA_IDENT_MAX_LBA_EXT]).*;
        } else {
            // Device uses CHS or 28-bit Addressing:
            self.size = @ptrCast(*const usize, &ide_buf[ATA_IDENT_MAX_LBA]).*;
        }
        // (VIII) String indicates model of device (like Western Digital HDD and SONY DVD-RW...):
        var k: u16 = 0;
        while (k < 40) : (k = k + 2) {
            self.model[k] = ide_buf[ATA_IDENT_MODEL + k + 1];
            self.model[k + 1] = ide_buf[ATA_IDENT_MODEL + k];
        }
        self.model[40] = 0; // Terminate String.
        self.format();
        return self;
    }

    inline fn poll(self: IDEDevice) void {
        for ([_]u8{ 0, 1, 2, 3 }) |_| _ = self.read(ATA_REG_ALTSTATUS); // wait 100ns per call
        while (self.read(ATA_REG_STATUS) & ATA_SR_BUSY != 0) {} // Wait for BSY to be zero.
    }
    inline fn poll_check(self: IDEDevice) !void {
        // (I) Delay 400 nanosecond for BSY to be set:
        self.poll();
        const state = self.read(ATA_REG_STATUS); // Read Status Register.
        if (state & ATA_SR_ERR != 0) return error.ATAStatusReg; // Error.
        if (state & ATA_SR_DF != 0) return error.ATADeviceFault; // Device Fault.
        if ((state & ATA_SR_DRQ) == 0) return error.ATANoDRQ; // DRQ should be set
    }

    pub inline fn read(self: IDEDevice, comptime reg: u8) u8 {
        if (reg > 0x07 and reg < 0x0C) self.write(ATA_REG_CONTROL, 0x80 | self.channel.nIEN);
        defer if (reg > 0x07 and reg < 0x0C) self.write(ATA_REG_CONTROL, self.channel.nIEN);
        return switch (reg) {
            0x0...0x7 => x86.inb(self.channel.base + reg - 0x0),
            0x8...0xb => x86.inb(self.channel.base + reg - 0x6),
            0xc...0xd => x86.inb(self.channel.ctrl + reg - 0xa),
            0xe...0x16 => x86.inb(self.channel.bmide + reg - 0xe),
            else => @compileError("bad IDE register."),
        };
    }
    pub inline fn read_buffer(self: IDEDevice, comptime reg: u8, buf: var, cnt: usize) void {
        if (reg > 0x07 and reg < 0x0C) self.write(ATA_REG_CONTROL, 0x80 | self.channel.nIEN);
        defer if (reg > 0x07 and reg < 0x0C) self.write(ATA_REG_CONTROL, self.channel.nIEN);
        switch (reg) {
            0x0...0x7 => x86.insl(self.channel.base + reg - 0x0, buf, cnt),
            0x8...0xb => x86.insl(self.channel.base + reg - 0x6, buf, cnt),
            0xc...0xd => x86.insl(self.channel.ctrl + reg - 0xa, buf, cnt),
            0xe...0x16 => x86.insl(self.channel.bmide + reg - 0xe, buf, cnt),
            else => @compileError("bad IDE register."),
        }
    }
    pub inline fn write(self: IDEDevice, comptime reg: u8, data: u8) void {
        if (reg > 0x07 and reg < 0x0C) self.write(ATA_REG_CONTROL, 0x80 | self.channel.nIEN);
        defer if (reg > 0x07 and reg < 0x0C) self.write(ATA_REG_CONTROL, self.channel.nIEN);
        switch (reg) {
            0x0...0x7 => x86.outb(self.channel.base + reg - 0x0, data),
            0x8...0xb => x86.outb(self.channel.base + reg - 0x6, data),
            0xc...0xd => x86.outb(self.channel.ctrl + reg - 0xa, data),
            0xe...0x16 => x86.outb(self.channel.bmide + reg - 0xe, data),
            else => @compileError("bad IDE register."),
        }
    }

    pub fn read_sectors(self: *IDEDevice, numsects: u8, lba: u64, selector: u8, buf: usize) !void {
        // 1: Check if the drive presents:
        if (self.reserved == 0) {
            return error.DriveNotFound; // Drive Not Found!
        } else if (self.idetype == IDE_ATA and (lba + numsects) > self.size) {
            // 2: Check if inputs are valid:
            return error.InvalidSeek; // Seeking to invalid position.
        } else {
            // 3: Read in PIO Mode through Polling & IRQs:
            if (self.idetype == IDE_ATA) {
                try self.ata_access(ATA_READ, lba, numsects, selector, buf);
            } else if (self.idetype == IDE_ATAPI) {
                return error.ATAPINotImplemented;
                // var i: u8 = 0;
                // while (i < numsects) : (i = i + 1) {
                //     // err = ide_atapi_read(drive, lba + i, 1, selector, buf + (i * 2048));
                // }
            }
        }
    }

    pub fn format(self: IDEDevice) void {
        kernel.println("[ide] {} drive ({}MB) - {}", .{
            if (self.idetype == 0) "ATA  " else "ATAPI",
            self.size * 512 / 1024 / 1024,
            self.model,
        });
    }

    fn ata_access(self: *IDEDevice, direction: u8, lba: u64, numsects: u8, selector: u16, buf: usize) !void {
        var dma = false; // 0: No DMA, 1: DMA
        var cmd: u8 = 0;
        var lba_io = [1]u8{0} ** 8;
        const bus: u16 = self.channel.base; // Bus Base, like 0x1F0 which is also data port.
        const words: usize = 256; // Almost every ATA drive has a sector-size of 512-byte.

        self.ide_irq_invoked = false;
        self.write(ATA_REG_CONTROL, 2); // disable IRQa

        var lba_mode: u8 = undefined;
        var head: u8 = undefined;

        // (I) Select one from LBA28, LBA48 or CHS;
        if (lba >= 0x10000000) {
            // Sure Drive should support LBA in this case, or you are giving a wrong LBA.
            // LBA48:
            lba_io = @bitCast([8]u8, lba);
            head = 0; // Lower 4-bits of HDDEVSEL are not used here.
            lba_mode = 2;
        } else if (self.capabilities & 0x200 != 0) { // Drive supports LBA?
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
        while (self.read(ATA_REG_STATUS) & ATA_SR_BUSY != 0) {} // Wait if busy.)

        // (IV) Select Drive from the controller;
        if (lba_mode == 0) self.write(ATA_REG_HDDEVSEL, 0xA0 | (self.drive << 4) | head); // Drive & CHS.
        if (lba_mode != 0) self.write(ATA_REG_HDDEVSEL, 0xE0 | (self.drive << 4) | head); // Drive & LBA

        // (V) Write Parameters;
        if (lba_mode == 2) {
            self.write(ATA_REG_SECCOUNT1, 0);
            self.write(ATA_REG_LBA3, lba_io[3]);
            self.write(ATA_REG_LBA4, lba_io[4]);
            self.write(ATA_REG_LBA5, lba_io[5]);
        }
        self.write(ATA_REG_SECCOUNT0, numsects);
        self.write(ATA_REG_LBA0, lba_io[0]);
        self.write(ATA_REG_LBA1, lba_io[1]);
        self.write(ATA_REG_LBA2, lba_io[2]);

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
        self.write(ATA_REG_COMMAND, cmd); // Send the Command.

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
            while (i < numsects) : (i = i + 1) {
                var iedi = buf + i * (words * 2);
                try self.poll_check(); // Polling, set error and exit if there is.

                // TODO? use selectors for non flat layouts
                // asm volatile ("pushw %%es");
                // asm volatile ("mov %[a], %%es"
                //     :
                //     : [a] "{eax}" (selector)
                // );
                asm volatile ("rep insw"
                    : [iedi] "={edi}" (iedi),
                      [words] "={ecx}" (words)
                    : [bus] "{dx}" (bus),
                      [iedi] "0" (iedi),
                      [words] "1" (words)
                    : "memory", "cc"
                );
                // asm volatile ("popw %%es");
                // x86.hang();
            }
        }
        if (!dma and direction == 1) {
            // PIO Write.
            var i: u8 = 0;
            while (i < numsects) : (i = i + 1) {
                var iedi = buf + i * (words * 2);
                self.poll(); // Polling.
                asm volatile ("pushw %%ds");
                asm volatile ("mov %%ax, %%ds"
                    : [selector] "={eax}" (selector)
                );
                asm volatile ("rep outsw"
                    :
                    : [words] "{ecx}" (words),
                      [bus] "{dx}" (bus),
                      [iedi] "{esi}" (iedi)
                ); // Send Data
                asm volatile ("popw %%ds");
            }
            if (lba_mode == 2) self.write(ATA_REG_COMMAND, ATA_CMD_CACHE_FLUSH_EXT);
            if (lba_mode != 2) self.write(ATA_REG_COMMAND, ATA_CMD_CACHE_FLUSH);
            try self.poll_check(); // Polling.
        }
    }
};

var ide_device_0: ?*IDEDevice = null;
var ide_device_1: ?*IDEDevice = null;
var ide_device_2: ?*IDEDevice = null;
var ide_device_3: ?*IDEDevice = null;

const IDEChannelRegister = struct {
    base: u16, // I/O Base.
    ctrl: u16, // Control Base
    bmide: u16, // Bus Master IDE
    nIEN: u8, // nIEN (No Interrupt);
};

pub const first_ide_drive = kernel.bio.BlockDev(512){
    .read = ide_block_read,
    .write = null,
};

pub fn ide_block_read(lba: u64, buf: *[512]u8) void {
    // read 1 sector on drive 0
    return ide_device_0.?.read_sectors(1, lba, 0x10, @ptrToInt(buf)) catch unreachable;
}

pub fn init(dev: kernel.pci.PciDevice) void {
    kernel.println("-- ide init --", .{});
    kernel.print("[ide] ", .{});
    dev.format();
    assert(dev.header_type() == 0x0); // mass storage device

    dev.config_write(@intCast(u8, 0xfe), 0x3c);
    if (dev.intr_line() == 0xfe) {
        kernel.println("[ide] detected ATA device", .{});
    } else {
        kernel.println("[ide] Potential SATA device. Not implemented. Hanging", .{});
        x86.hang();
    }

    const BAR0 = @intCast(u16, dev.bar(0));
    const BAR1 = @intCast(u16, dev.bar(1));
    const BAR2 = @intCast(u16, dev.bar(2));
    const BAR3 = @intCast(u16, dev.bar(3));
    const BAR4 = @intCast(u16, dev.bar(4));
    var channels: [2]IDEChannelRegister = undefined;
    channels[ATA_PRIMARY].base = if (BAR0 == 0) 0x1f0 else BAR0;
    channels[ATA_PRIMARY].ctrl = if (BAR1 == 0) 0x3F6 else BAR1;
    channels[ATA_SECONDARY].base = if (BAR2 == 0) 0x170 else BAR2;
    channels[ATA_SECONDARY].ctrl = if (BAR3 == 0) 0x376 else BAR3;
    channels[ATA_PRIMARY].bmide = (BAR4 & 0xFFFC); // Bus Master IDE
    channels[ATA_SECONDARY].bmide = (BAR4 & 0xFFFC) + 8; // Bus Master IDE

    ide_device_0 = IDEDevice.init(channels[ATA_PRIMARY], 0) catch unreachable;
    ide_device_1 = IDEDevice.init(channels[ATA_PRIMARY], 1) catch unreachable;
    ide_device_2 = IDEDevice.init(channels[ATA_SECONDARY], 0) catch unreachable;
    ide_device_3 = IDEDevice.init(channels[ATA_SECONDARY], 1) catch unreachable;
}
