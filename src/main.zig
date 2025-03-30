const std = @import("std");
const ts = @import("tree-sitter");
const Allocator = std.mem.Allocator;

const parser = @import("parser.zig");
const CodeParser = parser.CodeParser;
const lang = @import("language.zig");
const LanguageType = lang.LanguageType;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get file path from args or use default
    var argsIterator = try std.process.ArgIterator.initWithAllocator(allocator);
    defer argsIterator.deinit();

    // Skip executable
    _ = argsIterator.next();

    var file_path: [:0]const u8 = undefined;
    if (argsIterator.next()) |path| {
        file_path = path;
    } else {
        return error.NoFile;
    }

    // Read the source file
    const source = try std.fs.cwd().readFileAlloc(
        allocator,
        file_path,
        1024 * 1024 * 10,
    );
    defer allocator.free(source);

    // Create and configure the parser
    var code_parser = try CodeParser.create(allocator, file_path, source);
    defer code_parser.destroy();

    // Extract definitions
    var definitions = try code_parser.extractDefinitions();
    defer definitions.deinit();

    // Print the definitions
    const stdout = std.io.getStdOut();
    const writer = stdout.writer();

    try writer.print("File: {s}\n", .{file_path});
    try writer.print("Language: {s}\n\n", .{code_parser.language_type.getName()});

    // Print all definitions
    for (definitions.items.items) |def| {
        try def.print(writer);
    }
}
