const std = @import("std");
const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;
const builtin = std.builtin;

pub fn build(builder: *Builder) void {
    const mode = builder.standardReleaseOptions();
    const target = builder.standardTargetOptions(.{});

    addMainStep(builder, mode, target);
}

fn addMainStep(builder: *Builder, mode: builtin.Mode, target: CrossTarget) void {
    const main_exe_step = builder.addExecutable("lapp", "src/main.zig");

    main_exe_step.setBuildMode(mode);
    main_exe_step.setTarget(target);

    main_exe_step.addPackagePath("thirdparty/zig-clap", "thirdparty/zig-clap/clap.zig");
    main_exe_step.linkLibC();
    main_exe_step.linkSystemLibrary("argon2");

    if (main_exe_step.build_mode == .Debug) {
        main_exe_step.valgrind_support = true;
    } else {
        main_exe_step.strip = true;
        main_exe_step.pie = true;
    }

    main_exe_step.install();
}
