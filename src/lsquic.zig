// Re-export the C types for convenience
// pub const Conn = c.lsquic_conn_t;
pub const ConnectionContext = c.lsquic_conn_ctx_t;
// pub const StreamRaw = c.lsquic_stream_t;
// pub const StreamContext = c.lsquic_stream_ctx_t;
pub const OutSpec = c.lsquic_out_spec;
pub const SockAddr = c.struct_sockaddr;
pub const IoVec = c.struct_iovec;
pub const SslCtxSt = c.struct_ssl_ctx_st;

pub const LsquicVersion = enum(u8) {
    V043 = c.LSQVER_043,
    V046 = c.LSQVER_046,
    V050 = c.LSQVER_050,
    V_ID27 = c.LSQVER_ID27,
    V_ID29 = c.LSQVER_ID29,
    V_I001 = c.LSQVER_I001,
    V_I002 = c.LSQVER_I002,
    /// Special value indicating the number of versions in the enum. It may be used as argument to `engine.connect()`.
    N_LSQVER = c.N_LSQVER,
};

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

/// Microseconds since some time. Equivalent to `lsquic_time_t`.
pub const Time = u64;

// Opaque types (will need proper definitions elsewhere)
pub const HashElement = extern struct { data: [32]u8 };
pub const Hash = opaque {};
pub const DataIn = opaque {};

test "lsquic global init and cleanup" {
    // Initialize for both client and server
    try globalInit(GlobalInitFlags.CLIENT | GlobalInitFlags.SERVER);
    globalCleanup();

    try globalInit(GlobalInitFlags.CLIENT);
    globalCleanup();

    try globalInit(GlobalInitFlags.SERVER);
    globalCleanup();
}

fn newStream() Stream {}

//* Write data to the stream, but do not flush: connection cap take a hit.
// * After stream is destroyed, connection cap should go back up.
// */
//static void
//test_reset_stream_with_unflushed_data (struct test_objs *tobjs)
//{
//    lsquic_stream_t *stream;
//    char buf[0x100];
//    size_t n;
//    const struct lsquic_conn_cap *const cap = &tobjs->conn_pub.conn_cap;
//
//    assert(0x4000 == lsquic_conn_cap_avail(cap));   /* Self-check */
//    stream = new_stream(tobjs, 345);
//    n = lsquic_stream_write(stream, buf, 100);
//    assert(n == 100);
//
//    /* Unflushed data counts towards connection cap for connection-limited
//     * stream:
//     */
//    assert(0x4000 - 100 == lsquic_conn_cap_avail(cap));
//
//    lsquic_stream_destroy(stream);
//    assert(0x4000 == lsquic_conn_cap_avail(cap));   /* Goes back up */
//}

const std = @import("std");
const testing = std.testing;

const Engine = engine.Engine;
pub const engine = @import("engine.zig");
pub const connection = @import("connection.zig");

pub const SslCtx = c.struct_ssl_ctx_st;

// Stream imports
pub const Stream = @import("stream.zig").Stream;
pub const HskStatus = @import("stream.zig").HskStatus;
pub const StreamContext = @import("stream.zig").StreamContext;
pub const StreamIf = @import("stream.zig").StreamIf;
pub const StreamId = @import("stream.zig").StreamId;
pub const StreamRaw = @import("stream.zig").StreamRaw;

test {
    testing.refAllDeclsRecursive(@This());
}

const c = @cImport({
    @cInclude("lsquic.h");
    @cInclude("lsquic_types.h");
    @cInclude("lsxpack_header.h");
});
