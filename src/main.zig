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

    var children = std.ArrayList(Node).init(allocator);
    children.append(.{
        .Entry = .{
            .allocator = allocator,
            .name = "a",
            .value = 1,
        },
    }) catch @panic("Failed to append child");
    children.append(.{
        .Entry = .{
            .allocator = allocator,
            .name = "b",
            .value = 2,
        },
    }) catch @panic("Failed to append child");

    var tree = Node{
        .Unit = .{
            .allocator = allocator,
            .name = "root",
            .children = children,
        },
    };

    tree.printTreeString(&curses);

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

                const value = std.fmt.parseUnsigned(u64, value_dialog.value, 16) catch @panic("Failed to parse portal address");

                try tree.Unit.children.?.append(.{
                    .Entry = .{
                        .allocator = allocator,
                        .name = name_dialog.value,
                        .value = value,
                    },
                });

                curses.clear();
                curses.refresh();

                tree.printTreeString(&curses);

                const y = curses.get_y();
                curses.move(y, 0);
            },
            else => {
                std.debug.panic("ch: {d}\n", .{ch});
            },
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
