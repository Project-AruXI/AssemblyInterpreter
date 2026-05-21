// zig fmt: off

const std = @import("std");


pub const CommandType = enum {
	GetRegisters,
	GetRegister,
	GetMemory,
	Dump,
	Read,
	Write,
	Symbols,
	SetRegister,
	SetMemory,
	Unknown,
};

pub const OutputFormat = enum {
	Hex,
	Dec,
	Bin,
};

pub const Command = struct {
	cmdType: CommandType,
	register: ?[]const u8, // The register to view or to set
	memoryAddress: ?u32,
	memoryAddressName: ?[]const u8, // Additional name for memory address, used in replacement or conjunction to numerical address as a label
	memoryLength: ?u32,
	regValue: ?u32, // Value to go into registers (currently up to 32-bit)
	fRegValue: ?f32, // Value to go into FP registers (currently up to 32-bit float)
	memValue: ?u64, // Value to write into memory (up to 64-bit)
	memValueStr: ?[]const u8, // String value to write into memory
	format: ?OutputFormat
};

pub const ParseCommandError = error{
	InvalidCommand,
	InvalidArgument,
	InvalidFormatting,
	InvalidNumber
};


pub fn parseCommand(input: []const u8) !Command {
	var splitIter = std.mem.splitSequence(u8, input, " ");
	const cmdName = splitIter.next() orelse return ParseCommandError.InvalidCommand;

	var cmdType:CommandType = .Unknown;
	if (std.mem.eql(u8, cmdName, "registers")) {
		cmdType = .GetRegisters;
	} else if (std.mem.eql(u8, cmdName, "register")) {
		cmdType = .GetRegister;
	} else if (std.mem.eql(u8, cmdName, "memory")) {
		cmdType = .GetMemory;
	} else if (std.mem.eql(u8, cmdName, "dump")) {
		cmdType = .Dump;
	} else if (std.mem.eql(u8, cmdName, "read")) {
		cmdType = .Read;
	} else if (std.mem.eql(u8, cmdName, "write")) {
		cmdType = .Write;
	} else if (std.mem.eql(u8, cmdName, "symbols")) {
		cmdType = .Symbols;
	} else if (std.mem.eql(u8, cmdName, "set-reg")) {
		cmdType = .SetRegister;
	} else if (std.mem.eql(u8, cmdName, "set-mem")) {
		cmdType = .SetMemory;
	} else {
		return ParseCommandError.InvalidCommand;
	}

	var memoryLength: ?u32 = null;
	var regValue: ?u32 = null;
	var fRegValue: ?f32 = null;
	var memValue: ?u64 = null;
	var memValueStr: ?[]const u8 = null;
	var format: ?OutputFormat = null;

	var register: ?[]const u8 = null;
	if (cmdType == .GetRegister or cmdType == .SetRegister) {
		register = splitIter.next() orelse return ParseCommandError.InvalidArgument;
		if (cmdType == .SetRegister) {
			const valueStr = splitIter.next() orelse return ParseCommandError.InvalidArgument;

			// When the register is an FP reg, user may specify a float, intercept it and parse
			// Need to convert to u64 at the end anyway
			if (std.mem.indexOfScalar(u8, valueStr, '.')) |_| {
				std.debug.print("Parsing value as float: {s}\n", .{valueStr});
				const floatValue = try std.fmt.parseFloat(f32, valueStr);
				std.debug.print("Parsed float value: {}\n", .{floatValue});
				fRegValue = floatValue;
				std.debug.print("Assigned float value to fRegValue: {d:.2}\n", .{fRegValue.?});
			} else {
				// Otherwise, parse as integer
				regValue = try std.fmt.parseInt(u32, valueStr, 0); // Auto-detect base (hex with 0x, dec otherwise)
			}
		}
	}

	var memoryAddress: ?u32 = null;
	var memoryAddressName: ?[]const u8 = null; // The name for a memory address, either as a label or a segment name
	if (cmdType == .GetMemory or cmdType == .SetMemory) {
		const memAddrStr = splitIter.next() orelse return ParseCommandError.InvalidArgument;
		if (std.fmt.parseInt(u32, memAddrStr, 0)) |addr| {
			memoryAddress = addr;
		} else |_| {
			// If parsing as number fails, treat it as a label or segment name
			std.debug.print("Parsing memory address as label/segment name: {s}\n", .{memAddrStr});
			memoryAddressName = memAddrStr;
		}

		if (cmdType == .GetMemory) {
			// memory <address|label|segment> <length> [format]
			const memLenStr = splitIter.next() orelse return ParseCommandError.InvalidArgument;
			memoryLength = try std.fmt.parseInt(u32, memLenStr, 10);

			const formatStr = splitIter.next() orelse "hex";
			if (std.mem.eql(u8, formatStr, "hex")) {
				format = .Hex;
			} else if (std.mem.eql(u8, formatStr, "dec")) {
				format = .Dec;
			} else if (std.mem.eql(u8, formatStr, "bin")) {
				format = .Bin;
			} else {
				return ParseCommandError.InvalidFormatting;
			}
		} else if (cmdType == .SetMemory) {
			// set-mem <address> <value> <size>
			const valueStr = splitIter.next() orelse return ParseCommandError.InvalidArgument;
			memValue = try std.fmt.parseInt(u64, valueStr, 0); // Auto-detect base (hex with 0x, dec otherwise)

			const sizeStr = splitIter.next() orelse return ParseCommandError.InvalidArgument;
			const size = try std.fmt.parseInt(u32, sizeStr, 10);
			// TODO: Allow greater size or something
			if (size == 0 or size > 8) {
				return ParseCommandError.InvalidNumber;
			}
			memoryLength = size;
		}
	}

	if (cmdType == .Read) {
		// read <address|label> <length>
		const memAddrStr = splitIter.next() orelse return ParseCommandError.InvalidArgument;
		if (std.fmt.parseInt(u32, memAddrStr, 0)) |addr| {
			memoryAddress = addr;
		} else |_| {
			// If parsing as number fails, treat it as a label
			std.debug.print("Parsing memory address as label: {s}\n", .{memAddrStr});
			memoryAddressName = memAddrStr;
		}

		const memLenStr = splitIter.next() orelse return ParseCommandError.InvalidArgument;
		memoryLength = try std.fmt.parseInt(u32, memLenStr, 10);
	}

	if (cmdType == .Write) {
		// write <address> <label> <str>
		const memAddrStr = splitIter.next() orelse return ParseCommandError.InvalidArgument;
		memoryAddress = try std.fmt.parseInt(u32, memAddrStr, 0);
		memoryAddressName = splitIter.next() orelse return ParseCommandError.InvalidArgument;
		memValueStr = splitIter.rest();
	}

	if (cmdType == .Dump) {
		// Make sure there is nothing else after "dump"
		if (splitIter.next() != null) {
			return ParseCommandError.InvalidFormatting;
		}
	}

	return Command{
		.cmdType = cmdType,
		.register = register,
		.memoryAddress = memoryAddress,
		.memoryAddressName = memoryAddressName,
		.memoryLength = memoryLength,
		.regValue = regValue,
		.fRegValue = fRegValue,
		.memValue = memValue,
		.memValueStr = memValueStr,
		.format = format
	};
}

