// zig fmt: off

const std = @import("std");
const Config = @import("config.zig");

pub fn executeFile(cliConfig: *Config.CliConfig) !void {
	std.debug.print("Executing file: {s}\n", .{cliConfig.filePath.?});
	return;
}