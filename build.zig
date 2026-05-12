// zig fmt: off

const std = @import("std");
// Copies `src` to `dst` only when `dst` is missing or its contents differ.
fn copyIfDifferent(src: []const u8, dst: []const u8) !void {
  const cwd = std.fs.cwd();

  var srcFile = try cwd.openFile(src, .{});
  defer srcFile.close();

  const srcStat = try srcFile.stat();

  if (cwd.openFile(dst, .{}) catch null) |dstFile| {
    defer dstFile.close();

    const dstStat = try dstFile.stat();
    if (srcStat.size == dstStat.size) {
      var bufSrc: [4096]u8 = undefined;
      var bufDst: [4096]u8 = undefined;

      while (true) {
        const srcN = try srcFile.read(&bufSrc);
        const dstN = try dstFile.read(&bufDst);
        if (srcN != dstN) break;
        if (srcN == 0) return;
        if (!std.mem.eql(u8, bufSrc[0..srcN], bufDst[0..dstN])) break;
      }
    }
  }

  try srcFile.seekTo(0);

  var dstWrite = try cwd.createFile(dst, .{ .truncate = true });
  defer dstWrite.close();

  var buf: [4096]u8 = undefined;
  while (true) {
    const n = try srcFile.read(&buf);
    if (n == 0) break;
    try dstWrite.writeAll(buf[0..n]);
  }
}

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
    .use_llvm = true
  });
  // b.installArtifact(engineNative);
  const installEngine = b.addInstallArtifact(engineNative, .{
    .dest_dir = .{
      .override = .{ .custom = "../out" },
    },
  });
  // Ensure generated opcodes are present for the engine module
  copyIfDifferent("common/defs/instr/generated/opcodes.zig", "Backend/opcodes.zig") catch |err| {
    std.debug.print("opcodes sync (Backend) failed: {}\n", .{err});
  };

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

  // Ensure generated opcodes are present for the interpreter executable
  copyIfDifferent("common/defs/instr/generated/opcodes.zig", "Frontend/assembler/opcodes.zig") catch |err| {
    std.debug.print("opcodes sync (Frontend) failed: {}\n", .{err});
  };

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