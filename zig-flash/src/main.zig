const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

pub fn main() !void {
    const gpa = std.heap.smp_allocator;
    const cwd = std.fs.cwd();

    var input_path: []const u8 = "zig-out/firmware/firmware.uf2";
    var mount_point_or_label: []const u8 = "RPI-RP2";

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);
    for (args, 0..) |arg, idx| {
        switch (idx) {
            0 => {},
            1 => input_path = arg,
            2 => mount_point_or_label = arg,
            else => help(),
        }
    }

    try cwd.access(input_path, .{}); // input_path must exist!

    const resolved_mount_point: []const u8 = if (std.fs.path.isAbsolute(mount_point_or_label))
        try waitForDriveByAbsolutePath(gpa, mount_point_or_label)
    else
        try waitForDriveByLabel(gpa, mount_point_or_label);
    defer gpa.free(resolved_mount_point);

    const target_path = try std.fs.path.join(gpa, &.{ resolved_mount_point, "firmware.uf2" });
    defer gpa.free(target_path);

    std.log.info("USB drive detected...", .{});
    std.Thread.sleep(500 * std.time.ns_per_ms);

    std.log.info("Copying firmware...", .{});
    try cwd.copyFile(input_path, cwd, target_path, .{});
    std.log.info("Firmware copied to {s}", .{target_path});
}

/// Waits for a drive with the given absolute path to be connected
fn waitForDriveByAbsolutePath(gpa: std.mem.Allocator, mount_point: []const u8) ![]const u8 {
    assert(std.fs.path.isAbsolute(mount_point)); // mount_point must be absolute!
    std.log.info("Waiting for USB drive to appear at {s}...", .{mount_point});
    while (true) {
        std.fs.accessAbsolute(mount_point, .{}) catch {
            std.Thread.sleep(200 * std.time.ns_per_ms);
            continue;
        };
        std.log.info("Found drive: {s}", .{mount_point});
        return gpa.dupe(u8, mount_point);
    }
}

/// Waits for a drive with the given label to be connected, and returns its path
fn waitForDriveByLabel(gpa: std.mem.Allocator, target_label: []const u8) ![]const u8 {
    switch (builtin.os.tag) {
        .windows => {
            std.log.info("Waiting for drive with label '{s}' to be connected...", .{target_label});
            while (true) {
                const ps_cmd = try std.fmt.allocPrint(gpa, "(Get-Volume -FileSystemLabel '{s}' | Select-Object -ExpandProperty DriveLetter) + ':'", .{target_label});
                defer gpa.free(ps_cmd);

                const result = try std.process.Child.run(.{
                    .allocator = gpa,
                    .argv = &[_][]const u8{ "powershell", "-NoProfile", "-Command", ps_cmd },
                });
                defer gpa.free(result.stdout);
                defer gpa.free(result.stderr);

                if (result.term == .Exited and result.term.Exited == 0) {
                    const drive = std.mem.trim(u8, result.stdout, " \r\n");
                    if (drive.len >= 2 and drive[1] == ':') {
                        const final_path = try gpa.dupe(u8, drive[0..2]);

                        std.log.info("Found drive: {s}", .{final_path});
                        return final_path;
                    }
                }
                std.Thread.sleep(200 * std.time.ns_per_ms);
            }
        },
        .macos => {
            const abs_path = try std.fs.path.join(gpa, &.{ "/Volumes", target_label });
            return try waitForDriveByAbsolutePath(gpa, abs_path);
        },
        .linux => {
            const user = std.process.getEnvVarOwned(gpa, "USER") catch |err| {
                std.log.err("Failed to get USER environment variable: {any}\n", .{err});
                return err;
            };
            defer gpa.free(user);
            const abs_path = try std.fs.path.join(gpa, &.{ "/run/media", user, target_label });
            return try waitForDriveByAbsolutePath(gpa, abs_path);
        },
        else => {
            std.log.err("unsupported on operating system {s}", .{builtin.os.tag});
            help();
        },
    }
}

fn help() noreturn {
    std.debug.print(
        \\Usage: zig_flash [input_path] [mount_point]
        \\input_path: Path to the UF2 file to flash (default: zig-out/firmware/firmware.uf2)
        \\mount_point_or_label: Path or label of the USB drive or absolute path (default: "RPI-RP2")
    , .{});
    std.process.exit(0);
}
