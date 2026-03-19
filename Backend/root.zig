// zig fmt: off

const std = @import("std");

pub const CPU = @import("cpu.zig");
pub const Mem = @import("mem.zig");


pub const AruEngineConfig = struct {
  memSize: u32,
  stackSize: u32,
  heapSize: u32
};

pub const AruEngine = struct {
  cpu: CPU.IntrepIAruCPU,
  mem: Mem.AruMemory,


  pub fn containsAVExt(this: *const AruEngine) bool {
    _ = this;
    return true;
  }

  /// Loads the 32-bit instruction into the memory address pointed to by the current instruction register (IR).
  /// This assumes the IR continues sequentially.
  pub fn loadInstruction(this: *AruEngine, instr: u32) !void {
    const ir = this.cpu.ir;
    std.debug.print("Loading instruction 0x{x} into memory at address 0x{x}\n", .{instr, ir});
    try this.mem.writeWord(ir, instr);
  }
};


pub fn initEngine(config: AruEngineConfig, allocator: std.mem.Allocator) !AruEngine {
  std.debug.print("Initializing AruEngine...\n", .{});
  var mem = try Mem.AruMemory.init(allocator, config.memSize, config.heapSize, config.stackSize);
  var cpu = CPU.IntrepIAruCPU.init(&mem);

  cpu.ir = mem.textSegStart;
  cpu.sp = mem.stackStart + config.stackSize - 0x4;


  return AruEngine{
    .cpu = cpu,
    .mem = mem
  };
}

pub fn deinitEngine(engine: *AruEngine) void {
  std.debug.print("Deinitializing AruEngine...\n", .{});
  _ = engine;
}