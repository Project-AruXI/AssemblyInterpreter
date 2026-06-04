// zig fmt: off

const std = @import("std");
const builtin = @import("builtin");
const chameleon = @import("chameleon");

const Config = @import("config.zig");
const Engine = @import("Engine");
const assembler = @import("assembler/assemble.zig");
const preprocessor = @import("assembler/preprocess.zig");
const eval = @import("assembler/expr.zig").parseEval;
// const Directive = @import("assembler/directive.zig").Directive;


var wBuffer: [1024]u8 = undefined;
var w: std.fs.File.Writer = switch (builtin.os.tag) {
	.windows => undefined,
	else => std.fs.File.stdout().writer(&wBuffer)
};
const stdout = &w.interface;

var c = chameleon.initComptime();
var rC:chameleon.RuntimeChameleon = undefined;


const InterpreterContext = struct {
	const Section = enum {
		TextSect,
		DataSect
	};


	gpa: *std.heap.GeneralPurposeAllocator(.{}),
	arena: *std.heap.ArenaAllocator,

	/// Stores any symbols done by .set
	internalSymbols: std.StringHashMap(u32),

	/// The current section that the interpreter is working on
	currSection: Section,

	/// The LP for the current section
	lp: u32,

	/// The permanent LP for the data section
	dataLP: u32,

	/// The permanent LP for the text section
	textLP: u32
};



fn processDirective(aruEngine: *Engine.AruEngine, directiveStr: []const u8, ctx: *InterpreterContext) !void {
	std.debug.print("Processing directive: {s}\n", .{directiveStr});

	const directive = try assembler.assembleDirective(directiveStr);

	switch (directive.directiveType) {
		.Text => {
			// If the current section is text already, nothing happens
			if (ctx.currSection != .TextSect) {
				std.debug.print("Switching section to text. Saving LP 0x{x} to data. Set LP 0x{x} for text\n", .{ctx.lp, ctx.textLP});

				// Current LP has been for data
				// Save that LP to the dataLP
				// Replace it with textLP
				ctx.dataLP = ctx.lp;
				ctx.lp = ctx.textLP;
			}
		},
		.Data => {
			if (ctx.currSection != .DataSect) {
				std.debug.print("Switching section to data. Saving LP 0x{x} to text. Set LP 0x{x} for data\n", .{ctx.lp, ctx.dataLP});

				// Same situation as Text
				ctx.textLP = ctx.lp;
				ctx.lp = ctx.dataLP;
			}
		},
		.String => {
			// Assume LP is in data
			for (directive.stringData.?) |ch| {
				try aruEngine.mem.writeByte(ctx.lp, ch);
				ctx.lp += 1;
			}
			// Write null byte
			try aruEngine.mem.writeByte(ctx.lp, 0);
			ctx.lp += 1;
		},
		.Byte => {
			for (directive.numberData.?.items) |expr| {
				// std.debug.print("Expression string {s}\n", .{expr});
				// Eval the expression
				const num:u8 = @intCast(try eval(expr, .U8));
				try aruEngine.mem.writeByte(ctx.lp, num);
				ctx.lp += 1;
			}
		},
		.Float => {
			for (directive.floatData.?.items) |f| {
				try aruEngine.mem.writeWord(ctx.lp, @bitCast(f));
				ctx.lp += 4;
			}
		},
		else => {

		}
	}
}



fn interpretFile(aruEngine: *Engine.AruEngine, cliConfig: *Config.CliConfig, ctx: *InterpreterContext) !void {
	const filename = cliConfig.filePath.?;
	var file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only});
	defer file.close();

	const startingIR = aruEngine.cpu.ir;

	var lineBuffer:[64]u8 = undefined;
	var reader = file.reader(&lineBuffer);
	while (try reader.interface.takeDelimiter('\n')) |line| {
		// Run the program until the end of 
		std.debug.print("Line: `{s}`\n", .{line});
		
		if (line.len == 0) {
			continue;
		}

		const preprocessed = preprocessor.preprocess(line);
		const label = preprocessed.@"0";
		const rest = preprocessed.@"1";

		std.debug.print("Preprocessed input. Label: `{s}`, Rest: `{s}`\n", .{label orelse "null", rest orelse "null"});

		if (label) |l| {
			std.debug.print("Adding label {s} to symbol map with address 0x{x}\n", .{try rC.magenta().fmt("{s}", .{l}), ctx.lp});
			const newLabel = ctx.arena.allocator().dupe(u8, l) catch |err| {
				try rC.printOutBuffered("{s}", .{try rC.red().fmt("Error duplicating label: {any}\n", .{err})});
				// try stdout.print("Error duplicating label: {any}\n", .{err});
				try stdout.flush();
				return;
			};
			aruEngine.mem.addLabel(newLabel, ctx.lp) catch |err| {
				try rC.red().printOut("Error adding label: {any}\n", .{err});
				try stdout.flush();
			};
		}

		if (rest == null or rest.?.len == 0) continue;

		const i_d = rest.?;
		// Rest can either be directive or instruction
		// Handle directive stuff here, leave rest as instruction
		if (std.mem.startsWith(u8, i_d, ".")) {
			processDirective(aruEngine, i_d, ctx) catch |err| {
				try rC.red().printOut("Error processing directive: {any}\n", .{err});
				try stdout.flush();
			};
			continue;
		}

		// Instructions from here on out
		std.debug.print("Received instruction: {s}\n", .{rest.?});
		const instrEncoding = assembler.assemble(rest.?) catch |err| {
			try rC.red().printOut("Error assembling instruction: {any}\n", .{err});
			try stdout.flush();
			continue;
		};
		std.debug.print("Assembled instruction encoding: 0x{x} (0b{b})\n", .{instrEncoding, instrEncoding});
		aruEngine.loadInstruction(instrEncoding) catch |err| {
			try rC.red().printOut("Error loading instruction into memory: {any}\n", .{err});
			try stdout.flush();
			continue;
		};
		std.debug.print("Wrote instruction 0x{x} to address 0x{x}\n", .{instrEncoding, aruEngine.cpu.ir});
		aruEngine.cpu.ir += 4;
	}

	// By this point, all intructions are in memory and any labels and data are in the symbol map and memory
	// Able to execute
	aruEngine.cpu.ir = startingIR;

	while (true) {
		aruEngine.cpu.step() catch |err| {
			if (err == Engine.CPU.CPUError.HaltState) {
				std.debug.print("Program halted successfully.\n", .{});
				return;
			} else {
				try rC.red().printOut("Error executing instruction: {any}\n", .{err});
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

	std.debug.print("Running interpreter with config: {f}\n", .{cliConfig});

	const engineConfig = Engine.AruEngineConfig{
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

	// std.debug.print("Mem Addr: {*}\n", .{aruEngine.cpu.mem});

	var ctx = InterpreterContext{
		.gpa = &gpa,
		.arena = &arena,
		.internalSymbols = .init(arenaAllocator),
		.currSection = .TextSect,
		.lp = aruEngine.mem.textSegStart,
		.textLP = aruEngine.mem.textSegStart,
		.dataLP = aruEngine.mem.dataSegStart
	};


	if (cliConfig.enableAVExt and !((&aruEngine).containsAVExt())) {
		std.debug.print("Warning: AVExt extensions enabled in config but not supported by engine\n", .{});
		return;
	}

	interpretFile(&aruEngine, cliConfig, &ctx) catch |err| {
		std.debug.print("File interpreter exited with error: {any}\n", .{err});
	};


	allocator.free(aruEngine.mem.mem);
	aruEngine.mem.deinit();
}