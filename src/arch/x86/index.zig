// std
pub const assert = @import("std").debug.assert;

// from core kernel
pub usingnamespace @import("../../vga.zig");
pub const multiboot = @import("../../multiboot.zig");
pub const time = @import("../../time.zig");
pub const ps2 = @import("../../ps2.zig");

// x86 namespace
pub usingnamespace @import("lib/io.zig");
pub usingnamespace @import("lib/instructions.zig");
pub usingnamespace @import("main.zig");
pub const layout = @import("layout.zig");
pub const memory = @import("memory.zig");
pub const paging = @import("paging.zig");
pub const idt = @import("idt.zig");
pub const isr = @import("isr.zig");
pub const gdt = @import("gdt.zig");
pub const interrupt = @import("interrupt.zig");
