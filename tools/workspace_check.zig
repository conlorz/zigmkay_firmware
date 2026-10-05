//! Check mise's resolved package graph against files and the board catalog.
const std = @import("std");
const source_files = @import("source-files");
const Task = struct { name: []const u8, source: []const u8, depends: []const []const u8 };
fn excluded(_: []const u8, name: []const u8, kind: std.Io.File.Kind) bool {
    return kind == .directory and (std.mem.eql(u8, name, ".git") or std.mem.eql(u8, name, ".zig-cache") or std.mem.eql(u8, name, "zig-out") or std.mem.eql(u8, name, "zig-pkg"));
}
fn included(path: []const u8, kind: std.Io.File.Kind) bool {
    return kind == .file and std.mem.eql(u8, std.fs.path.basename(path), "mise.toml");
}
fn find(tasks: []const Task, name: []const u8) !Task {
    for (tasks) |task| if (std.mem.eql(u8, task.name, name)) return task;
    std.log.err("Missing mise task: {s}", .{name});
    return error.MissingWorkspaceTask;
}
fn contains(names: []const []const u8, name: []const u8) bool {
    for (names) |candidate| if (std.mem.eql(u8, name, candidate)) return true;
    return false;
}
fn verifyAggregates(tasks: []const Task) !void {
    const tests = try find(tasks, "//:test");
    const generated = try find(tasks, "//:check-generated");
    for (tasks) |task| {
        if (std.mem.startsWith(u8, task.name, "//:")) continue;
        const aggregate = if (std.mem.endsWith(u8, task.name, ":test") or std.mem.endsWith(u8, task.name, ":usb-test")) tests else if (std.mem.endsWith(u8, task.name, ":check-generated")) generated else continue;
        if (!contains(aggregate.depends, task.name)) {
            std.debug.print("{s} is missing from {s}\n", .{ task.name, aggregate.name });
            return error.MissingAggregateCoverage;
        }
    }
    for ([_][]const u8{ "//:test", "//:check-generated", "//:build-all", "//:gui-acceptance" }) |name| {
        const aggregate = try find(tasks, name);
        for (aggregate.depends) |dependency| _ = try find(tasks, dependency);
    }
}
fn run(gpa: std.mem.Allocator, io: std.Io, root: []const u8, argv: []const []const u8) !std.process.RunResult {
    const result = try std.process.run(gpa, io, .{
        .argv = argv,
        .cwd = .{ .path = root },
        .timeout = .{ .duration = .{ .raw = .fromSeconds(30), .clock = .awake } },
        .stdout_limit = .limited(4 * 1024 * 1024),
    });
    if (result.term != .exited or result.term.exited != 0) {
        std.log.err("Mise discovery failed: {s}", .{result.stderr});
        gpa.free(result.stdout);
        gpa.free(result.stderr);
        return error.MiseDiscoveryFailed;
    }
    return result;
}
pub fn check(gpa: std.mem.Allocator, io: std.Io, root_path: []const u8) !void {
    const listing = try run(gpa, io, root_path, &.{ "mise", "tasks", "ls", "--all", "--json" });
    defer gpa.free(listing.stdout);
    defer gpa.free(listing.stderr);
    const RawTask = struct { name: []const u8, source: []const u8, depends: []const std.json.Value };
    const parsed = try std.json.parseFromSlice([]RawTask, gpa, listing.stdout, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const tasks = try arena.allocator().alloc(Task, parsed.value.len);
    for (parsed.value, tasks) |raw, *task| {
        const dependencies = try arena.allocator().alloc([]const u8, raw.depends.len);
        for (raw.depends, dependencies) |dependency, *name| name.* = switch (dependency) {
            .string => |value| value,
            .array => |value| if (value.items.len > 0 and value.items[0] == .string) value.items[0].string else return error.InvalidTaskDependency,
            else => return error.InvalidTaskDependency,
        };
        task.* = .{ .name = raw.name, .source = raw.source, .depends = dependencies };
    }
    try verifyAggregates(tasks);
    var root = try std.Io.Dir.cwd().openDir(io, root_path, .{ .iterate = true });
    defer root.close(io);
    const absolute = try std.Io.Dir.cwd().realPathFileAlloc(io, root_path, gpa);
    defer gpa.free(absolute);
    const configs = try source_files.collect(gpa, io, root, .{ .excluded = excluded, .included = included });
    defer source_files.free(gpa, configs);
    const tests = try find(tasks, "//:test");
    const builds = try find(tasks, "//:build-all");
    for (configs) |config| {
        if (std.mem.eql(u8, config.path, "mise.toml")) continue;
        const package = std.fs.path.dirname(config.path).?;
        const prefix = try std.fmt.allocPrint(gpa, "//{s}:", .{package});
        defer gpa.free(prefix);
        const expected_source = try std.fs.path.join(gpa, &.{ absolute, config.path });
        defer gpa.free(expected_source);
        var discovered = false;
        var covered = false;
        for (tasks) |task| if (std.mem.startsWith(u8, task.name, prefix)) {
            if (!std.mem.eql(u8, task.source, expected_source)) return error.WrongPackageConfiguration;
            discovered = true;
            covered = covered or contains(tests.depends, task.name) or contains(builds.depends, task.name);
        };
        if (!discovered or !covered) {
            std.log.err("Package {s}: discovered={}, aggregate coverage={}", .{ package, discovered, covered });
            return error.MissingPackageCoverage;
        }
    }
    const Info = struct { usage_spec: struct { cmd: struct { args: []const struct { choices: struct { choices: []const []const u8 } } } } };
    inline for (.{ "//:firmware", "//keyboards:firmware", "//:flash" }) |name| {
        const result = try run(gpa, io, root_path, &.{ "mise", "tasks", "info", name, "--json" });
        defer gpa.free(result.stdout);
        defer gpa.free(result.stderr);
        const info = try std.json.parseFromSlice(Info, gpa, result.stdout, .{ .ignore_unknown_fields = true });
        defer info.deinit();
        if (info.value.usage_spec.cmd.args.len != 1) return error.InvalidBoardArguments;
        const choices = info.value.usage_spec.cmd.args[0].choices.choices;
        const catalog = @import("board-catalog");
        if (choices.len != catalog.len) return error.BoardCompletionDrift;
        inline for (catalog) |board| if (!contains(choices, board.name)) return error.BoardCompletionDrift;
    }
    std.debug.print("Mise package discovery, aggregate coverage and board choices match the workspace\n", .{});
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.Usage;
    try check(init.arena.allocator(), init.io, args[1]);
}

test "new package tests and generated checks require aggregate coverage" {
    const tasks = [_]Task{
        .{ .name = "//:test", .source = "", .depends = &.{"//old:test"} },
        .{ .name = "//:check-generated", .source = "", .depends = &.{} },
        .{ .name = "//:build-all", .source = "", .depends = &.{} },
        .{ .name = "//:gui-acceptance", .source = "", .depends = &.{} },
        .{ .name = "//old:test", .source = "", .depends = &.{} },
        .{ .name = "//new:test", .source = "", .depends = &.{} },
    };
    try std.testing.expectError(error.MissingAggregateCoverage, verifyAggregates(&tasks));
    var generated = tasks;
    generated[5].name = "//new:check-generated";
    try std.testing.expectError(error.MissingAggregateCoverage, verifyAggregates(&generated));
    try verifyAggregates(tasks[0..5]);
}
