pub usingnamespace @import("../../common.zig");

// from core kernel
pub const kernel = @import("../../index.zig");

// x86 namespace
pub const PAGE_SIZE: usize = 4096;
pub const io = @import("lib/io.zig");
pub const instr = @import("lib/instructions.zig");
pub usingnamespace @import("main.zig");
pub const pmem = @import("pmem.zig");
pub const paging = @import("paging.zig");
pub const idt = @import("idt.zig");
pub const isr = @import("isr.zig");
pub const gdt = @import("gdt.zig");
pub const interrupt = @import("interrupt.zig");
