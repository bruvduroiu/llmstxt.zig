const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// Base definition struct with common fields
const BaseDefinition = struct {
    name: []const u8,
    allocator: Allocator,
    documentation: ?[]const u8 = null,

    fn deinitBase(self: *const BaseDefinition) void {
        self.allocator.free(self.name);
        if (self.documentation) |doc| {
            self.allocator.free(doc);
        }
    }

    fn initBase(allocator: Allocator, name: []const u8, documentation: ?[]const u8) !BaseDefinition {
        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        var doc_copy: ?[]const u8 = null;
        if (documentation) |doc| {
            doc_copy = try allocator.dupe(u8, doc);
            errdefer if (doc_copy) |d| allocator.free(d);
        }

        return BaseDefinition{
            .name = name_copy,
            .allocator = allocator,
            .documentation = doc_copy,
        };
    }
};

pub const Function = struct {
    const Self = @This();
    base: BaseDefinition,
    parameters: ArrayList([]const u8),
    return_type: ?[]const u8 = null,

    pub fn init(allocator: Allocator, name: []const u8, documentation: ?[]const u8) !*Self {
        const base = try BaseDefinition.initBase(allocator, name, documentation);
        errdefer base.deinitBase();

        const f = try allocator.create(Self);
        errdefer allocator.destroy(f);

        f.* = .{
            .base = base,
            .parameters = ArrayList([]const u8).init(allocator),
            .return_type = null,
        };
        return f;
    }

    pub fn deinit(self: *Self) void {
        // Free parameter strings
        for (self.parameters.items) |param| {
            self.base.allocator.free(param);
        }
        self.parameters.deinit();

        // Free return type if it exists
        if (self.return_type) |ret_type| {
            self.base.allocator.free(ret_type);
        }

        // Free base definition fields
        self.base.deinitBase();

        // Free the struct itself
        self.base.allocator.destroy(self);
    }

    pub fn print(self: Self, writer: anytype) !void {
        try writer.print("func {s}(", .{self.base.name});

        for (self.parameters.items, 0..) |param, i| {
            if (i > 0) try writer.print(", ", .{});
            try writer.print("{s}", .{param});
        }

        try writer.print(") -> ", .{});

        if (self.return_type) |ret| {
            try writer.print("{s}", .{ret});
        } else {
            try writer.print("void", .{});
        }

        try writer.print(";\n", .{});
    }

    pub fn addParameter(self: *Self, param: []const u8) !void {
        const param_copy = try self.base.allocator.dupe(u8, param);
        errdefer self.base.allocator.free(param_copy);
        try self.parameters.append(param_copy);
    }

    pub fn setReturnType(self: *Self, ret_type: []const u8) !void {
        if (self.return_type) |old_ret| {
            self.base.allocator.free(old_ret);
        }
        self.return_type = try self.base.allocator.dupe(u8, ret_type);
    }
};

pub const Method = struct {
    const Self = @This();
    function: Function,
    class_name: []const u8,

    pub fn init(allocator: Allocator, name: []const u8, class_name: []const u8, documentation: ?[]const u8) !*Self {
        const func = try Function.init(allocator, name, documentation);
        errdefer func.deinit();

        const class_name_copy = try allocator.dupe(u8, class_name);
        errdefer allocator.free(class_name_copy);

        const m = try allocator.create(Self);
        errdefer allocator.destroy(m);

        m.* = .{
            .function = func.*,
            .class_name = class_name_copy,
        };

        // We've copied the function, so we can destroy the original
        allocator.destroy(func);

        return m;
    }

    pub fn deinit(self: *Self) void {
        // Free the class name
        self.function.base.allocator.free(self.class_name);

        // Clean up function fields but don't destroy the struct
        // Free parameter strings
        for (self.function.parameters.items) |param| {
            self.function.base.allocator.free(param);
        }
        self.function.parameters.deinit();

        // Free return type if it exists
        if (self.function.return_type) |ret_type| {
            self.function.base.allocator.free(ret_type);
        }

        // Free base definition fields
        self.function.base.deinitBase();

        // Free the struct itself
        self.function.base.allocator.destroy(self);
    }

    pub fn print(self: Self, writer: anytype) !void {
        try writer.print("method {s}::{s}(", .{ self.class_name, self.function.base.name });

        for (self.function.parameters.items, 0..) |param, i| {
            if (i > 0) try writer.print(", ", .{});
            try writer.print("{s}", .{param});
        }

        try writer.print(") -> ", .{});

        if (self.function.return_type) |ret| {
            try writer.print("{s}", .{ret});
        } else {
            try writer.print("void", .{});
        }

        try writer.print(";\n", .{});
    }
};

