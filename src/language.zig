const std = @import("std");
const ts = @import("tree-sitter");
const Allocator = std.mem.Allocator;

extern fn tree_sitter_zig() callconv(.C) *ts.Language;
extern fn tree_sitter_c() callconv(.C) *ts.Language;
extern fn tree_sitter_python() callconv(.C) *ts.Language;
extern fn tree_sitter_go() callconv(.C) *ts.Language;

pub const LanguageType = enum {
    python,
    zig,
    c,
    go,
    unknown,

    pub fn fromExtension(ext: []const u8) LanguageType {
        if (std.mem.eql(u8, ext, ".py")) {
            return .python;
        } else if (std.mem.eql(u8, ext, ".zig")) {
            return .zig;
        } else if (std.mem.eql(u8, ext, ".c") or std.mem.eql(u8, ext, ".h")) {
            return .c;
        } else if (std.mem.eql(u8, ext, ".go")) {
            return .go;
        } else {
            return .unknown;
        }
    }

    pub fn getName(self: LanguageType) []const u8 {
        return switch (self) {
            .python => "python",
            .zig => "zig",
            .c => "c",
            .go => "go",
            .unknown => "unknown",
        };
    }

    pub fn getLanguage(self: LanguageType) ?*ts.Language {
        return switch (self) {
            .python => tree_sitter_python(),
            .zig => tree_sitter_zig(),
            .c => tree_sitter_c(),
            .go => tree_sitter_go(),
            .unknown => null,
        };
    }

    pub fn getQuery(self: LanguageType) ?[]const u8 {
        return switch (self) {
            .python =>
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
            ,
            .zig =>
            \\ ;; Capture functions, structs, methods, variable definitions, and unions in Zig
            \\(variable_declaration (identifier)
            \\  (struct_declaration
            \\        (container_field) @class_variable))
            \\
            \\(variable_declaration (identifier)
            \\  (struct_declaration
            \\        (function_declaration
            \\            name: (identifier) @method)))
            \\
            \\(variable_declaration (identifier)
            \\  (enum_declaration
            \\    (container_field
            \\      type: (identifier) @enum_item)))
            \\
            \\(variable_declaration (identifier)
            \\  (union_declaration
            \\    (container_field
            \\      name: (identifier) @union_item)))
            \\
            \\(source_file (function_declaration) @function)
            \\
            \\(source_file (variable_declaration (identifier) @variable))
            ,
            .c =>
            \\;; Capture extern functions, variables, public classes, and methods
            \\(function_definition
            \\  (storage_class_specifier) @extern
            \\) @function
            \\(class_specifier
            \\  (public) @class
            \\  (function_definition) @method
            \\) @class
            \\(declaration
            \\  (storage_class_specifier) @extern
            \\) @variable
            ,
            .go =>
            \\;; Capture top-level functions and struct definitions
            \\(source_file
            \\  (var_declaration
            \\    (var_spec) @variable
            \\  )
            \\)
            \\(source_file
            \\  (const_declaration
            \\    (const_spec) @variable
            \\  )
            \\)
            \\(source_file
            \\  (function_declaration) @function
            \\)
            \\(source_file
            \\  (type_declaration
            \\    (type_spec (struct_type)) @class
            \\  )
            \\)
            \\(source_file
            \\  (type_declaration
            \\    (type_spec
            \\      (struct_type
            \\        (field_declaration_list
            \\          (field_declaration) @class_variable)))
            \\  )
            \\)
            \\(source_file
            \\  (method_declaration) @method
            \\)
            ,
            .unknown => null,
        };
    }
};
