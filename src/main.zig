const std = @import("std");
const testing = std.testing;
pub const Wolf = @import("wolf.zig");

test {
    testing.refAllDeclsRecursive(@This());
}
