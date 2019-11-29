/// std
pub const std = @import("std");
pub const assert = std.debug.assert;

pub usingnamespace @import("vga.zig");

///arch
pub const x86 = @import("arch/x86/index.zig");

///core
pub const layout = @import("layout.zig");
pub const multiboot = @import("multiboot.zig");
pub const vmem = @import("vmem.zig");
pub const task = @import("task.zig");
pub const time = @import("time.zig");

///extra
pub const console = @import("console.zig");
pub const pci = @import("pci/pci.zig");
pub const ps2 = @import("ps2.zig"); // i don't know whether this is x86 specific or not
