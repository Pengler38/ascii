const std = @import("std");

pub fn build(b: *std.Build) !void {
    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = b.path("main.zig"),
        .target = b.host,
    });

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var arr = std.ArrayList(u8).init(arena.allocator());
    defer arr.deinit();

    try findVulkanSDK(&arr);
    try arr.appendSlice("\\Include");
    const vulkanPath: std.Build.LazyPath = .{ .cwd_relative = arr.items };
    exe.addIncludePath(vulkanPath);

    exe.addLibraryPath(b.path("lib/glfw-3.4.bin.WIN64/lib-static-ucrt"));
    exe.addIncludePath(b.path("lib/glfw-3.4.bin.WIN64/include"));

    exe.linkLibC();
    exe.linkSystemLibrary("glfw3dll");

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    run_exe.addPathDir("lib/glfw-3.4.bin.WIN64/lib-static-ucrt");

    const run_step = b.step("run", "Run the program");
    run_step.dependOn(&run_exe.step);
}

fn findVulkanSDK(a: *std.ArrayList(u8)) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const env_map = try arena.allocator().create(std.process.EnvMap);
    env_map.* = try std.process.getEnvMap(arena.allocator());

    const location = env_map.get("VULKAN_SDK") orelse std.debug.panic("VULKAN_SDK environment variable not found, please install the vulkan SDK!\n", .{});

    try a.appendSlice(location);
}
