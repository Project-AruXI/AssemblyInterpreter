// zig fmt: off

const std = @import("std");
const builtin = @import("builtin");
const chameleon = @import("chameleon");

const Config = @import("config.zig");
const Engine = @import("Engine");
const assembler = @import("assembler/assemble.zig");
const preprocessor = @import("assembler/preprocess.zig");
// const Directive = @import("assembler/directive.zig").Directive;
// const Command = @import("command.zig");

var wBuffer: [1024]u8 = undefined;
var w: std.fs.File.Writer = switch (builtin.os.tag) {
	.windows => undefined,
	else => std.fs.File.stdout().writer(&wBuffer)
};
const stdout = &w.interface;

var c = chameleon.initComptime();
var rC:chameleon.RuntimeChameleon = undefined;





fn processDirective(aruEngine: *Engine.AruEngine, directiveStr: []const u8, allocator: std.mem.Allocator) !void {
	std.debug.print("Processing directive: {s}", .{directiveStr});
	// TODO
	// 

	const directive = try assembler.assembleDirective(directiveStr);
	_ = directive;
	_ = aruEngine;
	_ = allocator;
}



fn interpretFile(aruEngine: *Engine.AruEngine, cliConfig: *Config.CliConfig) !void {
	const filename = cliConfig.filePath.?;
	var file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only});
	defer file.close();

	var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
	defer _ = gpa.deinit();
	const allocator = gpa.allocator();

	var arena = std.heap.ArenaAllocator.init(allocator);
	defer arena.deinit();
	const arenaAllocator = arena.allocator();

	const startingIR = aruEngine.cpu.ir;

	var lineBuffer:[64]u8 = undefined;
	var reader = file.reader(&lineBuffer);
	while (try reader.interface.takeDelimiter('\n')) |line| {
		// Run the program until the end of 
		std.debug.print("Line: {s}\n", .{line});
		
		if (line.len == 0) {
			continue;
		}

		const preprocessed = preprocessor.preprocess(line);
		const label = preprocessed.@"0";
		const rest = preprocessed.@"1";

		std.debug.print("Preprocessed input. Label: {s}, Rest: {s}\n", .{label orelse "null", rest orelse "null"});

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
		std.debug.print("Received instruction: {s}\n", .{rest.?});
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
		aruEngine.cpu.ir += 4;
	}

	// In the case that the file does not contain an explicit halt, an implicit halt will be written
	// This may or may not be hit depending on any branching of sorts
	const haltEncoding = assembler.assemble("hlt") catch |err| blk: {
		try stdout.print("Error assembling implicit halt instruction: {any}\n", .{err});
		try stdout.flush();
		break :blk 0;
	};


	aruEngine.loadInstruction(haltEncoding) catch |err| {
		try stdout.print("Error loading implicit halt instruction into memory: {any}\n", .{err});
		try stdout.flush();
	};

	// By this point, all intructions are in memory and any labels and data are in the symbol map and memory
	// Able to execute
	aruEngine.cpu.ir = startingIR;

	while (true) {
		aruEngine.cpu.step() catch |err| {
			if (err == Engine.CPU.CPUError.HaltState) {
				std.debug.print("Program halted successfully.\n", .{});
				return;
			} else {
				try stdout.print("Error executing instruction: {any}\n", .{err});
				try stdout.flush();
				return;
			}
		};
	}
}

pub fn executeFile(cliConfig: *Config.CliConfig) !void {
	// std.debug.print("{any}\n", .{cliConfig});
	std.debug.print("Executing file: {s}\n", .{cliConfig.filePath.?});

	if (builtin.os.tag == .windows) {
		w = std.fs.File.stdout().writer(&wBuffer);
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
		std.debug.print("Warning: AVExt extensions enabled in config but not supported by engine\n", .{});
		return;
	}

	interpretFile(&aruEngine, cliConfig) catch |err| {
		std.debug.print("File interpreter exited with error: {any}\n", .{err});
	};


	allocator.free(aruEngine.mem.mem);
	aruEngine.mem.deinit();
}