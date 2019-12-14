const Builder = @import("std").build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    const kernel = b.addExecutable("kernel", "src/main.zig");
    kernel.addPackagePath("kernel", "src/index.zig");
    kernel.addPackagePath("x86", "src/arch/x86/index.zig");
    kernel.setOutputDir("build");

    kernel.addAssemblyFile("src/arch/x86/start.s");
    kernel.addAssemblyFile("src/arch/x86/gdt.s");
    kernel.addAssemblyFile("src/arch/x86/isr.s");
    kernel.addAssemblyFile("src/arch/x86/paging.s");
    kernel.addAssemblyFile("src/arch/x86/switch_tasks.s");

    kernel.setBuildMode(b.standardReleaseOptions());
    kernel.setTarget(builtin.Arch.i386, builtin.Os.freestanding, builtin.Abi.none);
    kernel.setLinkerScriptPath("src/arch/x86/linker.ld");
    b.default_step.dependOn(&kernel.step);
}
