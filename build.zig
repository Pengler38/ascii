const std = @import("std");

const os = enum {
    linux,
    windows,
};

pub fn build(b: *std.Build) !void {
    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = b.path("main.zig"),
        .target = b.graph.host,
    });

    const run_exe = b.addRunArtifact(exe);

    //Check Operating system (important for library linking because windows isn't great at this)
    var buildOs: os = undefined;
    if (b.graph.host.result.os.tag == std.Target.Os.Tag.linux) {
        std.debug.print("Building for Linux...\n", .{});
        buildOs = os.linux;
    } else if (b.graph.host.result.os.tag == std.Target.Os.Tag.windows) {
        std.debug.print("Building for Windows...\n", .{});
        buildOs = os.windows;
    } else {
        std.debug.print("Building on this OS not supported, trying anyways...\n", .{});
        buildOs = os.linux;
    }

    //OS dependent building:
    if (buildOs == os.windows) {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        var vulkanPathStr = std.ArrayList(u8).init(arena.allocator());
        defer vulkanPathStr.deinit();

        try findVulkanSDK(&vulkanPathStr);
        try vulkanPathStr.appendSlice("\\Include");
        const vulkanPath: std.Build.LazyPath = .{ .cwd_relative = vulkanPathStr.items };
        exe.addIncludePath(vulkanPath);

        exe.addLibraryPath(b.path("lib/glfw-3.4.bin.WIN64/lib-static-ucrt"));
        exe.addIncludePath(b.path("lib/glfw-3.4.bin.WIN64/include"));

        exe.linkSystemLibrary("glfw3dll");

        run_exe.addPathDir("lib/glfw-3.4.bin.WIN64/lib-static-ucrt");
    } else if (buildOs == os.linux) {
        exe.linkSystemLibrary("glfw3");
    }

    exe.linkLibC();

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the program");
    run_step.dependOn(&run_exe.step);
}

fn findVulkanSDK(a: *std.ArrayList(u8)) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const env_map = try arena.allocator().create(std.process.EnvMap);
    env_map.* = try std.process.getEnvMap(arena.allocator());

    const location = env_map.get("VULKAN_SDK") orelse
        std.debug.panic("VULKAN_SDK environment variable not found, please install the vulkan SDK!\n", .{});

    try a.appendSlice(location);
}
