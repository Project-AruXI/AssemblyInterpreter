// zig fmt: off

const std = @import("std");
const builtin = @import("builtin");
const chameleon = @import("chameleon");

const Config = @import("config.zig");
const Engine = @import("Engine");
const assembler = @import("assembler/assemble.zig");
const preprocessor = @import("assembler/preprocess.zig");
// const Directive = @import("assembler/directive.zig").Directive;
const Command = @import("command.zig");


var wBuffer: [1024]u8 = undefined;
var rBuffer: [1024]u8 = undefined;
var w: std.fs.File.Writer = switch (builtin.os.tag) {
	.windows => undefined,
	else => std.fs.File.stdout().writer(&wBuffer)
};
var r: std.fs.File.Reader = switch (builtin.os.tag) {
	.windows => undefined,
	else => std.fs.File.stdin().reader(&rBuffer)
};
const stdout = &w.interface;
const stdin = &r.interface;

var c = chameleon.initComptime();
var rC:chameleon.RuntimeChameleon = undefined;

const REPL_PROMPT = "asmintrep>";


fn regNameToReg(regname:[]const u8) Engine.CPU.Register {
	// regname is something like "x0", "v3", "ir", etc
	// Need to normalize it
	if (std.mem.eql(u8, regname, "ir")) {
		return .IR;
	} else if (std.mem.eql(u8, regname, "cstr")) {
		return .CSTR;
	} else if (std.mem.eql(u8, regname, "sp")) {
		return .SP;
	} else if (regname.len > 1 and regname[0] == 'x') {
		// Intercept for xb aliasing to x29, and xz aliasing to x30
		if (regname.len == 2 and regname[1] == 'b') {
			return Engine.CPU.Register{ .GP = 29 };
		} else if (regname.len == 2 and regname[1] == 'z') {
			return Engine.CPU.Register{ .GP = 30 };
		}

		const idx = std.fmt.parseInt(u32, regname[1..], 10) catch {
			return Engine.CPU.Register{ .GP = 0 }; // Default to x0 on parse error
		};
		if (idx < 31) {
			return Engine.CPU.Register{ .GP = idx };
		}
	} else if (regname.len > 1 and regname[0] == 'v') {
		const idx = std.fmt.parseInt(u32, regname[1..], 10) catch {
			return Engine.CPU.Register{ .VR = 0 }; // Default to VR on parse error
		};
		if (idx < 6) {
			return Engine.CPU.Register{ .VR = idx };
		}
	} else if (regname.len > 1 and regname[0] == 'f') {
		const idx = std.fmt.parseInt(u32, regname[1..], 10) catch {
			return Engine.CPU.Register{ .FP = 0 }; // Default to FP on parse error
		};
		if (idx < 16) {
			return Engine.CPU.Register{ .FP = idx };
		}
	} else {
		// Special
		// a0/xr maps to x0
		// a1 - a9 maps to x1 - x9
		// c0 - c4 maps to x12 - x16
		// s0 - s10 maps to x17 - x27
		// lr maps to x28
		if (std.mem.eql(u8, regname, "a0") or std.mem.eql(u8, regname, "xr")) {
			return Engine.CPU.Register{ .GP = 0 };
		} else if (regname.len == 2 and regname[0] == 'a' and regname[1] >= '1' and regname[1] <= '9') {
		 	const idx = regname[1] - '0';
		 	return Engine.CPU.Register{ .GP = idx };
		} else if (regname.len == 2 and regname[0] == 'c' and regname[1] >= '0' and regname[1] <= '4') {
			const idx = regname[1] - '0';
			return Engine.CPU.Register{ .GP = 12 + idx };
		} else if (regname.len == 2 and regname[0] == 's' and regname[1] >= '0' and regname[1] <= '9') {
			const idx = regname[1] - '0';
			return Engine.CPU.Register{ .GP = 17 + idx };
		} else if (std.mem.eql(u8, regname, "lr")) {
			return Engine.CPU.Register{ .GP = 28 };
		}
	}

	return Engine.CPU.Register{ .GP = 0 }; // Default to x0 if unrecognized
}

