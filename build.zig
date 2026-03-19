// zig fmt: off

const std = @import("std");

pub fn build(b: *std.Build) void {
  const target = b.standardTargetOptions(.{});
  const optimize = b.standardOptimizeOption(.{});

  // Engine module (Backend)
  const engineModule = b.addModule("Engine", .{
    .root_source_file = b.path("Backend/root.zig"),
    .target = target,
  });

  // Native library for the engine
  const engineNative = b.addLibrary(.{
    .name = "engine",
    .root_module = b.createModule(.{
      .root_source_file = b.path("Backend/root.zig"),
      .target = target,
      .optimize = optimize,
    }),
  });
  // b.installArtifact(engineNative);
  const installEngine = b.addInstallArtifact(engineNative, .{
    .dest_dir = .{
      .override = .{ .custom = "../out" },
    },
  });

  // Interpreter executable (Frontend) which imports the `Engine` module
  const exe = b.addExecutable(.{
    .name = "asmintrep",
    .root_module = b.createModule(.{
      .root_source_file = b.path("Frontend/main.zig"),
      .target = target,
      .optimize = optimize,
      .imports = &.{
        .{ .name = "Engine", .module = engineModule },
      },
    }),
    .use_llvm = true
  });

  const cliargs = b.dependency("yazap", .{});
  exe.root_module.addImport("args", cliargs.module("yazap"));

  const cham = b.dependency("chameleon", .{});
  exe.root_module.addImport("chameleon", cham.module("chameleon"));

  const installExe = b.addInstallArtifact(exe, .{
    .dest_dir = .{
      .override = .{ .custom = "../out" },
    },
  });

  // Top-level steps so the user can run specific targets:
  //  - `zig build build-engine` to build native engine library
  //  - `zig build build-interpreter` to build the interpreter
  b.step("engine", "Build engine (native)").dependOn(&installEngine.step);
  b.step("interpreter", "Build interpreter").dependOn(&installExe.step);

  const runStep = b.step("run", "Build and run interpreter");
  const runCmd = b.addRunArtifact(exe);
  runStep.dependOn(&runCmd.step);
  runCmd.step.dependOn(b.getInstallStep());
  if (b.args) |args| {
    runCmd.addArgs(args);
  }

  const exeTests = b.addTest(.{
    .root_module = exe.root_module,
  });
  const runExeTests = b.addRunArtifact(exeTests);
  b.step("test", "Run tests").dependOn(&runExeTests.step);
}