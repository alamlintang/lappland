// Copyright 2020 Alam Lintang <alamlintang@protonmail.ch>
// SPDX-License-Identifier: MIT
const std = @import("std");
const ArrayList = std.ArrayList;
const SemanticVersion = std.SemanticVersion;
const Target = std.Target;
const debug = std.debug;
const fmt = std.fmt;
const fs = std.fs;
const heap = std.heap;
const io = std.io;
const math = std.math;
const mem = std.mem;
const process = std.process;
const unicode = std.unicode;

const clap = @import("thirdparty/zig-clap");

const algorithm = @import("algorithm.zig");

pub fn main() !void {
    const allocator = heap.page_allocator;

    const stderr = io.getStdErr();
    const stdout = io.getStdOut();

    const param = parseParam(allocator) catch |err| switch (err) {
        error.Help => return printHelp(stdout.writer()),
        error.Version => return printVersion(),
        else => {
            if (err == error.NotEnoughParams) printHelp(stderr.writer());
            return err;
        },
    };

    defer allocator.free(param.user_name);
    defer allocator.free(param.site_name);

    const password = try readPasswordFromStdin(allocator);
    defer allocator.free(password);

    const result = try algorithm.generateDiceware(
        allocator,
        param.user_name,
        param.site_name,
        param.counter,
        param.word_count,
        password,
    );

    defer allocator.free(result);

    stdout.writer().print("{}", .{result}) catch return;
    if (stdout.isTty()) stdout.writer().print("\n", .{}) catch return;
}

const Param = struct {
    allocator: *mem.Allocator,
    user_name: []u8,
    site_name: []u8,
    counter: u8 = 1,
    word_count: u4 = 6,
};

fn parseEnvVar(allocator: *mem.Allocator, param: *Param) !void {
    const is_windows = Target.current.os.tag == .windows;

    const counter = process.getEnvVarOwned(allocator, "LAPPLAND_COUNTER") catch |err| switch (err) {
        error.OutOfMemory, error.EnvironmentVariableNotFound => null,
        error.InvalidUtf8 => if (is_windows) null else unreachable,
    };

    const words = process.getEnvVarOwned(allocator, "LAPPLAND_WORD_COUNT") catch |err| switch (err) {
        error.OutOfMemory, error.EnvironmentVariableNotFound => null,
        error.InvalidUtf8 => if (is_windows) null else unreachable,
    };

    defer if (counter) |c| allocator.free(c);
    defer if (words) |w| allocator.free(w);

    if (counter) |c| param.*.counter = try fmt.parseUnsigned(@TypeOf(param.*.counter), c, 10);
    if (words) |w| param.*.word_count = try fmt.parseUnsigned(@TypeOf(param.*.word_count), w, 10);
}

fn parseParam(allocator: *mem.Allocator) !Param {
    var param = Param{
        .allocator = allocator,
        .user_name = undefined,
        .site_name = undefined,
    };

    try parseEnvVar(allocator, &param);

    var array_list = blk: {
        var self = ArrayList([]const u8).init(allocator);

        const new_memory = try self.allocator.allocAdvanced([]const u8, null, 2, .exact);
        self.items.ptr = new_memory.ptr;
        self.capacity = new_memory.len;

        break :blk self;
    };

    defer array_list.deinit();

    const flags = comptime [_]clap.Param(u8){
        clap.Param(u8){
            .id = 'c',
            .names = .{ .short = 'c', .long = "counter" },
            .takes_value = .One,
        },
        clap.Param(u8){
            .id = 'w',
            .names = .{ .short = 'w', .long = "words" },
            .takes_value = .One,
        },
        clap.Param(u8){
            .id = 'h',
            .names = .{ .short = 'h', .long = "help" },
        },
        clap.Param(u8){
            .id = 255,
            .names = .{ .long = "version" },
        },
        clap.Param(u8){
            .id = 0,
            .takes_value = .One,
        },
    };

    const is_windows = Target.current.os.tag == .windows;

    var iter = clap.args.OsIterator.init(allocator) catch |err| if (is_windows) return err else unreachable;
    defer iter.deinit();

    var parser = clap.StreamingClap(@TypeOf(flags[0].id), clap.args.OsIterator){
        .params = &flags,
        .iter = &iter,
    };

    while (parser.next(null) catch |err| switch (err) {
        error.OutOfMemory => if (is_windows) return err else unreachable,
        else => return err,
    }) |arg| {
        switch (arg.param.id) {
            'c' => param.counter = try fmt.parseUnsigned(@TypeOf(param.counter), arg.value.?, 10),
            'w' => param.word_count = try fmt.parseUnsigned(@TypeOf(param.word_count), arg.value.?, 10),
            'h' => return error.Help,
            255 => return error.Version,
            0 => {
                parser.state = .rest_are_positional;
                if (array_list.items.len < 2) array_list.appendAssumeCapacity(arg.value.?);
            },
            else => unreachable,
        }
    }

    if (array_list.items.len < 2) return error.NotEnoughParams;
    if (param.counter == 0) return error.InvalidValue;

    if (param.word_count < 5)
        return error.WordsTooFew
    else if (param.word_count > 10)
        return error.WordsTooMany;

    for (array_list.items) |item|
        if (!unicode.utf8ValidateSlice(item))
            return error.InvalidUtf8;

    param.user_name = try param.allocator.dupe(u8, array_list.items[0]);
    errdefer param.allocator.free(param.user_name);
    param.site_name = try param.allocator.dupe(u8, array_list.items[1]);

    return param;
}

fn printHelp(writer: fs.File.Writer) void {
    const usage =
        \\Usage: lapp [options] <username> <sitename>
        \\
        \\Options:
        \\  -c, --counter <value>  Set the counter value (default: 0)
        \\  -w, --words <value>    Set how many words will be generated
        \\                         (default: 6, min: 5, max: 10)
        \\  -h, --help             Print this help and exit
        \\      --version          Print version number and exit
        \\
        \\Password is read from the standard input.
    ;

    writer.print("{}\n", .{usage}) catch return;
}

fn printVersion() void {
    @setCold(true);
    const stdout = io.getStdOut().writer();

    const version = SemanticVersion{
        .major = 0,
        .minor = 1,
        .patch = 0,
    };

    stdout.print("lappland version ", .{}) catch return;
    version.format("", .{}, stdout) catch return;
    stdout.print("\n", .{}) catch return;
}

fn readPasswordFromStdin(allocator: *mem.Allocator) ![]u8 {
    const file_size = @typeInfo(fs.File.Stat).Struct.fields[1];
    comptime debug.assert(mem.eql(u8, file_size.name, "size"));
    comptime debug.assert(file_size.field_type == u64);

    const stdin = io.getStdIn().reader();
    return stdin.readAllAlloc(allocator, math.maxInt(file_size.field_type));
}
