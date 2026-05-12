// zig fmt: off

const std = @import("std");


pub const MemoryError = error{
	OutOfBounds,
	UnalignedAccess,
	DuplicateLabel,
	LabelNotFound
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

	symbolMap: std.StringHashMap(u32),

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

		var symbolMap = std.StringHashMap(u32).init(allocator);
		// Pre-populate symbol map with "labels" indicating segment starts
		try symbolMap.put("data", dataSegStart);
		try symbolMap.put("text", textSegStart);
		try symbolMap.put("heap", heapStart);
		try symbolMap.put("stack", stackStart);


		return AruMemory{
			.mem = memSlice,
			.memSize = memSize,
			.dataSegStart = dataSegStart,
			.textSegStart = textSegStart,
			.heapStart = heapStart,
			.stackStart = stackStart,
			.symbolMap = symbolMap,
		};
	}


	pub fn deinit(this: *AruMemory) void {
		std.debug.print("Deinitializing memory...\n", .{});
		this.symbolMap.deinit();
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


	// Symbol Map Interface
	// Recommended to use this interface to interact with the map instead of directly accessing the map, 
	//  to ensure proper error handling and to abstract away implementation details.

	/// Adds a label to the symbol map with its associated address. Used for labels in assembly code.
	/// It also makes sure that the value is not out of memory size.
	/// If an address is already associated with the given label, it will be overwritten.
	/// However, the only labels not allowed to be overwritten are the predefined segment labels ("data", "text", "heap", "stack").
	pub fn addLabel(this: *AruMemory, label: []const u8, addr: u32) !void {
		if (addr >= this.memSize) {
			return MemoryError.OutOfBounds;
		}

		if (std.mem.eql(u8, label, "data") or std.mem.eql(u8, label, "text") or std.mem.eql(u8, label, "heap") or std.mem.eql(u8, label, "stack")) {
			return MemoryError.DuplicateLabel;
		}

		try this.symbolMap.put(label, addr);
	}

	/// Adds a symbol to the symbol map with its associated value. Used for directives like `.set`.
	pub fn addSymbol(this: *AruMemory, symbol: []const u8, value: u32) !void {
		try this.symbolMap.put(symbol, value);
	}

	/// Retrieves the address associated with a label from the symbol map.
	/// The label may be a user-defined label or a predefined segment label ("data", "text", "heap", "stack").
	/// If the label is not found in the symbol map, it returns an error.
	pub fn getAddress(this: *AruMemory, label: []const u8) !u32 {
		const addr = this.symbolMap.get(label);
		if (addr) |a| {
			return a;
		} else {
			return MemoryError.LabelNotFound;
		}
	}
};