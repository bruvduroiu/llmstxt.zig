const std = @import("std");

pub const Function = struct {
    name: []u8,
    params: []u8,
    return_type: []u8,
    access_modifier: []u8,
    documentation: []u8,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        params: []const u8,
        return_type: []const u8,
        access_modifier: []const u8,
        documentation: []const u8,
    ) !Function {
        return .{
            .name = try allocator.dupe(u8, name),
            .params = try allocator.dupe(u8, params),
            .return_type = try allocator.dupe(u8, return_type),
            .access_modifier = try allocator.dupe(u8, access_modifier),
            .documentation = try allocator.dupe(u8, documentation),
            .allocator = allocator,
        };
    }

    pub fn destroy(self: *Function) void {
        self.allocator.free(self.name);
        self.allocator.free(self.params);
        self.allocator.free(self.return_type);
        self.allocator.free(self.access_modifier);
        self.allocator.free(self.documentation);
    }

    pub fn print(self: Function, writer: anytype) void {
        writer.print("func {s}() -> {s};", .{ self.name, self.return_type });
    }
};

pub const Property = struct {
    name: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !Property {
        return Property{
            .name = try allocator.dupe(u8, name),
            .allocator = allocator,
        };
    }

    pub fn destroy(self: *Property) void {
        self.allocator.free(self.name);
    }
};

pub const Definition = union(enum) {
    function: Function,

    pub fn print(self: Definition, writer: anytype) !void {
        switch (self) {
            inline else => |case| return case.print(writer),
        }
    }

    pub fn destroy(self: *Definition) void {
        switch (self) {
            inline else => |case| return case.destroy(),
        }
    }
};
