const std = @import("std");

const page_size = 65536;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "zonzai",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.rdynamic = true;
    exe.entry = .disabled;
    // exe.use_llvm = false;
    // exe.use_lld = false;

    // exe.stack_size = 65536; // 1 page = 64kB
    // exe.import_memory = true; // import linear memory from the environment
    // exe.initial_memory = 2 * page_size; // initial size of the linear memory (1 page = 64kB)
    // exe.max_memory = 2 * page_size; // maximum size of the linear memory
    // exe.global_base = 100000; // offset in linear memory to place global data

    const install = b.addInstallArtifact(exe, .{});
    install.step.dependOn(&exe.step);
    b.default_step.dependOn(&install.step);
}
