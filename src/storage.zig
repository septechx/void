const std = @import("std");
const p = @import("parser.zig");
const library = @import("library.zig");
const Node = library.Node;

pub fn stringify(allocator: std.mem.Allocator, node: Node) ![]const u8 {
    // This could be replaced by a file stream
    var buf: [4096]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    try writer.print("{s}:[", .{node.Unit.name});

    for (node.Unit.children.items) |child| {
        switch (child) {
            .Unit => {
                const string = try stringify(allocator, child);
                defer allocator.free(string);

                try writer.writeAll(string);
            },
            .Entry => |entry| {
                try writer.print("{s}:{X},", .{ entry.name, entry.value.* });
            },
        }
    }

    try writer.writeAll("],");

    const written = try allocator.dupe(u8, stream.getWritten());

    return written;
}

pub fn write(allocator: std.mem.Allocator, node: Node) !void {
    const string = try stringify(allocator, node);
    defer allocator.free(string);

    const file = try get_storage_file(allocator, .write);
    defer file.close();

    try file.writeAll(string);
}

pub fn read(allocator: std.mem.Allocator) !Node {
    const file = try get_storage_file(allocator, .read);
    defer file.close();

    const file_size = try file.getEndPos();
    const buf = try allocator.alloc(u8, file_size);
    defer allocator.free(buf);

    _ = try file.readAll(buf);

    var parser = try p.Parser.parse(allocator, buf);
    defer parser.deinit_no_tree();

    return parser.tree;
}

fn get_storage_file(allocator: std.mem.Allocator, comptime mode: enum { read, write }) !std.fs.File {
    const home_path = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home_path);

    const path = try std.fs.path.join(allocator, &[_][]const u8{ home_path, "/.local/share/void/" });
    defer allocator.free(path);

    std.fs.makeDirAbsolute(path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    const file_path = try std.fs.path.join(allocator, &[_][]const u8{ path, "portals.glass" });
    defer allocator.free(file_path);

    return switch (mode) {
        .read => try std.fs.openFileAbsolute(file_path, .{}),
        .write => try std.fs.openFileAbsolute(file_path, .{ .mode = .write_only }),
    };
}
