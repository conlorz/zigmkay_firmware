const std = @import("std");
pub fn jobs(gpa: std.mem.Allocator, env: *const std.process.Environ.Map) ![]const u8 {
    const value = env.get("ZIGMKAY_BUILD_JOBS") orelse "4";
    const count = std.fmt.parseInt(u16, value, 10) catch return error.InvalidBuildJobs;
    if (count == 0) return error.InvalidBuildJobs;
    return std.fmt.allocPrint(gpa, "-j{d}", .{count});
}
