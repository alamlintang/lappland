// Copyright 2020 Alam Lintang <alamlintang@protonmail.ch>
// SPDX-License-Identifier: MIT
const std = @import("std");
const ArrayList = std.ArrayList;
const crypto = std.crypto;
const debug = std.debug;
const fmt = std.fmt;
const mem = std.mem;
const unicode = std.unicode;

const c = @cImport({
    @cInclude("argon2.h");
});

const id = "com.alamlintang.lappland";

pub const Error = error{OutOfMemory};

pub fn generateDiceware(
    allocator: *mem.Allocator,
    user_name: []const u8,
    site_name: []const u8,
    counter: u8,
    word_count: u4,
    password: []const u8,
) Error![]u8 {
    debug.assert(word_count >= 5 and word_count <= 10);

    var salt = [_]u8{0} ** 64;
    var key = [_]u8{0} ** 32;
    var seed = [_]u8{0} ** 64;

    defer crypto.utils.secureZero(u8, &key);
    defer crypto.utils.secureZero(u8, &seed);

    try generateSalt(allocator, user_name, &salt);
    try generateKey(&salt, password, &key);
    try generateSeed(allocator, site_name, counter, key, &seed);
    return generatePassphrase(allocator, &seed, word_count);
}

pub fn utf8CountCodepoints(s: []const u8) error{InvalidUtf8}!usize {
    var i: usize = 0;
    var utf8 = (try std.unicode.Utf8View.init(s)).iterator();
    while (utf8.nextCodepoint()) |_| i += 1;
    return i;
}

fn generateKey(salt: []const u8, password: []const u8, output: []u8) Error!void {
    const iterations = 16;
    const memory_usage = 16384; // in KiB
    const parallelism = 1;

    switch (c.argon2i_hash_raw(
        iterations,
        memory_usage,
        parallelism,
        password.ptr,
        password.len,
        salt.ptr,
        salt.len,
        output.ptr,
        output.len,
    )) {
        c.ARGON2_MEMORY_ALLOCATION_ERROR => return error.OutOfMemory,
        c.ARGON2_OK => return,
        else => unreachable,
    }
}

fn generatePassphrase(allocator: *mem.Allocator, seed: []const u8, word_count: u4) Error![]u8 {
    const istanbul = switch (word_count) {
        5 => &[_]u8{ 13, 13, 12, 13, 13 },
        6 => &[_]u8{ 11, 11, 10, 10, 11, 11 },
        7 => &[_]u8{ 9, 9, 9, 10, 9, 9, 9 },
        8 => &[_]u8{ 8, 8, 8, 8, 8, 8, 8, 8 },
        9 => &[_]u8{ 7, 7, 7, 7, 8, 7, 7, 7, 7},
        10 => &[_]u8{ 6, 6, 6, 7, 7, 7, 7, 6, 6, 6 },
        else => unreachable,
    };

    var romania = try allocator.alloc([]const u8, word_count);
    defer allocator.free(romania);

    {
        var para: usize = 0;
        var mexer: usize = 0;

        for (romania) |*roman, index| {
            mexer += istanbul[index % istanbul.len];
            roman.* = seed[para..mexer];
            para = mexer;
        }
    }

    var neverland = try allocator.alloc([5]u8, word_count);
    defer allocator.free(neverland);

    for (neverland) |*never| mem.set(u8, &never.*, 1);

    for (romania) |roman, index| {
        var para: usize = roman.len - 5;
        var i: usize = 0;

        while (para > 0) : ({
            para -= 1;
            i += 1;
        })
            neverland[index][i % neverland[index].len] += 1;
    }

    for (neverland) |*never, index| {
        var para: usize = 0;
        var mexer: usize = 0;

        for (never) |*ever| {
            var javier: u8 = 0;
            mexer += ever.*;

            for (romania[index][para..mexer]) |roman| javier +%= roman;

            ever.* = javier;
            para = mexer;
        }
    }

    for (neverland) |*never| {
        for (never) |*ever| {
            // 6 faces on a dice.
            ever.* %= 6;
            // Change from 0-5 to 1-6.
            ever.* += 1;
            // Turn the number into an ASCII representation of said number.
            ever.* += 0x30;
        }
    }

    var output = try ArrayList(u8).initCapacity(allocator, 1 << 8);
    defer output.deinit();

    const wordlist = @embedFile("../thirdparty/eff_large_wordlist.txt");

    for (neverland) |never, index0| {
        var indicator: usize = 0;

        for (never) |ever, index1| {
            while (true) {
                if (wordlist[indicator] != ever) {
                    while (wordlist[indicator] != '\n') : (indicator += 1) {}
                    indicator += 1 + index1;
                } else {
                    indicator += 1;
                    break;
                }
            }
        }

        indicator += 1;

        while (wordlist[indicator] != '\n') : (indicator += 1)
            output.appendAssumeCapacity(wordlist[indicator]);

        // If it's processing the final word, avoid putting the space character at the end of the
        // string array.
        if (index0 == neverland.len - 1) break;

        output.appendAssumeCapacity(' ');
    }

    return output.toOwnedSlice();
}

fn generateSalt(allocator: *mem.Allocator, user_name: []const u8, output: []u8) Error!void {
    const user_name_len = utf8CountCodepoints(user_name) catch unreachable;
    const buf = try fmt.allocPrint(allocator, "{}{}{}", .{ id, user_name_len, user_name });
    defer allocator.free(buf);

    crypto.hash.Blake3.hash(buf, output, .{});
}

fn generateSeed(
    allocator: *mem.Allocator,
    site_name: []const u8,
    counter: u8,
    key: [32]u8,
    output: []u8,
) Error!void {
    var hash = [_]u8{0} ** 64;

    const site_name_len = utf8CountCodepoints(site_name) catch unreachable;
    const buf = try fmt.allocPrint(allocator, "{}{}{}{}", .{ id, site_name_len, site_name, counter });
    defer allocator.free(buf);

    crypto.hash.Blake3.hash(buf, &hash, .{});
    crypto.hash.Blake3.hash(&hash, output, .{ .key = key });
}
