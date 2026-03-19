// zig fmt: off

const std = @import("std");
const Memory = @import("mem.zig");

pub const OsError = error{
	InvalidSyscall,
	MissingArgument,
};

const SyscallType = enum {
	READ,
	WRITE,
};

pub const SyscallData = struct {
	stype: u32,
	arg0: ?u32 = undefined,
	arg1: ?u32 = undefined,
	arg2: ?u32 = undefined,
	arg3: ?u32 = undefined,
	arg4: ?u32 = undefined,
	arg5: ?u32 = undefined,
	arg6: ?u32 = undefined,
	arg7: ?u32 = undefined,
	arg8: ?u32 = undefined
};


pub fn handleSyscall(data: SyscallData, mem: *Memory.AruMemory) !void {
	std.debug.print("Handling syscall with arguments: {any}\n", .{data});

	const syscallType: SyscallType = @enumFromInt(data.stype);

	switch (syscallType) {
		.READ => {
			// arg0: count, arg1: buffer address
			std.debug.print("Syscall: READ with arg0={any}, arg1={any}\n", .{data.arg0, data.arg1});
			
			const count = data.arg0 orelse return OsError.MissingArgument;
			const bufferAddr = data.arg1 orelse return OsError.MissingArgument;

			var memSegment = mem.mem[bufferAddr..bufferAddr + count];
			const bytesRead = try std.fs.File.stdin().readAll(memSegment);
			std.debug.print("Input read from READ syscall: {s}\n", .{memSegment[0..bytesRead]});

		},
		.WRITE => {
			// arg0: count, arg1: buffer address
			std.debug.print("Syscall: WRITE with arg0={any}, arg1={any}\n", .{data.arg0, data.arg1});
			
			const count = data.arg0 orelse return OsError.MissingArgument;
			const bufferAddr = data.arg1 orelse return OsError.MissingArgument;

			const memSegment = mem.mem[bufferAddr..bufferAddr + count];
			// const output = std.mem.trimRight(u8, memSegment, 0); // Trim null bytes for cleaner output
			std.debug.print("Output from WRITE syscall: {s}\n", .{memSegment[0..count]});
			try std.fs.File.stdout().writeAll(memSegment[0..count]);
		}
	}
}