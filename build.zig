const Builder = @import("std").build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    const kernel = b.addExecutable("bzImage", "src/arch/x86/main.zig");
    kernel.addPackagePath("kernel", "src/index.zig");
    kernel.addPackagePath("arch", "src/arch/x86/lib/index.zig");
    kernel.setOutputDir("build");

    kernel.addAssemblyFile("src/arch/x86/_start.s");
    kernel.addAssemblyFile("src/arch/x86/gdt.s");
    kernel.addAssemblyFile("src/arch/x86/isr.s");

    kernel.setBuildMode(b.standardReleaseOptions());
    kernel.setTarget(builtin.Arch.i386, builtin.Os.freestanding, builtin.Abi.none);
    kernel.setLinkerScriptPath("src/arch/x86/linker.ld");
    b.default_step.dependOn(&kernel.step);
}
