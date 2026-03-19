// zig fmt: off

const std = @import("std");


/// Preprocess a line that can either be:
///   label: .directive...
///   label: instruction...
///   .directive...
///   instruction...
/// It will return a struct containing the label (if any), and either the directive or instruction (if any).
pub fn preprocess(str: []const u8) struct { ?[]const u8, ?[]const u8 } {
	// Everything up until the first colon is the label (if it exists)
	const colonIndex = std.mem.indexOf(u8, str, ":");
	if (colonIndex) |idx| {
		const label = str[0..idx];
		const rest = str[idx + 1..];
		// Now we need to determine if the rest is a directive or an instruction
		const trimmedRest = std.mem.trim(u8, rest, " \t");
		if (std.mem.startsWith(u8, trimmedRest, ".")) {
			// It's a directive
			return .{ label, trimmedRest };
		} else {
			// It's an instruction
			return .{ label, trimmedRest };
		}
	} else {
		// No label, so we just need to determine if it's a directive or an instruction
		const trimmedStr = std.mem.trim(u8, str, " \t");
		if (std.mem.startsWith(u8, trimmedStr, ".")) {
			// It's a directive
			return .{ null, trimmedStr };
		} else {
			// It's an instruction
			return .{ null, trimmedStr };
		}
	}
}

test "Label with instruction" {
	const result = preprocess("loop: add x0, x1, x2");
	const resultLabel = result.@"0";
	const resultRest = result.@"1";
	const expectedLabel = "loop";
	const expectedRest = "add x0, x1, x2";
	try std.testing.expectEqualStrings(expectedLabel, resultLabel.?);
	try std.testing.expectEqualStrings(expectedRest, resultRest.?);
}

test "Label with directive" {
	const result = preprocess("data: .word 0x12345678");
	const resultLabel = result.@"0";
	const resultRest = result.@"1";
	const expectedLabel = "data";
	const expectedRest = ".word 0x12345678";
	try std.testing.expectEqualStrings(expectedLabel, resultLabel.?);
	try std.testing.expectEqualStrings(expectedRest, resultRest.?);
}

test "Instruction only" {
	const result = preprocess("add x0, x1, x2");
	const resultLabel = result.@"0";
	const resultRest = result.@"1";
	const expectedRest = "add x0, x1, x2";
	try std.testing.expect(resultLabel == null);
	try std.testing.expectEqualStrings(expectedRest, resultRest.?);
}

test "Directive only" {
	const result = preprocess(".word 0x12345678");
	const resultLabel = result.@"0";
	const resultRest = result.@"1";
	const expectedRest = ".word 0x12345678";
	try std.testing.expect(resultLabel == null);
	try std.testing.expectEqualStrings(expectedRest, resultRest.?);
}

test "Label only" {
	const result = preprocess("loop:");
	const resultLabel = result.@"0";
	const resultRest = result.@"1";
	const expectedLabel = "loop";
	try std.testing.expectEqualStrings(expectedLabel, resultLabel.?);
	try std.testing.expect(resultRest == null);
}