usingnamespace @import("lib/io.zig");
usingnamespace @import("lib/instructions.zig");
usingnamespace @import("main.zig");

const memory = @import("memory.zig");
const paging = @import("paging.zig");
const idt = @import("idt.zig");
const gdt = @import("gdt.zig");
const interrupt = @import("interrupt.zig");
