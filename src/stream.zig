const std = @import("std");
const testing = std.testing;

const Connection = @import("connection.zig").Connection;

/// Opaque QUIC stream handle. Layout is internal to lsquic and must not be
/// accessed from Zig — use the methods below, all of which delegate to the
/// public lsquic C API.
pub const Stream = opaque {
    /// Get the connection this stream belongs to
    pub fn getConnection(self: *const Stream) *Connection {
        const stream_ptr: *const c.lsquic_stream_t = @ptrCast(self);
        return @ptrCast(c.lsquic_stream_conn(stream_ptr));
    }

    pub fn wantWrite(self: *Stream, is_want: bool) bool {
        return c.lsquic_stream_wantwrite(@ptrCast(self), @intCast(@intFromBool(is_want))) != 0;
    }

    pub fn wantRead(self: *Stream, is_want: bool) bool {
        return c.lsquic_stream_wantread(@ptrCast(self), @intCast(@intFromBool(is_want))) != 0;
    }

    pub fn read(self: *Stream, buf: []u8, buflen: usize) isize {
        return c.lsquic_stream_read(@ptrCast(self), @ptrCast(buf), buflen);
    }

    pub fn write(self: *Stream, buf: []u8, buflen: usize) isize {
        return c.lsquic_stream_write(@ptrCast(@alignCast(self)), @ptrCast(buf), buflen);
    }

    pub fn flush(self: *Stream) c_int {
        return c.lsquic_stream_flush(@ptrCast(@alignCast(self)));
    }

    pub fn close(self: *Stream) bool {
        return c.lsquic_stream_close(@ptrCast(self)) != 0;
    }
};

pub const StreamRaw = Stream;

pub const StreamId = u64;

pub const HskStatus = c.lsquic_hsk_status;

pub const StreamContext = struct {};

pub const ConnectionContext = @import("connection.zig").ConnectionContext;

pub const OnNewConnectionFn = ?*const fn (?*anyopaque, ?*Connection) callconv(.c) ?*ConnectionContext;
pub const OnGoawayReceivedFn = ?*const fn (?*Connection) callconv(.c) void;
pub const OnConnectionClosedFn = ?*const fn (?*Connection) callconv(.c) void;
pub const OnNewStreamFn = ?*const fn (?*anyopaque, ?*StreamRaw) callconv(.c) ?*StreamContext;
pub const OnReadFn = ?*const fn (?*StreamRaw, ?*StreamContext) callconv(.c) void;
pub const OnWriteFn = ?*const fn (?*StreamRaw, ?*StreamContext) callconv(.c) void;
pub const OnCloseFn = ?*const fn (?*StreamRaw, ?*StreamContext) callconv(.c) void;
pub const OnDgWriteFn = ?*const fn (?*Connection, *const anyopaque, usize) callconv(.c) isize;
pub const OnDatagramFn = ?*const fn (?*Connection, *const anyopaque, usize) callconv(.c) void;
pub const OnHskDoneFn = ?*const fn (?*Connection, HskStatus) callconv(.c) void;
pub const OnNewTokenFn = ?*const fn (?*Connection, [*c]const u8, usize) callconv(.c) void;
pub const OnSessResumeInfoFn = ?*const fn (?*Connection, [*c]const u8, usize) callconv(.c) void;
pub const OnResetFn = ?*const fn (?*StreamRaw, ?*StreamContext, c_int) callconv(.c) void;
pub const OnConnectionCloseFrameReceivedFn = ?*const fn (?*Connection, c_int, u64, [*c]const u8, c_int) callconv(.c) void;

/// Zig translation of struct lsquic_stream_if
/// The definitions of callback functions called by lsquic_stream to process events.
pub const StreamIf = extern struct {
    /// Called when a new connection is established.
    /// Use lsquic_conn_get_ctx to get back the context.
    /// It is OK for this function to return null.
    on_new_conn: OnNewConnectionFn = null,

    /// Called when our side received GOAWAY frame. After this,
    /// new streams should not be created. This callback is optional.
    on_goaway_received: OnGoawayReceivedFn = null,

    /// Called when a connection is closed.
    on_conn_closed: OnConnectionClosedFn = null,

    /// Called when a new stream is created.
    /// If you need to initiate a connection, call lsquic_conn_make_stream().
    /// This will cause `on_new_stream' callback to be called when appropriate
    /// (this operation is delayed when maximum number of outgoing streams is reached).
    /// After `on_close' is called, the stream is no longer accessible.
    on_new_stream: OnNewStreamFn = null,

    /// Called when stream data is available for reading.
    on_read: OnReadFn = null,

    /// Called when stream is ready for writing.
    on_write: OnWriteFn = null,

    /// Called when a stream is closed.
    on_close: OnCloseFn = null,

    /// Called when datagram is ready to be written.
    on_dg_write: OnDgWriteFn = null,

    /// Called when datagram is read from a packet. This callback is required
    /// when es_datagrams is true. Take care to process it quickly, as this
    /// is called during lsquic_engine_packet_in().
    on_datagram: OnDatagramFn = null,

    /// Called when handshake is completed. This callback is only called in client mode.
    on_hsk_done: OnHskDoneFn = null,

    /// Called when client receives a token in NEW_TOKEN frame. This callback is optional.
    on_new_token: OnNewTokenFn = null,

    /// This optional callback lets client record information needed to
    /// perform a session resumption next time around.
    /// For IETF QUIC, this is called only if ea_get_ssl_ctx() is *not* set,
    /// in which case the library creates its own SSL_CTX.
    /// Note: this callback will be deprecated when gQUIC support is removed.
    on_sess_resume_info: OnSessResumeInfoFn = null,

    /// Called as soon as the peer resets a stream.
    /// The argument `how' is either 0, 1, or 2, meaning "read", "write", and
    /// "read and write", respectively (just like in shutdown(2)). This
    /// signals the user to stop reading, writing, or both.
    /// Note that resets differ in gQUIC and IETF QUIC. In gQUIC, `how' is
    /// always 2; in IETF QUIC, `how' is either 0 or 1 because one can reset
    /// just one direction in IETF QUIC.
    on_reset: OnResetFn = null,

    /// Called when a CONNECTION_CLOSE frame is received.
    /// This allows the application to log low-level diagnostic information about
    /// errors received with the CONNECTION_CLOSE frame. If app_error is -1 then
    /// it is considered unknown if this is an app_error or not.
    on_conncloseframe_received: OnConnectionCloseFrameReceivedFn = null,
};

test "stream" {}

const c = @cImport({
    @cInclude("lsquic.h");
    @cInclude("lsquic_types.h");
    @cInclude("lsxpack_header.h");
});