fn regToRegname(reg: Engine.CPU.Register) []const u8 {
	switch (reg) {
		.Engine.CPU.Register.GP => return "x" ++ std.fmt.itou32(reg.GP),
		.Engine.CPU.Register.SP => return "sp",
		.Engine.CPU.Register.FP => return "f" ++ std.fmt.itou32(reg.FP),
		.Engine.CPU.Register.VR => return "v" ++ std.fmt.itou32(reg.VR),
		.Engine.CPU.Register.CSTR => return "cstr",
		else => return "unknown",
	}
}

fn executeCommand(cmd: Command.Command, aruEngine: *Engine.AruEngine, allowSystem: bool) !void {
	std.debug.print("Executing command: {any}\n", .{cmd});

	if ((cmd.cmdType == .SetMemory or cmd.cmdType == .SetRegister) and !allowSystem) {
		try stdout.print("System commands are not allowed in this REPL instance.\n", .{});
		try stdout.flush();
		return;
	}

	switch (cmd.cmdType) {
		.GetRegisters => {
			// IR: 0x00000000    SP: 0x00000000    CSTR: 0x0000
			// X0: 0x00000000  X1: 0x00000000  X2: 0x00000000  X3: 0x00000000  X4: 0x00000000
			// ...
			// X26: 0x00000000  X26: 0x00000000  X27: 0x00000000  X28: 0x00000000 X29: 0x00000000
			// 
			// F0: 0.000000  F1: 0.000000  F2: 0.000000  F3: 0.000000
			// ...
			// F12: 0.000000  F13: 0.000000  F14: 0.000000  F15: 0.000000
			//
			// V0: [0.000000, 0.000000, 0.000000, 0.000000]
			// ...
			// V5: [0.000000, 0.000000, 0.000000, 0.000000]
			try stdout.print("IR: 0x{x:08}    SP: 0x{x:08}    CSTR: 0x{x:08}\n\n", .{aruEngine.cpu.ir, aruEngine.cpu.sp, aruEngine.cpu.cstr});
			for (aruEngine.cpu.gpRegs, 0..) |reg, idx| {
				try stdout.print("X{d}: 0x{x:08}  ", .{idx, reg});
				if (idx % 5 == 4) try stdout.print("\n", .{});
			}
			try stdout.print("\n", .{});
			for (aruEngine.cpu.fpRegs, 0..) |reg, idx| {
				try stdout.print("F{d}: {d:0.6}  ", .{idx, reg});
				if (idx % 4 == 3) try stdout.print("\n", .{});
			}
			try stdout.print("\n", .{});
			for (aruEngine.cpu.vecRegs, 0..) |vecReg, idx| {
				try stdout.print("V{d}: [", .{idx});
				for (vecReg.data._v32, 0..) |elem, elemIdx| {
					try stdout.print("{d:0.6}", .{elem});
					if (elemIdx != 15) try stdout.print(", ", .{});
				}
				try stdout.print("]\n", .{});
			}
			try stdout.flush();
		},
		.GetRegister => {
			const regName = cmd.register.?;
			const register = regNameToReg(regName);
			const regValue = aruEngine.cpu.getRegister(register);

			// For all other registers except Vector registers, simply print the value in hex and decimal
			// For vector registers, print each element of the vector in hex and decimal
			switch (register) {
				.GP, .SP, .CSTR, .IR => {
					try stdout.print("Value of register {s}: 0x{x} ({d})\n", .{regName, regValue.Int, regValue.Int});
				},
				.FP => {
					try stdout.print("Value of floating-point register {s}: {}\n", .{regName, regValue.Float});
				},
				.VR => {
					try stdout.print("Value of vector register {s}:\n", .{regName});
					for (regValue.Vector.data._v32, 0..) |elem, idx| {
						const elem_bits: u32 = @bitCast(elem);
						try stdout.print("  [{d}]: 0x{x} ({d})\n", .{idx, elem_bits, elem_bits});
					}
				}
			}
			try stdout.flush();
		},
		.GetMemory => {
			var addr: u32 = undefined;
			if (cmd.memoryAddress) |a| {
				addr = a;
			} else if (cmd.memoryAddressName) |name| {
				std.debug.print("Resolving memory address from name: {s}\n", .{name});

				// Intercept when name is "stack"
				// Use the sp instead
				if (std.mem.eql(u8, name, "stack")) {
					addr = aruEngine.cpu.sp;
				} else {
					addr = aruEngine.mem.getAddress(name) catch |err| {
						try stdout.print("Error resolving memory address for name {s}: {any}\n", .{name, err});
						try stdout.flush();
						return;
					};
				}
				std.debug.print("Resolved memory address: 0x{x}\n", .{addr});
			} else {
				try stdout.print("No memory address provided for set-mem command\n", .{});
				try stdout.flush();
				return;
			}

			const length = cmd.memoryLength.?;

			const memSegment = &aruEngine.mem.mem[addr..addr + length];

			for (memSegment.*, 0..) |byte, idx| {
				const byteAddr = addr + idx;
				if ((idx % 8 == 0)) try stdout.print("0x{x:08}: ", .{byteAddr});
				switch (cmd.format.?) {
					.Hex => try stdout.print("0x{x:02} ", .{byte}),
					.Dec => try stdout.print("{d} ", .{byte}),
					.Bin => try stdout.print("0b{b:08} ", .{byte}),
				}
				if ((idx + 1) % 8 == 0) try stdout.print("\n", .{});
			}
			try stdout.print("\n", .{});
			try stdout.flush();
		},
		.Dump => {
			var _a: std.heap.DebugAllocator(.{}) = .init;
			const allocator = _a.allocator();
			const cpuState = try aruEngine.cpu.dumpState(allocator);

			const file = try std.fs.cwd().createFile("cpu.dump", .{ .truncate = true });
			defer file.close();
			try file.writeAll(cpuState);
			try stdout.print("CPU state dumped to cpu.dump\n", .{});
			try stdout.flush();
			_ = _a.deinit();
		},
		.SetRegister => {
			const regName = cmd.register.?;
			const register = regNameToReg(regName);

			// Disallow setting IR and CSTR
			if (register == .IR or register == .CSTR) {
				try stdout.print("Cannot set value of register {s}\n", .{regName});
				try stdout.flush();
				return;
			}

			const intVal = cmd.regValue orelse 0;
			const floatVal = cmd.fRegValue orelse 0.0;

			std.debug.print("Setting register {s} to int value {x} ({d}) or float value {d:.2}\n", .{regName, intVal, intVal, floatVal});

			var regVal: Engine.CPU.RegisterValue = undefined;
			switch (register) {
				.GP => regVal = .{ .Int = intVal },
				.SP => regVal = .{ .Int = intVal },
				.FP => regVal = .{ .Float = floatVal },
				.VR => {
					var v: Engine.CPU.VecReg = Engine.CPU.VecReg{ .data = .{ ._v32 = [_]f32{0.0} ** 16 } };
					for (&v.data._v32) |*elem| {
						elem.* = floatVal;
					}
					regVal = .{ .Vector = v };
				},
				else => {
					try stdout.print("Cannot set this register type: {s}\n", .{regName});
					try stdout.flush();
					return;
				}
			}

			aruEngine.cpu.setRegister(register, regVal);
			// try stdout.print("Set register {s} to 0x{x} ({d}) ({})\n", .{regName, rawValue, rawValue, regVal.Float});
			try stdout.print("Set register {s} to ", .{regName});
			switch (register) {
				.GP, .SP => try stdout.print("0x{x} ({d})\n", .{intVal, intVal}),
				.FP => try stdout.print("{d}\n", .{floatVal}),
				.VR => {
					try stdout.print("Vector of {d} elements:\n", .{16});
					for (regVal.Vector.data._v32, 0..) |elem, idx| {
						const elem_bits: u32 = @bitCast(elem);
						try stdout.print("  [{d}]: 0x{x} ({d})\n", .{idx, elem_bits, elem_bits});
					}
				},
				else => try stdout.print("unknown format\n", .{}),
			}
			try stdout.flush();
		},
		.SetMemory => {
			var addr: u32 = undefined;
			if (cmd.memoryAddress) |a| {
				addr = a;
			} else if (cmd.memoryAddressName) |name| {
				std.debug.print("Resolving memory address from name: {s}\n", .{name});

				// Intercept when name is "stack"
				// Use the sp instead
				if (std.mem.eql(u8, name, "stack")) {
					addr = aruEngine.cpu.sp;
				} else {
					addr = aruEngine.mem.getAddress(name) catch |err| {
						try stdout.print("Error resolving memory address for name {s}: {any}\n", .{name, err});
						try stdout.flush();
						return;
					};
				}
				std.debug.print("Resolved memory address: 0x{x}\n", .{addr});
			} else {
				try stdout.print("No memory address provided for set-mem command\n", .{});
				try stdout.flush();
				return;
			}

			const value = cmd.memValue.?;
			const length = cmd.memoryLength.?; // How many bytes to write to (up to 8 bytes)

			// Write the value to memory in little-endian format
			// Convert the 64-bit value to its little-endian byte representation
			const bytes: [8]u8 = @bitCast(value);
			for (0..length) |i| {
				aruEngine.mem.mem[addr + i] = bytes[i];
			}
			try stdout.print("Set memory at address 0x{x} to value 0x{x} ({d}) with length {d} bytes\n", .{addr, value, value, length});			
		},
		.Read => {
			var address: u32 = undefined;
			if (cmd.memoryAddress) |a| {
				// An address was provided
				address = a;
			} else if (cmd.memoryAddressName) |name| {
				// A label was provided, resolve the address
				address = aruEngine.mem.getAddress(name) catch |err| {
					try stdout.print("Error resolving memory address for name {s}: {any}\n", .{name, err});
					try stdout.flush();
					return;
				};
			}

			const length = cmd.memoryLength.?;

			// Constraints: data must be in data segment
			if (address >= aruEngine.mem.textSegStart) {
				try stdout.print("Error: Address 0x{x} is not within the data segment\n", .{address});
				try stdout.flush();
				return;
			}
			if (address + length >= aruEngine.mem.textSegStart) {
				try stdout.print("Error: Address 0x{x} + length {d} is not within the data segment\n", .{address, length});
				try stdout.flush();
				return;
			}

			// Read until null terminator or length provided as a string
			for (address..address + length) |addr| {
				const byte = aruEngine.mem.readByte(@as(u32, @intCast(addr))) catch |err| {
					try stdout.print("Error reading from memory: {any}\n", .{err});
					try stdout.flush();
					return;
				};
				if (byte == 0) break;
				try stdout.print("{c}", .{byte});
			}
			try stdout.print("\n", .{});
			try stdout.flush();
	
		},
		.Write => {
			const label = cmd.memoryAddressName.?;
			const address = cmd.memoryAddress.?;
			const _str = cmd.memValueStr.?;
			// _str is "....", need to take out the quotation marks and write the characters with null terminator
			const str = std.mem.trim(u8, _str, "\"");

			// Constraints: data must be within data segment, label should not exist
			if (address >= aruEngine.mem.textSegStart) {
				try stdout.print("Error: Address 0x{x} is not within the data segment\n", .{address});
				try stdout.flush();
				return;
			}
			if (address + str.len >= aruEngine.mem.textSegStart) {
				try stdout.print("Error: Address 0x{x} + length {d} is not within the data segment\n", .{address, str.len});
				try stdout.flush();
				return;
			}
			if (aruEngine.mem.symbolMap.get(label) != null) {
				try stdout.print("Error: Label {s} already exists\n", .{label});
				try stdout.flush();
				return;
			}

			for (str, 0..) |ch, i| {
				aruEngine.mem.writeByte(address + @as(u32, @intCast(i)), ch) catch |err| {
					try stdout.print("Error writing to memory at address 0x{x}: {any}\n", .{address + i, err});
					try stdout.flush();
					return;
				};
			}
			aruEngine.mem.writeByte(address + @as(u32, @intCast(str.len)), 0) catch |err| {
				try stdout.print("Error writing to memory at address 0x{x}: {any}\n", .{address + str.len, err});
				try stdout.flush();
				return;
			};

			aruEngine.mem.addLabel(label, address) catch |err| {
				try stdout.print("Error adding label {s} at address 0x{x}: {any}\n", .{label, address, err});
				try stdout.flush();
				return;
			};
			try stdout.print("Wrote string '{s}' to memory at address 0x{x} and associated it with label '{s}'\n", .{str, address, label});
			try stdout.flush();
		},
		.Symbols => {
			try stdout.print("Symbol map:\n", .{});
			var iter = aruEngine.mem.symbolMap.iterator();
			while (iter.next()) |entry| {
				try stdout.print("  {s}: 0x{x}\n", .{entry.key_ptr.*, entry.value_ptr.*});
			}
		},
		else => try stdout.print("Unknown command type: {any}\n", .{cmd.cmdType}),
	}
	try stdout.flush();
}

