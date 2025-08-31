const std = @import("std");
const Curses = @import("Curses.zig");
const library = @import("library.zig");
const Entry = library.Entry;
const Unit = library.Unit;
const Node = library.Node;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var curses = Curses.init();
    defer curses.deinit();

    var tree = Node{
        .Unit = try Unit.init(allocator, "root"),
    };
    defer tree.deinit();

    try tree.Unit.children.append(.{
        .Entry = try Entry.init(allocator, "a", 1),
    });
    try tree.Unit.children.append(.{
        .Entry = try Entry.init(allocator, "b", 2),
    });

    library.printTree(&curses, tree);

    curses.move(0, 0);

    while (next_char(&curses)) |ch| {
        switch (ch) {
            'j', Curses.c.KEY_DOWN => {
                const y = curses.get_y();
                const x = curses.get_x();

                curses.move(y + 1, x);
            },
            'k', Curses.c.KEY_UP => {
                const y = curses.get_y();
                const x = curses.get_x();

                curses.move(y - 1, x);
            },
            'a' => {
                var name_dialog = Curses.Dialog.init(allocator, 7, 45, "Name: ");
                defer name_dialog.deinit();

                var value_dialog = Curses.Dialog.init(allocator, 7, 45, "Portal Address: ");
                defer value_dialog.deinit();

                const value = try std.fmt.parseUnsigned(u64, value_dialog.value, 16);

                var parts = std.mem.splitScalar(u8, name_dialog.value, ':');

                var current_children = &tree.Unit.children;
                while (parts.next()) |part| {
                    const is_last = parts.peek() == null;

                    if (is_last) {
                        try current_children.append(.{
                            .Entry = try Entry.init(allocator, part, value),
                        });
                    } else {
                        try current_children.append(.{
                            .Unit = try Unit.init(allocator, part),
                        });
                        current_children = &current_children.items[current_children.items.len - 1].Unit.children;
                    }
                }

                curses.clear();
                curses.refresh();

                library.printTree(&curses, tree);

                const y = curses.get_y();
                curses.move(y, 0);
            },
            else => {},
        }

        curses.refresh();
    }
}

fn next_char(curses: *Curses) ?u16 {
    const ch = curses.get_char();
    if (ch == 27 or ch == 'q') {
        return null;
    } else {
        return ch;
    }
}
