const std = @import("std");
const ts = @import("tree-sitter");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const defs = @import("definitions.zig");
const Definition = defs.Definition;
const Function = defs.Function;
const Property = defs.Property;
const ClassProperty = defs.ClassProperty;
const Method = defs.Method;
const Class = defs.Class;
const DefinitionList = defs.DefinitionList;

const lang = @import("language.zig");
const LanguageType = lang.LanguageType;

pub const CodeParser = struct {
    const Self = @This();
    parser: *ts.Parser,
    language_type: LanguageType,
    allocator: Allocator,
    source: []const u8,

    // Maps to track class definitions for later reference
    class_map: StringHashMap(*Class),

    pub fn create(allocator: Allocator, file_path: []const u8, source: []const u8) !*Self {
        // Determine language from file extension
        const ext = std.fs.path.extension(file_path);
        const language_type = LanguageType.fromExtension(ext);

        // Get the tree-sitter language
        const language = language_type.getLanguage() orelse return error.UnsupportedLanguage;

        // Create and configure the parser
        var parser = ts.Parser.create();
        errdefer parser.destroy();
        try parser.setLanguage(language);

        // Create the parser instance
        const p = try allocator.create(Self);
        errdefer allocator.destroy(p);

        p.* = .{
            .parser = parser,
            .language_type = language_type,
            .allocator = allocator,
            .source = source,
            .class_map = StringHashMap(*Class).init(allocator),
        };

        return p;
    }

    pub fn destroy(self: *Self) void {
        // Free class map entries
        var it = self.class_map.iterator();
        while (it.next()) |entry| {
            // Classes will be freed when the definitions list is freed
            _ = entry;
        }
        self.class_map.deinit();

        // Free the parser
        self.parser.destroy();

        // Free self
        self.allocator.destroy(self);
    }

    pub fn extractDefinitions(self: *Self) !DefinitionList {
        var definitions = DefinitionList.init(self.allocator);
        errdefer definitions.deinit();

        // Parse the source code
        const tree = self.parser.parseString(self.source, null);
        if (tree == null) {
            return error.ParseFailed;
        }
        defer tree.?.destroy();

        const root_node = tree.?.rootNode();

        // Get the appropriate query for this language
        const query_string = self.language_type.getQuery() orelse return error.QueryNotFound;
        var error_offset: u32 = 0;
        const query = try ts.Query.create(self.parser.getLanguage() orelse return error.LanguageNotSet, query_string, &error_offset);
        defer query.destroy();

        // Execute the query
        const cursor = ts.QueryCursor.create();
        defer cursor.destroy();
        cursor.exec(query, root_node);

        // Track captured nodes to avoid duplicates
        var captured_nodes = std.AutoHashMap(ts.Node, void).init(self.allocator);
        defer captured_nodes.deinit();

        while (cursor.nextMatch()) |match| {
            for (match.captures) |capture| {
                const capture_name = query.captureNameForId(capture.index) orelse continue;
                const node = capture.node;

                // Skip if we've already processed this node
                if (captured_nodes.contains(node)) continue;
                try captured_nodes.put(node, {});

                // Extract node text and name
                const node_text = self.source[node.startByte()..node.endByte()];
                const name = if (node.childByFieldName("name")) |name_node|
                    self.source[name_node.startByte()..name_node.endByte()]
                else
                    node_text;

                // Extract documentation if available
                const doc = self.extractDocumentation(node);

                try self.processCapture(capture_name, node, name, doc, &definitions);
            }
        }

        return definitions;
    }

    fn extractDocumentation(self: *Self, node: ts.Node) ?[]const u8 {
        // Look for docstrings in various formats depending on language
        // This is a simplified implementation
        if (self.language_type == .python) {
            // For Python, look for a string as the first child of a function/class body
            if (node.childByFieldName("body")) |body| {
                if (body.namedChild(0)) |first_child| {
                    if (std.mem.eql(u8, first_child.kind(), "string")) {
                        return self.source[first_child.startByte()..first_child.endByte()];
                    }
                }
            }
        }

        return null;
    }

    fn processCapture(self: *Self, capture_name: []const u8, node: ts.Node, name: []const u8, doc: ?[]const u8, definitions: *DefinitionList) !void {
        if (std.mem.eql(u8, capture_name, "function")) {
            const func = try Function.init(self.allocator, name, doc);
            try definitions.append(.{ .function = func });
        } else if (std.mem.eql(u8, capture_name, "class")) {
            const class = try Class.init(self.allocator, name, doc);
            try self.class_map.put(name, class);
            try definitions.append(.{ .class = class });
        } else if (std.mem.eql(u8, capture_name, "method")) {
            // Find the parent class
            const class_name = self.findParentClassName(node);
            if (class_name) |cn| {
                const method = try Method.init(self.allocator, name, cn, doc);

                // Add to class if we have it
                if (self.class_map.get(cn)) |class| {
                    try class.addMethod(method);
                } else {
                    // Otherwise add as standalone method
                    try definitions.append(.{ .method = method });
                }
            } else {
                // If we can't find a parent class, treat it as a function
                const func = try Function.init(self.allocator, name, doc);
                try definitions.append(.{ .function = func });
            }
        } else if (std.mem.eql(u8, capture_name, "class_assignment") or
            std.mem.eql(u8, capture_name, "class_variable"))
        {
            // Find the parent class
            const class_name = self.findParentClassName(node);
            if (class_name) |cn| {
                const prop = try ClassProperty.init(self.allocator, name, cn, doc);

                // Add to class if we have it
                if (self.class_map.get(cn)) |class| {
                    try class.addProperty(prop);
                } else {
                    // Otherwise add as standalone property
                    try definitions.append(.{ .class_property = prop });
                }
            } else {
                // If we can't find a parent class, treat it as a regular property
                const prop = try Property.init(self.allocator, name, doc);
                try definitions.append(.{ .property = prop });
            }
        } else if (std.mem.eql(u8, capture_name, "assignment")) {
            const prop = try Property.init(self.allocator, name, doc);
            try definitions.append(.{ .property = prop });
        } else if (std.mem.eql(u8, capture_name, "docstring")) {
            // Handle docstrings - already processed in extractDocumentation
        }
    }

    fn findParentClassName(self: *Self, node: ts.Node) ?[]const u8 {
        var current = node.parent();
        while (current) |parent| {
            if (std.mem.eql(u8, parent.kind(), "class_definition")) {
                if (parent.childByFieldName("name")) |name_node| {
                    return self.source[name_node.startByte()..name_node.endByte()];
                }
                return null;
            }
            current = parent.parent();
        }
        return null;
    }
};
