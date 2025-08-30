const std = @import("std");
const Curses = @import("Curses.zig");

pub const Entry = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    value: u64,

    pub fn printTreeString(self: Entry, curses: *Curses) void {
        curses.print("{s}: {d}\n", .{ self.name, self.value }) catch @panic("Failed to print entry");
    }
};

pub const Unit = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    children: ?[]const Node,

    pub fn printTreeString(self: Unit, curses: *Curses) void {
        curses.attr_on(Curses.c.COLOR_PAIR(1));
        curses.attr_on(Curses.c.A_BOLD);
        curses.print(" {s}\n", .{self.name}) catch @panic("Failed to print unit");
        curses.attr_off(Curses.c.A_BOLD);
        curses.attr_off(Curses.c.COLOR_PAIR(1));

        if (self.children) |children| {
            for (children, 0..) |child, i| {
                if (i == children.len - 1) {
                    curses.print("└── ", .{}) catch @panic("Failed to print indent");
                } else {
                    curses.print("├── ", .{}) catch @panic("Failed to print indent");
                }

                child.printTreeString(curses);
            }
        }
    }
};

pub const Node = union(enum) {
    Entry: Entry,
    Unit: Unit,

    pub fn printTreeString(self: Node, curses: *Curses) void {
        switch (self) {
            .Entry => |entry| entry.printTreeString(curses),
            .Unit => |unit| unit.printTreeString(curses),
        }
    }
};
