const std = @import("std");

pub fn compileShaders(
    b: *std.Build,
    step: *std.Build.Step,
) void {
    std.log.info("Building shaders", .{});
    const ShaderType = enum {
        vertex,
        vert,
        fragment,
        frag,
        tesscontrol,
        tesc,
        tesseval,
        tese,
        geometry,
        geom,
        compute,
        comp,
    };

    const s_folder = "assets/shaders";
    const in_ext = "glsl";
    const out_ext = "spv";
    const out_folder = "bin";

    b.build_root.handle.makePath(s_folder) catch |err| {
        switch (err) {
            error.PathAlreadyExists => {},
            else => {
                @panic(std.fmt.allocPrint(
                    b.allocator,
                    "Error creating {s}",
                    .{s_folder},
                ) catch "Fmt error");
            },
        }
    };

    const s_dir = b.build_root.handle.openDir(
        s_folder,
        .{ .iterate = true },
    ) catch @panic("Error opening shaders folder");

    var s_walker = s_dir.iterate();

    while (s_walker.next() catch @panic("Error iterating shaders folder")) |entry| {
        switch (entry.kind) {
            .file => {
                const ext = std.fs.path.extension(entry.name);
                if (std.mem.eql(u8, ext, "." ++ in_ext)) {
                    const basename = std.fs.path.basename(entry.name);
                    const name = basename[0 .. basename.len - ext.len];

                    var shader_stage: []const u8 = "";
                    var src_path_split = std.mem.splitScalar(u8, name, '.');
                    while (src_path_split.next()) |path| {
                        const s_type = std.meta.stringToEnum(ShaderType, path) orelse continue;
                        shader_stage = std.enums.tagName(ShaderType, s_type).?;
                    }
                    const s_source = std.fmt.allocPrint(
                        b.allocator,
                        "{s}/{s}.{s}",
                        .{ s_folder, name, in_ext },
                    ) catch @panic("Error formating source shader path");

                    const s_outpath = std.fmt.allocPrint(
                        b.allocator,
                        "{s}/{s}/{s}.{s}",
                        .{ s_folder, out_folder, name, out_ext },
                    ) catch @panic("Error formating output shader path");

                    const s_stage_arg = std.fmt.allocPrint(
                        b.allocator,
                        "-fshader-stage={s}",
                        .{
                            shader_stage,
                        },
                    ) catch @panic("Error formating shader stage");

                    s_dir.makePath(out_folder) catch |err| {
                        switch (err) {
                            error.PathAlreadyExists => {},
                            else => {
                                @panic(std.fmt.allocPrint(
                                    b.allocator,
                                    "Error creating {s}/{s}",
                                    .{ s_folder, out_folder },
                                ) catch "Fmt error");
                            },
                        }
                    };

                    const s_comp = b.addSystemCommand(&.{"glslc"});
                    s_comp.addArg(s_stage_arg);
                    s_comp.addFileArg(b.path(s_source));
                    s_comp.addArg("-o");
                    s_comp.addFileArg(b.path(s_outpath));

                    step.dependOn(&s_comp.step);
                }
            },
            else => {},
        }
    }
}

// TODO: make this build for windows

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_mod = b.createModule(.{
        .root_source_file = b.path("src/core/core.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    // ---------- Dependencies ----------
    core_mod.addIncludePath(b.path("vendor/include"));

    // Vulkan
    core_mod.linkSystemLibrary("vulkan", .{});

    // VulkanMemoryAllocator
    core_mod.addCSourceFile(.{
        .file = b.path("vendor/c/vk_mem_alloc.cpp"),
        .flags = &.{""},
    });

    // SDL3
    core_mod.addObjectFile(b.path("vendor/libSDL3.a"));

    // stb
    core_mod.addCSourceFile(.{
        .file = b.path("vendor/c/stb.c"),
        .flags = &.{""},
    });

    // ----------------------------------

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "Core", .module = core_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "b_engine",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const compile_shaders = b.option(bool, "cShader", "Compile shaders") orelse false;
    if (compile_shaders) {
        compileShaders(b, &exe.step);
    }

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    // run_cmd.setEnvironmentVariable("SDL_VIDEODRIVER", "wayland");

    const run_step = b.step("run", "Run the app");

    run_step.dependOn(&run_cmd.step);
}
