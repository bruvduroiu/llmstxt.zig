const std = @import("std");
const ts = @import("tree-sitter");

const Parser = @import("parser.zig");

extern fn tree_sitter_zig() callconv(.C) *ts.Language;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file_path = "/Users/bogdanbuduroiu/development/aurelio-labs/semantic-router/semantic_router/route.py";

    var parser = try Parser.create(allocator, file_path);
    defer parser.destroy();
    const definitions = try parser.extractDefinitions();
    _ = definitions; // autofix
}
