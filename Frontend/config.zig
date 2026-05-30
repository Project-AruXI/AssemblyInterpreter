// zig fmt: off

const std = @import("std");

pub const CliConfig = struct {
	memSize:u32,
	stackSize:u32,
	heapSize:u32,
	enableAVExt:bool,
	allocator:std.mem.Allocator,

	// File-based interpreter only
	filePath:?[]const u8,

	// REPL only
	allowSystem:bool,

	pub fn init(memSize:u32, stackSize:u32, heapSize:u32, enableAVExt:bool, allowSystem:bool, filePath:?[]const u8, allocator:std.mem.Allocator) CliConfig {
		return CliConfig{
			.memSize = memSize,
			.stackSize = stackSize,
			.heapSize = heapSize,
			.enableAVExt = enableAVExt,
			.allowSystem = allowSystem,
			.filePath = filePath,
			.allocator = allocator,
		};
	}

	pub fn format(self: *const CliConfig, writer: *std.Io.Writer) !void {
		try writer.writeAll("CliConfig{\n");
		inline for (@typeInfo(CliConfig).@"struct".fields) |field| {
			_print: {
				// If the field is allocator, skip it
				// If the field type is a string, print as a string
				if (std.mem.eql(u8, field.name, "allocator")) {
					break :_print;
				}
				const value = @field(self, field.name);

				if (comptime std.mem.eql(u8, field.name, "filePath")) {
					try writer.print("{s}: {?s}\n", .{field.name, value});
				} else {
					try writer.print("{s}: {any}\n", .{field.name, value});
				}
			}
		}
		try writer.writeAll("}\n");
	}
};

test "formatNoPath" {
	const cfg = CliConfig.init(65536, 4096, 16384, false, true, null, std.testing.allocator);
	
	const cfgString = try std.fmt.allocPrint(std.testing.allocator, "{f}", .{cfg});
	defer std.testing.allocator.free(cfgString);
	
	try std.testing.expectEqualStrings(
		"CliConfig{\nmemSize: 65536\nstackSize: 4096\nheapSize: 16384\nenableAVExt: false\nfilePath: null\nallowSystem: true\n}\n", 
		cfgString
	);
}

test "formatPath" {
	const cfg = CliConfig.init(4096 * 5, 2048, 2048, true, false, "./samples/org.as", std.testing.allocator);

	const cfgString = try std.fmt.allocPrint(std.testing.allocator, "{f}", .{cfg});
	defer std.testing.allocator.free(cfgString);

	try std.testing.expectEqualStrings(
		"CliConfig{\nmemSize: 20480\nstackSize: 2048\nheapSize: 2048\nenableAVExt: true\nfilePath: ./samples/org.as\nallowSystem: false\n}\n",
		cfgString
	);
}