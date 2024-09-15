const std = @import("std");

const os = enum {
    linux,
    windows,
};

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = b.path("main.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });

    const run_exe = b.addRunArtifact(exe);

    //Add option so the code can tell whether it's building for debug or release
    const options = b.addOptions();
    options.addOption(bool, "debug", optimize == std.builtin.OptimizeMode.Debug);
    exe.root_module.addOptions("config", options);

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
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var vulkanPathStr = std.ArrayList(u8).init(arena.allocator());
    defer vulkanPathStr.deinit();
    if (buildOs == os.windows) {
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

    //Step to compile shaders using glslc
    const shader_step = b.addSystemCommand(&.{"glslc"});
    shader_step.addFileArg(b.path("shaders/tri.frag"));
    const shader_location = shader_step.addPrefixedOutputFileArg("-o", "shaders/frag.spv");

    const shader_step_2 = b.addSystemCommand(&.{"glslc"});
    shader_step_2.addFileArg(b.path("shaders/tri.vert"));
    const shader_location_2 = shader_step_2.addPrefixedOutputFileArg("-o", "shaders/vert.spv");

    //Copy shader output in cache to source files in /shader folder
    //IMPORTANT NOTE: usage of WriteFile to write to source files will be deprecated in zig 0.14.0 and will need to change to UpdateSourceFiles
    const shader_write = b.addWriteFiles();
    shader_write.addCopyFileToSource(shader_location, "shaders/frag.spv");
    shader_write.addCopyFileToSource(shader_location_2, "shaders/vert.spv");

    exe.step.dependOn(&shader_write.step);

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
