// zig fmt: off

pub const CliConfig = struct {
	memSize:u32,
	stackSize:u32,
	heapSize:u32,
	enableAVExt:bool,
	filePath:?[]const u8,

	// REPL only
	allowSystem:bool,

	pub fn init(memSize:u32, stackSize:u32, heapSize:u32, enableAVExt:bool, allowSystem:bool, filePath:?[]const u8) CliConfig {
		return CliConfig{
			.memSize = memSize,
			.stackSize = stackSize,
			.heapSize = heapSize,
			.enableAVExt = enableAVExt,
			.allowSystem = allowSystem,
			.filePath = filePath,
		};
	}
};