fn processCommand(input: []const u8, aruEngine: *Engine.AruEngine, allowSystem: bool) !bool {
	std.debug.print("Processing command: {s}", .{input});

	// All commands are at least 5 characters long
	if (input.len < 6) {
		try stdout.print("Invalid command: {s}", .{input});
		try stdout.flush();
		return false;
	}

	// Make sure there is no space after '/'
	if (input[1] == ' ') {
		try stdout.print("Invalid command: {s}", .{input});
		try stdout.flush();
		return false;
	}

	const cmdStr = std.mem.trim(u8, input[1..], " \t\r\n");


	if (std.mem.eql(u8, cmdStr, "exit")) {
		return true;
	} else if (std.mem.eql(u8, cmdStr, "help")) {
		try stdout.print("Available commands:\n", .{});
		try stdout.print("/registers - Print current register values\n", .{});
		try stdout.print("/register [reg] - Print value of specific register\n", .{});
		try stdout.print("/memory [address] [length] [format?(hex|dec|bin)] - Print memory contents\n", .{});
		try stdout.print("/symbols - Print symbol map\n", .{});
		try stdout.print("/read [address|label] [length] - Read length bytes from memory starting at address as a string\n", .{});
		try stdout.print("/write [address] [label] [string] - Write a string to memory at the specified address and associate it with a label\n", .{});
		try stdout.print("/dump - Dump CPU state and memory contents to a file\n", .{});
		try stdout.print("/help - Show this help message\n", .{});
		try stdout.print("/exit - Exit the REPL\n", .{});
		if (allowSystem) {
			try stdout.print("/set-reg [reg] [value] - Set register to a specific value\n", .{});
			try stdout.print("/set-mem [address] [value] [size] - Set memory at address to a specific value\n", .{});
		}
		try stdout.flush();
	} else {
		const cmd = Command.parseCommand(cmdStr) catch |err| {
			try stdout.print("Error parsing command: {any}\n", .{err});
			try stdout.flush();
			return false;
		};
		// execute command
		executeCommand(cmd, aruEngine, allowSystem) catch |err| {
			// std.debug.print("Error executing command: {any}\n", .{err});
			try stdout.print("Error executing command: {any}\n", .{err});
			try stdout.flush();
		};
	}

	return false;
}


