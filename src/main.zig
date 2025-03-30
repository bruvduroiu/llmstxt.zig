const std = @import("std");
const ts = @import("tree-sitter");

extern fn tree_sitter_zig() callconv(.C) *ts.Language;

pub fn main() !void {
    // Create a parser for the zig language
    const language = tree_sitter_zig();
    defer language.destroy();

    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(language);

    // Parse some source code and get the root node
    const tree = parser.parseString("pub fn main() !void {}", null);
    defer tree.?.destroy();

    const node = tree.?.rootNode();
    std.debug.assert(std.mem.eql(u8, node.kind(), "source_file"));
    std.debug.print("{s}", .{node.kind()});

    // Create a query and execute it
    var error_offset: u32 = 0;
    const query = try ts.Query.create(language, "name: (identifier) @name", &error_offset);
    defer query.destroy();

    const cursor = ts.QueryCursor.create();
    defer cursor.destroy();
    cursor.exec(query, node);

    // Get the captured node of the first match
    const match = cursor.nextMatch().?;
    const capture = match.captures[0].node;
    std.debug.assert(std.mem.eql(u8, capture.kind(), "identifier"));
}
