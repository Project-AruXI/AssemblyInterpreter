// zig fmt: off

const std = @import("std");
// const Engine = @import("Engine");
const args = @import("args");
const App = args.App;
const Arg = args.Arg;
const Command = args.Command;
const Error = args.YazapError;
const repl = @import("repl.zig");
const interpreter = @import("interpreter.zig");
const Config = @import("config.zig");

var buffer: [1024]u8 = undefined;
var w = std.fs.File.stdout().writer(&buffer);
const stdout = &w.interface;


const KB = 1024;

fn parseArgs() !*Config.CliConfig {
	var cliargs = App.init(std.heap.page_allocator, "asmintrep", "Desc");
	defer cliargs.deinit();

	var cli = cliargs.rootCommand();
	
	try cli.addArgs(&[_]Arg{
		Arg.singleValueOption("mem-size", null, "Memory size to be allocated."),
		Arg.singleValueOption("stack-size", null, "Stack size to be allocated."),
		Arg.singleValueOption("heap-size", null, "Heap size to be allocated."),
		Arg.booleanOption("avext", null, "Whether to enable AVX extensions."),
		Arg.booleanOption("allow-system", null, "Whether to allow system calls (REPL only)."),
		Arg.booleanOption("version", 'v', "Print version information and exit."),
		Arg.booleanOption("help", 'h', "Show help message and exit.")
	});

	try cli.addArg(Arg.positional("file", "The assembly file to execute", null));

	const matches = try cliargs.parseProcess();

	// Make CliConfig be in the heap to return
	var cliConfig = std.heap.page_allocator.create(Config.CliConfig) catch |err| {
		return err;
	};
	cliConfig.* = Config.CliConfig.init(
		64 * KB,
		4 * KB,
		16 * KB,
		false,
		false,
		null
	);

	if (matches.containsArg("version")) {
		try stdout.print("asmintrep version 0.1.0\n", .{});
		try stdout.flush();
		std.process.exit(0);
	}

	if (matches.containsArg("help")) {
		try stdout.print("Usage: asmintrep [options] [file]\n\n", .{});
		try stdout.print("Options:\n", .{});
		try stdout.print("  --mem-size <size>       Memory size to be allocated.\n", .{});
		try stdout.print("  --stack-size <size>    Stack size to be allocated.\n", .{});
		try stdout.print("  --heap-size <size>     Heap size to be allocated.\n", .{});
		try stdout.print("  --avext                Whether to enable AVX extensions.\n", .{});
		try stdout.print("  --allow-system         Whether to allow system calls (REPL only).\n", .{});
		try stdout.print("  -v, --version          Print version information and exit.\n", .{});
		try stdout.flush();
		std.process.exit(0);
	}

	if (matches.getSingleValue("mem-size")) |memSize| {
		const memSizeInt = try std.fmt.parseInt(u32, memSize, 10);
		if (memSizeInt == 0) {
			return error.InvalidArgument;
		}
		cliConfig.memSize = memSizeInt;
	}

	if (matches.getSingleValue("stack-size")) |stackSize| {
		const stackSizeInt = try std.fmt.parseInt(u32, stackSize, 10);
		if (stackSizeInt == 0) {
			return error.InvalidArgument;
		}
		cliConfig.stackSize = stackSizeInt;
	}

	if (matches.getSingleValue("heap-size")) |heapSize| {
		const heapSizeInt = try std.fmt.parseInt(u32, heapSize, 10);
		if (heapSizeInt == 0) {
			return error.InvalidArgument;
		}
		cliConfig.heapSize = heapSizeInt;
	}

	cliConfig.enableAVExt = matches.containsArg("avext");
	cliConfig.allowSystem = matches.containsArg("allow-system");

	if (matches.getSingleValue("file")) |filePath| {
		// Will run as file interpreter, invalid when also passing allow-system
		if (cliConfig.allowSystem) {
			return error.InvalidArgument;
		}
		cliConfig.filePath = filePath;
	} else {
		cliConfig.filePath = null;
	}

	return cliConfig;
}


pub fn main() !void {
	const cliConfig = parseArgs() catch {
		std.debug.print("Failed to parse arguments\n", .{});
		return;
	};

	// If no file path, then start up as repl
	// If file path, start up as interpreter and execute the file
	if (cliConfig.filePath == null) {
		try repl.startRepl(cliConfig);
	} else {
		try interpreter.executeFile(cliConfig);
	}
}