pub const Property = struct {
    const Self = @This();
    base: BaseDefinition,
    type: ?[]const u8 = null,

    pub fn init(allocator: Allocator, name: []const u8, documentation: ?[]const u8) !*Self {
        const base = try BaseDefinition.initBase(allocator, name, documentation);
        errdefer base.deinitBase();

        const p = try allocator.create(Self);
        errdefer allocator.destroy(p);

        p.* = .{
            .base = base,
            .type = null,
        };
        return p;
    }

    pub fn deinit(self: *Self) void {
        // Free type if it exists
        if (self.type) |t| {
            self.base.allocator.free(t);
        }

        // Free base definition fields
        self.base.deinitBase();

        // Free the struct itself
        self.base.allocator.destroy(self);
    }

    pub fn print(self: Property, writer: anytype) !void {
        try writer.print("var {s}", .{self.base.name});

        if (self.type) |t| {
            try writer.print(": {s}", .{t});
        }

        try writer.print(";\n", .{});
    }

    pub fn setType(self: *Self, prop_type: []const u8) !void {
        if (self.type) |old_type| {
            self.base.allocator.free(old_type);
        }
        self.type = try self.base.allocator.dupe(u8, prop_type);
    }
};

pub const ClassProperty = struct {
    const Self = @This();
    property: Property,
    class_name: []const u8,

    pub fn init(allocator: Allocator, name: []const u8, class_name: []const u8, documentation: ?[]const u8) !*Self {
        const prop = try Property.init(allocator, name, documentation);
        errdefer prop.deinit();

        const class_name_copy = try allocator.dupe(u8, class_name);
        errdefer allocator.free(class_name_copy);

        const cp = try allocator.create(Self);
        errdefer allocator.destroy(cp);

        cp.* = .{
            .property = prop.*,
            .class_name = class_name_copy,
        };

        // We've copied the property, so we can destroy the original
        allocator.destroy(prop);

        return cp;
    }

    pub fn deinit(self: *Self) void {
        // Free the class name
        self.property.base.allocator.free(self.class_name);

        // Clean up property fields but don't destroy the struct
        // Free type if it exists
        if (self.property.type) |t| {
            self.property.base.allocator.free(t);
        }

        // Free base definition fields
        self.property.base.deinitBase();

        // Free the struct itself
        self.property.base.allocator.destroy(self);
    }

    pub fn print(self: ClassProperty, writer: anytype) !void {
        try writer.print("prop {s}::{s}", .{ self.class_name, self.property.base.name });

        if (self.property.type) |t| {
            try writer.print(": {s}", .{t});
        }

        try writer.print(";\n", .{});
    }
};

pub const Class = struct {
    const Self = @This();
    base: BaseDefinition,
    properties: ArrayList(*ClassProperty),
    methods: ArrayList(*Method),

    pub fn init(allocator: Allocator, name: []const u8, documentation: ?[]const u8) !*Self {
        const base = try BaseDefinition.initBase(allocator, name, documentation);
        errdefer base.deinitBase();

        const c = try allocator.create(Self);
        errdefer allocator.destroy(c);

        c.* = .{
            .base = base,
            .properties = ArrayList(*ClassProperty).init(allocator),
            .methods = ArrayList(*Method).init(allocator),
        };
        return c;
    }

    pub fn deinit(self: *Self) void {
        // Free all properties
        for (self.properties.items) |prop| {
            prop.deinit();
        }
        self.properties.deinit();

        // Free all methods
        for (self.methods.items) |method| {
            method.deinit();
        }
        self.methods.deinit();

        // Free base definition fields
        self.base.deinitBase();

        // Free the struct itself
        self.base.allocator.destroy(self);
    }

    pub fn print(self: Class, writer: anytype) !void {
        try writer.print("class {s} {{\n", .{self.base.name});

        for (self.properties.items) |prop| {
            try writer.print("  ", .{});
            try prop.print(writer);
        }

        if (self.properties.items.len > 0 and self.methods.items.len > 0) {
            try writer.print("\n", .{});
        }

        for (self.methods.items) |method| {
            try writer.print("  ", .{});
            try method.print(writer);
        }

        try writer.print("}};\n", .{});
    }

    pub fn addProperty(self: *Self, prop: *ClassProperty) !void {
        try self.properties.append(prop);
    }

    pub fn addMethod(self: *Self, method: *Method) !void {
        try self.methods.append(method);
    }
};

pub const Definition = union(enum) {
    const Self = @This();
    function: *Function,
    property: *Property,
    class_property: *ClassProperty,
    method: *Method,
    class: *Class,

    pub fn print(self: Definition, writer: anytype) !void {
        switch (self) {
            inline else => |case| try case.print(writer),
        }
    }

    pub fn deinit(self: Self) void {
        switch (self) {
            inline else => |case| case.deinit(),
        }
    }
};

pub const DefinitionList = struct {
    const Self = @This();
    items: ArrayList(Definition),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Self {
        return Self{
            .items = ArrayList(Definition).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.items.items) |def| {
            def.deinit();
        }
        self.items.deinit();
    }

    pub fn append(self: *Self, def: Definition) !void {
        try self.items.append(def);
    }

    pub fn pop(self: *Self) ?Definition {
        return if (self.items.items.len > 0) self.items.pop() else null;
    }
};
