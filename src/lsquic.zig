// Re-export the C types for convenience
pub const lsquic_conn_t = c.lsquic_conn_t;
pub const ConnectionContext = c.lsquic_conn_ctx_t;
pub const lsquic_stream_t = c.lsquic_stream_t;
pub const lsquic_cid_t = c.lsquic_cid_t;
pub const out_spec = c.lsquic_out_spec;
pub const struct_sockaddr = c.struct_sockaddr;
pub const iovec = c.struct_iovec;

pub const GlobalInitFlags = struct {
    pub const CLIENT = c.LSQUIC_GLOBAL_CLIENT;
    pub const SERVER = c.LSQUIC_GLOBAL_SERVER;
};

pub const Error = error{
    GlobalInitFailed,
    EngineCreationFailed,
    InvalidParameter,
    OutOfMemory,
};

pub fn globalInit(flags: c_int) Error!void {
    const result = c.lsquic_global_init(flags);
    if (result != 0) {
        return Error.GlobalInitFailed;
    }
}

pub fn globalCleanup() void {
    c.lsquic_global_cleanup();
}

pub const OnNewConnFn = ?*const fn (?*anyopaque, ?*lsquic_conn_t) callconv(.c) ?*ConnectionContext;
pub const OnGoawayReceivedFn = ?*const fn (?*lsquic_conn_t) callconv(.c) void;
pub const OnConnClosedFn = ?*const fn (?*lsquic_conn_t) callconv(.c) void;
pub const OnNewStreamFn = ?*const fn (?*anyopaque, ?*lsquic_stream_t) callconv(.c) ?*c.lsquic_stream_ctx_t;
pub const OnReadFn = ?*const fn (?*lsquic_stream_t, ?*c.lsquic_stream_ctx_t) callconv(.c) void;
pub const OnWriteFn = ?*const fn (?*lsquic_stream_t, ?*c.lsquic_stream_ctx_t) callconv(.c) void;
pub const OnCloseFn = ?*const fn (?*lsquic_stream_t, ?*c.lsquic_stream_ctx_t) callconv(.c) void;
pub const OnDgWriteFn = ?*const fn (?*lsquic_conn_t, ?*anyopaque, usize) callconv(.c) isize;
pub const OnDatagramFn = ?*const fn (?*lsquic_conn_t, ?*const anyopaque, usize) callconv(.c) void;
pub const OnHskDoneFn = ?*const fn (?*lsquic_conn_t, c.lsquic_hsk_status) callconv(.c) void;
pub const OnNewTokenFn = ?*const fn (?*lsquic_conn_t, [*c]const u8, usize) callconv(.c) void;
pub const OnSessResumeInfoFn = ?*const fn (?*lsquic_conn_t, [*c]const u8, usize) callconv(.c) void;
pub const OnResetFn = ?*const fn (?*lsquic_stream_t, ?*c.lsquic_stream_ctx_t, c_int) callconv(.c) void;
pub const OnConnCloseFrameReceivedFn = ?*const fn (?*lsquic_conn_t, c_int, u64, [*c]const u8, c_int) callconv(.c) void;

/// Connection wrapper
pub const Connection = opaque {
    pub fn getId(self: *const Connection) *const lsquic_cid_t {
        const conn_ptr: *const c.lsquic_conn_t = @ptrCast(self);
        return c.lsquic_conn_id(conn_ptr);
    }

    pub fn getEngine(self: *Connection) *Engine {
        const conn_ptr: *c.lsquic_conn_t = @ptrCast(self);
        return @ptrCast(c.lsquic_conn_get_engine(conn_ptr));
    }
};

/// Stream wrapper
pub const Stream = opaque {
    /// Get the connection this stream belongs to
    pub fn getConnection(self: *const Stream) *Connection {
        const stream_ptr: *const c.lsquic_stream_t = @ptrCast(self);
        return @ptrCast(c.lsquic_stream_conn(stream_ptr));
    }
};

test "lsquic global init and cleanup" {
    // Initialize for both client and server
    try globalInit(GlobalInitFlags.CLIENT | GlobalInitFlags.SERVER);
    globalCleanup();

    try globalInit(GlobalInitFlags.CLIENT);
    globalCleanup();

    try globalInit(GlobalInitFlags.SERVER);
    globalCleanup();
}

const std = @import("std");
const testing = std.testing;

const Engine = engine.Engine;
pub const engine = @import("engine.zig");

const c = @cImport({
    @cInclude("lsquic.h");
    @cInclude("lsquic_types.h");
    @cInclude("lsxpack_header.h");
});
