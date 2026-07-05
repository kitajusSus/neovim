const std = @import("std");
const c = @import("c");

export fn mb_utf_index_to_bytes(s: [*c]const u8, len: usize, index: usize, use_utf16_units: bool) callconv(.c) isize {
    if (index == 0) return 0;

    const slice = s[0..len];
    var i: usize = 0;
    var count: usize = 0;

    // Fast path: Process 8 ASCII bytes at a time using 64-bit word operations.
    // ASCII characters (bytes < 0x80) represent exactly 1 codepoint and 1 UTF-16 code unit.
    while (i + 8 <= len and count + 8 <= index) {
        const word = @as(*const align(1) u64, @ptrCast(slice[i..i+8].ptr)).*;
        if ((word & 0x8080808080808080) != 0) {
            break;
        }
        i += 8;
        count += 8;
    }

    // Process remaining bytes
    while (i < len) {
        if (count >= index) {
            return @intCast(i);
        }

        const lead_byte = slice[i];
        var clen: usize = 1;
        var codepoint: u32 = lead_byte;

        if (lead_byte < 0x80) {
            clen = 1;
        } else if ((lead_byte & 0xE0) == 0xC0) {
            clen = 2;
            if (i + 2 <= len) {
                const b1 = slice[i+1];
                if ((b1 & 0xC0) == 0x80) {
                    codepoint = (@as(u32, lead_byte & 0x1F) << 6) | (b1 & 0x3F);
                } else {
                    clen = @intCast(c.utf_ptr2len_len(s + i, @intCast(len - i)));
                    codepoint = if (clen > 1) @intCast(c.utf_ptr2char(s + i)) else lead_byte;
                }
            } else {
                clen = @intCast(c.utf_ptr2len_len(s + i, @intCast(len - i)));
                codepoint = if (clen > 1) @intCast(c.utf_ptr2char(s + i)) else lead_byte;
            }
        } else if ((lead_byte & 0xF0) == 0xE0) {
            clen = 3;
            if (i + 3 <= len) {
                const b1 = slice[i+1];
                const b2 = slice[i+2];
                if ((b1 & 0xC0) == 0x80 and (b2 & 0xC0) == 0x80) {
                    codepoint = (@as(u32, lead_byte & 0x0F) << 12) | (@as(u32, b1 & 0x3F) << 6) | (b2 & 0x3F);
                } else {
                    clen = @intCast(c.utf_ptr2len_len(s + i, @intCast(len - i)));
                    codepoint = if (clen > 1) @intCast(c.utf_ptr2char(s + i)) else lead_byte;
                }
            } else {
                clen = @intCast(c.utf_ptr2len_len(s + i, @intCast(len - i)));
                codepoint = if (clen > 1) @intCast(c.utf_ptr2char(s + i)) else lead_byte;
            }
        } else if ((lead_byte & 0xF8) == 0xF0) {
            clen = 4;
            if (i + 4 <= len) {
                const b1 = slice[i+1];
                const b2 = slice[i+2];
                const b3 = slice[i+3];
                if ((b1 & 0xC0) == 0x80 and (b2 & 0xC0) == 0x80 and (b3 & 0xC0) == 0x80) {
                    codepoint = (@as(u32, lead_byte & 0x07) << 18) | (@as(u32, b1 & 0x3F) << 12) | (@as(u32, b2 & 0x3F) << 6) | (b3 & 0x3F);
                } else {
                    clen = @intCast(c.utf_ptr2len_len(s + i, @intCast(len - i)));
                    codepoint = if (clen > 1) @intCast(c.utf_ptr2char(s + i)) else lead_byte;
                }
            } else {
                clen = @intCast(c.utf_ptr2len_len(s + i, @intCast(len - i)));
                codepoint = if (clen > 1) @intCast(c.utf_ptr2char(s + i)) else lead_byte;
            }
        } else {
            clen = @intCast(c.utf_ptr2len_len(s + i, @intCast(len - i)));
            codepoint = if (clen > 1) @intCast(c.utf_ptr2char(s + i)) else lead_byte;
        }

        i += clen;
        count += 1;
        if (use_utf16_units and codepoint > 0xFFFF) {
            count += 1;
        }
    }

    if (count >= index) {
        return @intCast(i);
    }
    return -1;
}
