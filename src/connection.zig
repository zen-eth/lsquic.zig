/// Opaque QUIC connection handle.
pub const Connection = opaque {
    pub fn getId(self: *const Connection) *const Cid {
        const conn_ptr: *const c.lsquic_conn_t = @ptrCast(self);
        return c.lsquic_conn_id(conn_ptr);
    }

    pub fn getEngine(self: *Connection) *Engine {
        const conn_ptr: *c.lsquic_conn_t = @ptrCast(self);
        return @ptrCast(c.lsquic_conn_get_engine(conn_ptr));
    }

    pub fn setContext(self: *Connection, context: ?*ConnectionContext) void {
        c.lsquic_conn_set_ctx(@ptrCast(self), context);
    }

    pub fn getContext(self: *Connection) ?*ConnectionContext {
        return @ptrCast(@alignCast(c.lsquic_conn_get_ctx(@ptrCast(self))));
    }

    pub fn makeStream(self: *Connection) void {
        c.lsquic_conn_make_stream(@ptrCast(self));
    }

    pub fn wantDatagramWrite(self: *Connection, is_want: c_int) c_int {
        return c.lsquic_conn_want_datagram_write(@ptrCast(self), is_want);
    }

    pub fn close(self: *Connection) void {
        return c.lsquic_conn_close(@ptrCast(self));
    }

    pub fn nPendingStreams(self: *Connection) c_uint {
        return c.lsquic_conn_n_pending_streams(@ptrCast(self));
    }
};

const Engine = @import("engine.zig").Engine;
pub const ConnectionContext = c.lsquic_conn_ctx_t;

pub const Cid = c.lsquic_cid_t;

const c = @cImport({
    @cInclude("lsquic.h");
    @cInclude("lsquic_types.h");
    @cInclude("lsxpack_header.h");
});
