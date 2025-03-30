const std = @import("std");
const ts = @import("tree-sitter");
const Allocator = std.mem.Allocator;
const MultiArrayList = std.MultiArrayList;
const definitions = @import("definitions.zig");
const Definition = definitions.Definition;
const Function = definitions.Function;

const Self = @This();
parser: *ts.Parser,
language_name: []const u8,
source: []const u8,
allocator: Allocator,

pub fn create(allocator: Allocator, file_path: []const u8) !*Self {
    const ext = std.fs.path.extension(file_path);

    var parser = ts.Parser.create();
    errdefer parser.destroy();

    const language = try getLanguageForExtension(ext);
    try parser.setLanguage(language);

    const source = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024 * 10); // 10MB max
    errdefer allocator.free(source);

    const p = try allocator.create(Self);
    p.* = .{
        .parser = parser,
        .source = source,
        .allocator = allocator,
        .language_name = "python",
    };
    return p;
}

pub fn destroy(self: *Self) void {
    self.parser.destroy();
    self.allocator.free(self.source);
    self.allocator.destroy(self);
}

pub fn extractDefinitions(self: *Self) !MultiArrayList(Definition) {
    var defs = MultiArrayList(Definition){};
    defer defs.deinit(self.allocator);

    // Parse the source code
    const tree = self.parser.parseString(self.source, null);
    if (tree == null) {
        return error.ParseFailed;
    }
    defer tree.?.destroy();

    const root_node = tree.?.rootNode();

    // Get the appropriate query for this language
    const query_string = try getQueryForLanguage(self.language_name);
    var error_offset: u32 = 0;
    const query = try ts.Query.create(self.parser.getLanguage() orelse tree_sitter_python(), query_string, &error_offset);
    defer query.destroy();

    // Execute the query
    const cursor = ts.QueryCursor.create();
    defer cursor.destroy();
    cursor.exec(query, root_node);

    while (cursor.nextMatch()) |match| {
        for (match.captures) |capture| {
            const capture_name = query.captureNameForId(capture.index) orelse "mock_caputer";
            const node = capture.node;
            const node_text = self.source[node.startByte()..node.endByte()];
            const name = if (node.childByFieldName("name")) |name_node|
                self.source[name_node.startByte()..name_node.endByte()]
            else
                node_text;

            if (std.mem.eql(u8, capture_name, "function")) {
                var func_def = try Function.init(self.allocator, name, "", "", "", "");
                try defs.append(self.allocator, func_def);
                defer func_def.destroy();
            }
        }
    }

    for (defs) |def| {
        try def.print(std.debug);
    }
    return defs;
}

// Helper

fn getLanguageForExtension(ext: []const u8) !*ts.Language {
    if (std.mem.eql(u8, ext, ".zig")) {
        return tree_sitter_zig();
    } else if (std.mem.eql(u8, ext, ".c") or std.mem.eql(u8, ext, ".h")) {
        return tree_sitter_c();
    } else if (std.mem.eql(u8, ext, ".py")) {
        return tree_sitter_python();
    } else {
        return error.UnsupportedLanguage;
    }
}

fn getQueryForLanguage(language_name: []const u8) ![]const u8 {
    // In a real implementation, this would load queries from files
    if (std.mem.eql(u8, language_name, "python")) {
        return 
        \\;; Capture top-level functions, class, and method definitions
        \\(module
        \\  (expression_statement
        \\    (assignment) @assignment
        \\  )
        \\)
        \\(module
        \\  (function_definition) @function
        \\)
        \\(module
        \\  (decorated_definition
        \\    definition: (function_definition) @function
        \\  )
        \\)
        \\(module
        \\  (class_definition
        \\    body: (block
        \\      (expression_statement
        \\        (assignment) @class_assignment
        \\      )
        \\    )
        \\  ) @class
        \\)
        \\(module
        \\  (class_definition
        \\    body: (block
        \\      (function_definition) @method
        \\    )
        \\  ) @class
        \\)
        \\(module
        \\  (class_definition
        \\    body: (block
        \\      (expression_statement 
        \\        (string) @docstring
        \\      )
        \\    )
        \\  ) @class
        \\)
        \\(module
        \\  (class_definition
        \\    body: (block
        \\      (decorated_definition
        \\        definition: (function_definition) @method
        \\      )
        \\    )
        \\  ) @class
        \\)
        ;
    } else {
        return 
        \\(function_definition name: (identifier) @function)
        \\(class_definition name: (identifier) @class)
        \\(method_definition name: (identifier) @method)
        ;
    }
}

// External C functions for tree-sitter languages
extern fn tree_sitter_zig() callconv(.C) *ts.Language;
extern fn tree_sitter_c() callconv(.C) *ts.Language;
extern fn tree_sitter_python() callconv(.C) *ts.Language;