test "parseCommand should parse valid commands correctly" {
	const cmd1 = try parseCommand("registers");
	try std.testing.expect(cmd1.cmdType == .GetRegisters);

	const cmd2 = try parseCommand("register x10");
	try std.testing.expect(cmd2.cmdType == .GetRegister);
	try std.testing.expect(std.mem.eql(u8, cmd2.register.?, "x10"));

	const cmd3 = try parseCommand("memory 0x1000 64 hex");
	try std.testing.expect(cmd3.cmdType == .GetMemory);
	try std.testing.expect(cmd3.memoryAddress == 0x1000);
	try std.testing.expect(cmd3.memoryLength == 64);
	try std.testing.expect(cmd3.format == .Hex);

	const cmd4 = try parseCommand("set-reg x20 0x1234");
	try std.testing.expect(cmd4.cmdType == .SetRegister);
	try std.testing.expect(std.mem.eql(u8, cmd4.register.?, "x20"));
	try std.testing.expect(cmd4.regValue == 0x1234);

	const cmd5 = try parseCommand("set-mem 0x2000 0xdeadbeef 4");
	try std.testing.expect(cmd5.cmdType == .SetMemory);
	try std.testing.expect(cmd5.memoryAddress == 0x2000);
	try std.testing.expect(cmd5.memValue == 0xdeadbeef);
}