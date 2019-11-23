// std
pub const std = @import("std");
pub const assert = std.debug.assert;

// main namespace
pub usingnamespace @import("vga.zig");
pub const x86 = @import("arch/x86/index.zig");
pub const multiboot = @import("multiboot.zig");
pub const mem = @import("memory.zig");
pub const task = @import("task.zig");
pub const console = @import("console.zig");
pub const pci = @import("pci/pci.zig");
pub const ps2 = @import("ps2.zig");
pub const time = @import("time.zig");
