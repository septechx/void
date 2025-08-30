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

    const tree = Node{
        .Unit = .{
            .allocator = allocator,
            .name = "root",
            .children = &.{
                Node{
                    .Entry = .{
                        .allocator = allocator,
                        .name = "a",
                        .value = 1,
                    },
                },
                Node{
                    .Entry = .{
                        .allocator = allocator,
                        .name = "b",
                        .value = 2,
                    },
                },
            },
        },
    };

    tree.printTreeString(&curses);

    curses.move(0, 0);

    while (next_char(&curses)) |ch| {
        switch (ch) {
            'j' => {
                const y = curses.get_y();
                const x = curses.get_x();

                curses.move(y + 1, x);
            },
            'k' => {
                const y = curses.get_y();
                const x = curses.get_x();

                curses.move(y - 1, x);
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