fn processDirective(aruEngine: *Engine.AruEngine, directiveStr: []const u8, allocator: std.mem.Allocator) !void {
	std.debug.print("Processing directive: {s}", .{directiveStr});
	// TODO
	// Allowable directives in REPL mode are:
	// .set symbol, expr

	const directive = try assembler.assembleDirective(directiveStr);
	switch (directive.directiveType) {
		.Set => {
			// std.debug.print("Processing .set directive. Symbol: {s}, ExprNum: {d}\n", .{directive.symbol, directive.exprNum});
			// For now, just set the symbol to the current IR value; in the future we can evaluate the expression and set it to that value
			const symbol = allocator.dupe(u8, directive.symbol) catch |err| {
				try stdout.print("Error duplicating symbol: {any}\n", .{err});
				try stdout.flush();
				return;
			};
			aruEngine.mem.addSymbol(symbol, directive.exprNum) catch |err| {
				try stdout.print("Error adding symbol: {any}\n", .{err});
				try stdout.flush();
			};
		}
	}
}


fn runREPL(aruEngine: *Engine.AruEngine, allowSystem: bool) !void {
	std.debug.print("Running REPL with allowSystem={}\n", .{allowSystem});

	var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
	defer _ = gpa.deinit();
	const allocator = gpa.allocator();

	var arena = std.heap.ArenaAllocator.init(allocator);
	defer arena.deinit();
	const arenaAllocator = arena.allocator();

	while (true) {
		try rC.magenta().printOut("{s} ", .{REPL_PROMPT});
		try stdout.flush();

		const line = try stdin.takeDelimiterInclusive('\n');

		const input = line;
		std.debug.print("{s}", .{try rC.blue().fmt("Received input: {s}" , .{input})});

		const trimmed = std.mem.trim(u8, input, " \t\r");
		if (trimmed.len == 0) continue;
		// If first character of input is '/', treat it as a potential command
		// '/' can also be a division operator but it cannot be the first character

		if (trimmed[0] == '/') {
			const quit = processCommand(trimmed, aruEngine, allowSystem) catch |err| {
				std.debug.print("Error processing command: {any}\n", .{err});
				return;
			};
			if (quit) {
				std.debug.print("Exiting REPL...\n", .{});
				return;
			}
			continue;
		}

		const preprocessed = preprocessor.preprocess(trimmed);
		const label = preprocessed.@"0";
		const rest = preprocessed.@"1";

		std.debug.print("Preprocessed input. Label: {s}, Rest: {s}", .{label orelse "null", rest orelse "null"});

		if (label) |l| {
			// std.debug.print("Adding label to symbol map: {s}\n", .{l});
			const newLabel = arenaAllocator.dupe(u8, l) catch |err| {
				try stdout.print("Error duplicating label: {any}\n", .{err});
				try stdout.flush();
				return;
			};
			aruEngine.mem.addLabel(newLabel, aruEngine.cpu.ir) catch |err| {
				try stdout.print("Error adding label: {any}\n", .{err});
				try stdout.flush();
			};
		}

		if (rest) |i_d| {
			// Rest can either be directive or instruction
			// Handle directive stuff here, leave rest as instruction
			if (std.mem.startsWith(u8, i_d, ".")) {
				processDirective(aruEngine, i_d, arenaAllocator) catch |err| {
					try stdout.print("Error processing directive: {any}\n", .{err});
					try stdout.flush();
				};
				continue;
			}
		}

		// Instructions from here on out
		std.debug.print("Received instruction input: {s}", .{rest.?});
		const instrEncoding = assembler.assemble(rest.?) catch |err| {
			try stdout.print("Error assembling instruction: {any}\n", .{err});
			try stdout.flush();
			continue;
		};
		std.debug.print("Assembled instruction encoding: 0x{x} (0b{b})\n", .{instrEncoding, instrEncoding});
		aruEngine.loadInstruction(instrEncoding) catch |err| {
			try stdout.print("Error loading instruction into memory: {any}\n", .{err});
			try stdout.flush();
			continue;
		};
		aruEngine.cpu.step() catch |err| {
			try stdout.print("Error executing instruction: {any}\n", .{err});
			try stdout.flush();
		};
	}
}


