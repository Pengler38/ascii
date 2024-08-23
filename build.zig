const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = b.path("main.zig"),
        .target = b.host,
    });

    exe.linkLibC();
    exe.addLibraryPath(b.path("lib/glfw-3.4.bin.WIN64/lib-static-ucrt"));
    exe.addIncludePath(b.path("lib/glfw-3.4.bin.WIN64/include"));
    exe.addIncludePath(b.path("lib/vulkan/Include"));
    exe.linkSystemLibrary("glfw3dll");

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    run_exe.addPathDir("lib/glfw-3.4.bin.WIN64/lib-static-ucrt");
    const run_step = b.step("run", "Run the program");
    run_step.dependOn(&run_exe.step);
}
