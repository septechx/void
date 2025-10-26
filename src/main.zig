const std = @import("std");
const Curses = @import("Curses.zig");
const storage = @import("storage.zig");
const parser = @import("parser.zig");
const library = @import("library.zig");
const Entry = library.Entry;
const Unit = library.Unit;
const Node = library.Node;

pub fn main() !void {
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

                const y = curses.get_y();

                var current_children = if (library.findNodeByY(&tree, y)) |node|
                    switch (node.*) {
                        .Unit => |*unit| &unit.children,
                        .Entry => if (library.findParent(&tree, node)) |p| &p.parent.children else &tree.Unit.children,
                    }
                else
                    &tree.Unit.children;

                var parts = std.mem.splitScalar(u8, name_dialog.value, ':');

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
                const y = curses.get_y();

                if (library.findNodeByY(&tree, y)) |node_to_delete| {
                    if (library.findParent(&tree, node_to_delete)) |result| {
                        var node = result.parent.children.orderedRemove(result.index);
                        node.deinit();

                        try reload(allocator, &curses, &tree);
                    } else {
                        Curses.Toast.init(3, 50, "Cannot delete root node");
                    }
                }
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
    const ch = curses.next_char();
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