pub fn startRepl(cliConfig: *Config.CliConfig) !void {
	if (builtin.os.tag == .windows) {
		w = std.fs.File.stdout().writer(&wBuffer);
		r = std.fs.File.stdin().reader(&rBuffer);
	}

	var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
	defer _ = gpa.deinit();
	const allocator = gpa.allocator();

	var arena = std.heap.ArenaAllocator.init(allocator);
	defer arena.deinit();
	const arenaAllocator = arena.allocator();

	rC = chameleon.initRuntime(.{.allocator = arenaAllocator});
	defer rC.deinit();

	std.debug.print("Starting REPL with config: {any}\n", .{cliConfig});

	const engineConfig =Engine.AruEngineConfig{
		.memSize = cliConfig.memSize,
		.stackSize = cliConfig.stackSize,
		.heapSize = cliConfig.heapSize
	};


	var aruEngine = Engine.initEngine(engineConfig, allocator) catch {
		std.debug.print("Failed to initialize engine\n", .{});
		return;
	};
	// FIXME: Hack to reset memory reference; this is done in the init when doing CPU.init but initEngine returns a new struct
	// with a copy of the Mem struct, so what cpu.mem refers to is not to engine.mem
	aruEngine.cpu.mem = &aruEngine.mem;


	if (cliConfig.enableAVExt and !((&aruEngine).containsAVExt())) {
		std.debug.print("Warning: AVExt enabled in config but not supported by engine\n", .{});
		return;
	}

	// Start REPL loop
	runREPL(&aruEngine, cliConfig.allowSystem) catch |err| {
		std.debug.print("REPL exited with error: {any}\n", .{err});
	};

	allocator.free(aruEngine.mem.mem);
	aruEngine.mem.deinit();
}