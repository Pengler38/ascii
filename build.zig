const std = @import("std");

const os = enum {
    linux,
    windows,
};

//Global arena
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

pub fn build(b: *std.Build) !void {
    defer arena.deinit();

    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = b.path("src/main.zig"),
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

    exe.step.dependOn(&addShaders(b).step);

    const run_step = b.step("run", "Run the program");
    run_step.dependOn(&run_exe.step);
}

fn addShaders(b: *std.Build) *std.Build.Step.WriteFile {
    //Step to compile shaders using glslc
    const names = [_][:0]const u8{
        "src/shaders/tri.vert",
        "src/shaders/tri.frag",
        "src/shaders/blur.frag",
    };

    const out_names = [_][:0]const u8{
        "src/shaders/tri.vert.spv",
        "src/shaders/tri.frag.spv",
        "src/shaders/blur.frag.spv",
    };

    //Copy shader output in cache to source files in /shader folder
    //IMPORTANT NOTE: usage of WriteFile to write to source files will be deprecated in zig 0.14.0 and will need to change to UpdateSourceFiles
    const write = b.addWriteFiles();

    for (names, out_names) |name, out_name| {
        const comp_step = b.addSystemCommand(&.{"glslc"});
        comp_step.addFileArg(b.path(name));
        const location = comp_step.addPrefixedOutputFileArg("-o", out_name);

        write.addCopyFileToSource(location, out_name);
    }

    return write;
}

fn findVulkanSDK(a: *std.ArrayList(u8)) !void {
    const env_map = try arena.allocator().create(std.process.EnvMap);
    env_map.* = try std.process.getEnvMap(arena.allocator());

    const location = env_map.get("VULKAN_SDK") orelse
        std.debug.panic("VULKAN_SDK environment variable not found, please install the vulkan SDK!\n", .{});

    try a.appendSlice(location);
}
