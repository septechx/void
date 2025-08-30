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

    const curses = Curses.init();
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

    tree.printTreeString(curses);

    while (next_char(curses)) |ch| {
        switch (ch) {
            'e' => {
                try curses.print("New file\n", .{});
            },
            else => {},
        }

        curses.refresh();
    }
}

fn next_char(curses: Curses) ?u16 {
    const ch = curses.get_char();
    if (ch == 27 or ch == 'q') {
        return null;
    } else {
        return ch;
    }
}
