const Builder = @import("std").build.Builder;
const Target = @import("std").Target;
const CrossTarget = @import("std").zig.CrossTarget;
const Feature = @import("std").Target.Cpu.Feature;
const builtin = @import("builtin");
const std = @import("std");

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

    // const features = Target.x86.Feature;

    // var disabled_features = Feature.Set.empty;
    // var enabled_features = Feature.Set.empty;

    // disabled_features.addFeature(@enumToInt(features.mmx));
    // disabled_features.addFeature(@enumToInt(features.sse));
    // disabled_features.addFeature(@enumToInt(features.sse2));
    // disabled_features.addFeature(@enumToInt(features.avx));
    // disabled_features.addFeature(@enumToInt(features.avx2));
    // enabled_features.addFeature(@enumToInt(features.soft_float));

    const target = CrossTarget{
        .cpu_arch = Target.Cpu.Arch.i386,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
        // .cpu_features_sub = disabled_features,
        // .cpu_features_add = enabled_features
    };

    kernel.setTarget(target);
    kernel.setBuildMode(b.standardReleaseOptions());
    kernel.setLinkerScriptPath(.{ .path = "src/arch/x86/linker.ld" });
    b.default_step.dependOn(&kernel.step);
}
