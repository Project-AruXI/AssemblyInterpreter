// zig fmt: off

const std = @import("std");


pub const MemoryError = error{
	OutOfBounds,
	UnalignedAccess,
};


pub const AruMemory = struct {
	// Memory will be dynamically allocated since:
	// 1) Repl and Interpreter allow setting size of memory
	// 2) WebAssembly target requires its memory to be set
	mem: []u8,

	// Memory starts with data segments, then text, then heap, then stack
	// Heap and stack sizes are controllable
	memSize: u32,
	dataSegStart: u32,
	textSegStart: u32,
	heapStart: u32,
	stackStart: u32,

	labelMap: std.AutoHashMap([]const u8, u32),

	pub fn init(allocator: std.mem.Allocator, memSize: u32, heapSize: u32, stackSize: u32) !AruMemory {
		std.debug.print("Initializing memory with size {d} bytes...\n", .{memSize});
		const memSlice = try allocator.alloc(u8, @as(usize, memSize));
		@memset(memSlice, 0); // Zero out memory for safety

		// Calculate segment start addresses based on initial sizes (will be updated later)
		const remainingSize = memSize - heapSize - stackSize;
		const dataSegSize = remainingSize / 2;
		const textSegSize = remainingSize - dataSegSize;

		// Data segment starts at 0, then text, then heap, then stack
		const dataSegStart = 0x0;
		const textSegStart = dataSegStart + dataSegSize;
		const heapStart = textSegStart + textSegSize;
		const stackStart = heapStart + heapSize;

		return AruMemory{
			.mem = memSlice,
			.memSize = memSize,
			.dataSegStart = dataSegStart,
			.textSegStart = textSegStart,
			.heapStart = heapStart,
			.stackStart = stackStart,
			.labelMap = std.AutoHashMap([]const u8, u32).init(allocator),
		};
	}


	pub fn deinit(this: *AruMemory) void {
		std.debug.print("Deinitializing memory...\n", .{});
		this.labelMap.deinit();
		this.mem = null;
	}

	// Writer Interface

	pub fn writeByte(this: *AruMemory, addr: u32, value: u8) !void {
		const idx: usize = @intCast(addr);
		if (idx >= this.mem.len) return MemoryError.OutOfBounds;
		this.mem[idx] = value;
	}
	pub fn writeHalfWord(this: *AruMemory, addr: u32, value: u16) !void {
		const idx: usize = @intCast(addr);
		if (idx + 1 >= this.mem.len) return MemoryError.OutOfBounds;
		var tmp: [2]u8 = undefined;
		std.mem.writeInt(u16, tmp[0..], value, .little);
		@memcpy(this.mem[idx..idx + 2], tmp[0..2]);
	}
	pub fn writeWord(this: *AruMemory, addr: u32, value: u32) !void {
		const idx: usize = @intCast(addr);
		if (idx + 3 >= this.mem.len) return MemoryError.OutOfBounds;
		var tmp: [4]u8 = undefined;
		std.mem.writeInt(u32, tmp[0..], value, .little);
		@memcpy(this.mem[idx..idx + 4], tmp[0..4]);
	}

	// Alt
	pub fn write(this: *AruMemory, comptime T: type, addr: u32, value: T) !void {
		const idx: usize = @intCast(addr);
		if (idx + @sizeOf(T) - 1 >= this.mem.len) return MemoryError.OutOfBounds;
		var tmp: [@sizeOf(T)]u8 = undefined;
		std.mem.writeInt(T, tmp[0..], value, .little);
		@memcpy(this.mem[idx..idx + @sizeOf(T)], tmp[0..@sizeOf(T)]);
	}


	// Reader Interface

	pub fn readByte(this: *AruMemory, addr: u32) !u8 {
		const idx: usize = @intCast(addr);
		if (idx >= this.mem.len) return MemoryError.OutOfBounds;
		return this.mem[idx];
	}
	pub fn readHalfWord(this: *AruMemory, addr: u32) !u16 {
		const idx: usize = @intCast(addr);
		if (idx + 1 >= this.mem.len) return MemoryError.OutOfBounds;
		var tmp: [2]u8 = undefined;
		@memcpy(tmp[0..], this.mem[idx..idx + 2]);
		return std.mem.readInt(u16, tmp[0..2], .little);
	}
	pub fn readWord(this: *AruMemory, addr: u32) !u32 {
		const idx: usize = @intCast(addr);
		if (idx + 3 >= this.mem.len) return MemoryError.OutOfBounds;

		var tmp: [4]u8 = undefined;
		// @memcpy(tmp[0..4], memSegment.*);
		@memcpy(tmp[0..], this.mem[idx..idx + 4]);
		return std.mem.readInt(u32, tmp[0..4], .little);
	}

	// Alt
	pub fn read(this: *AruMemory, comptime T: type, addr: u32) !T {
		const idx: usize = @intCast(addr);
		if (idx + @sizeOf(T) - 1 >= this.mem.len) return MemoryError.OutOfBounds;
		var tmp: [@sizeOf(T)]u8 = undefined;
		@memcpy(tmp[0..], this.mem[idx..idx + @sizeOf(T)]);
		return std.mem.readInt(T, tmp[0..@sizeOf(T)], .little);
	}
};