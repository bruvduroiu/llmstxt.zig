//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const ts = @import("tree-sitter");
const testing = std.testing;
const Parser = @import("parser.zig");

extern fn tree_sitter_python() callconv(.C) *ts.Language;

test "basic add functionality" {
    const p = try Parser.create(testing.allocator, tree_sitter_python());
    const definitions = try p.extractDefinitions("def is_valid() -> bool: ...");

    const def = definitions[0];
    switch (def) {
        .function => try testing.expect(std.mem.eql(def.function.name, "is_valid")),
        else => unreachable,
    }
}
