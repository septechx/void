const std = @import("std");
const Curses = @import("Curses.zig");
const storage = @import("storage.zig");
const parser = @import("parser.zig");
const library = @import("library.zig");
const Entry = library.Entry;
const Unit = library.Unit;
const Node = library.Node;

pub fn main() !void {
    // var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    // defer arena.deinit();
    // const allocator = arena.allocator();
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var curses = Curses.init();
    defer curses.deinit();

    var tree = try storage.read(allocator);
    defer tree.deinit();

    library.printTree(&curses, tree);

    curses.move(0, 0);

    while (next_char(&curses)) |ch| {
        switch (ch) {
            'j', Curses.c.KEY_DOWN => {
                const y = curses.get_y();
                const x = curses.get_x();

                curses.move(y + 1, x);

                curses.refresh();
            },

            'k', Curses.c.KEY_UP => {
                const y = curses.get_y();
                const x = curses.get_x();

                curses.move(y - 1, x);

                curses.refresh();
            },

            'a' => {
                var name_dialog = Curses.Dialog.init(allocator, 8, 48, "Name: ", struct {
                    pub fn validate(value: []const u8) bool {
                        return value.len > 0;
                    }
                }.validate);
                defer name_dialog.deinit();

                var value_dialog = Curses.Dialog.init(allocator, 8, 48, "Portal Address: ", struct {
                    pub fn validate(value: []const u8) bool {
                        return value.len == 16;
                    }
                }.validate);
                defer value_dialog.deinit();

                const value = try std.fmt.parseUnsigned(u64, value_dialog.value, 16);

                var parts = std.mem.splitScalar(u8, name_dialog.value, ':');

                var current_children = &tree.Unit.children;
                blk: while (parts.next()) |part| {
                    const is_last = parts.peek() == null;

                    if (is_last) {
                        try current_children.append(.{
                            .Entry = try Entry.init(allocator, part, value),
                        });
                    } else {
                        for (current_children.items) |*child| {
                            switch (child.*) {
                                .Unit => {},
                                else => continue,
                            }

                            if (std.mem.eql(u8, child.Unit.name, part)) {
                                current_children = &child.Unit.children;
                                continue :blk;
                            }
                        }

                        try current_children.append(.{
                            .Unit = try Unit.init(allocator, part),
                        });
                        current_children = &current_children.items[current_children.items.len - 1].Unit.children;
                    }
                }

                try reload(allocator, &curses, &tree);
            },

            'd' => {
                var name_dialog = Curses.Dialog.init(allocator, 8, 48, "Name: ", struct {
                    pub fn validate(value: []const u8) bool {
                        return value.len > 0;
                    }
                }.validate);
                defer name_dialog.deinit();

                var parts = std.mem.splitScalar(u8, name_dialog.value, ':');

                var current_children = &tree.Unit.children;
                blk: while (parts.next()) |part| {
                    const is_last = parts.peek() == null;

                    if (is_last) {
                        for (current_children.items, 0..) |*child, i| {
                            switch (child.*) {
                                .Unit => {
                                    if (std.mem.eql(u8, child.Unit.name, part)) {
                                        var node = current_children.orderedRemove(i);
                                        node.Unit.deinit();
                                    }
                                },
                                .Entry => {
                                    if (std.mem.eql(u8, child.Entry.name, part)) {
                                        var node = current_children.orderedRemove(i);
                                        node.Entry.deinit();
                                    }
                                },
                            }
                        }
                    } else {
                        for (current_children.items) |*child| {
                            switch (child.*) {
                                .Unit => {},
                                else => continue,
                            }

                            if (std.mem.eql(u8, child.Unit.name, part)) {
                                current_children = &child.Unit.children;
                                continue :blk;
                            }
                        }
                    }
                }

                try reload(allocator, &curses, &tree);
            },

            else => {},
        }
    }
}

fn reload(allocator: std.mem.Allocator, curses: *Curses, tree: *Node) !void {
    curses.clear();
    curses.refresh();

    library.printTree(curses, tree.*);

    const y = curses.get_y();
    curses.move(y, 0);

    try storage.write(allocator, tree.*);
}

fn next_char(curses: *Curses) ?u16 {
    const ch = curses.get_char();
    if (ch == 27 or ch == 'q') {
        return null;
    } else {
        return ch;
    }
}

test {
    _ = parser;
    std.testing.refAllDecls(@This());
}
