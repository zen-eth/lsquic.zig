/// A quick tutorial demonstrating usage of lsquic.
///
/// Sources:
/// - https://lsquic.readthedocs.io/en/latest/tutorial.html
/// - https://github.com/dtikhonov/lsquic-tutorial
fn send_packets_out(
    _: ?*anyopaque,
    specs: [*c]const lsquic.OutSpec,
    count: c_uint,
) callconv(.C) c_int {
    var msg: msghdr_const = undefined;

    var n: usize = 1;
    const sockfd: *fd_t = @ptrCast(@alignCast(specs[n].peer_ctx.?));
    while (n < count) : (n += 1) {
        msg.name = @ptrCast(specs[n].dest_sa);
        msg.namelen = @sizeOf(std.posix.sockaddr);
        msg.iov = @ptrCast(specs[n].iov);
        msg.iovlen = @intCast(specs[n].iovlen);
        _ = sendmsg(sockfd.*, &msg, 0) catch @panic("send msg error");
    }

    return @intCast(n);
}

const TutorialServer = struct {};

/// # Behaviour
///
/// server: `Connection` object is created before the handshake is attempted
/// Server: handshake is already known to succeed
fn serverOnNewConn(stream_if_ctx: ?*anyopaque, conn: ?*lsquic.Conn) callconv(.c) ?*lsquic.ConnectionContext {
    _ = stream_if_ctx;
    _ = conn;
    std.log.debug("New siduck connection established!", .{});

    return null;
}

fn serverOnConnClosed(conn: ?*lsquic.Conn) callconv(.c) void {
    _ = conn;
    std.log.debug("siduck connection closed!", .{});
    //TODO: set context?
}

fn serverOnDgWrite(
    conn: ?*lsquic.Conn,
    buf: *const anyopaque,
    sz: usize,
) callconv(.c) isize {
    var s: i32 = 0;
    if (conn) |c| s = c.wantDatagramWrite(0);
    std.debug.assert(s == 1);

    @memcpy(buf[0..sz], "quack-ack");
    if (conn) |c| c.close();
}

fn serverOnDatagram(
    conn: ?*lsquic.Conn,
    buf: *const anyopaque,
    sz: usize,
) callconv(.c) void {
    if (sz == 9 and std.mem.eql(u8, @ptrCast(buf[0..sz]), "quack-ack")) {
        std.debug.print("Received expected response: {s}\n", .{buf});
        if (conn) |c| c.close();
    }
}

var server_callbacks = lsquic.StreamIf{
    .on_new_conn = serverOnNewConn,
    .on_conn_closed = serverOnConnClosed,
    .on_dg_write = serverOnDgWrite,
    .on_datagram = serverOnDatagram,
};

pub fn main() !void {
    std.debug.print("Initializing LSQUIC library...\n", .{});

    try lsquic.globalInit(lsquic.GlobalInitFlags.SERVER);
    defer lsquic.globalCleanup();
    var eapi = lsquic.engine.EngineApi.init(send_packets_out, server_callbacks);

    eapi.packetsOutCtx = undefined;
    eapi.streamIfCtx = undefined;

    _ = try lsquic.engine.Engine.new(lsquic.engine.EngineFlags.SERVER, &eapi);
}

const fd_t = std.posix.system.fd_t;
const sendmsg = std.posix.sendmsg;
const msghdr_const = std.posix.msghdr_const;
const std = @import("std");
const lsquic = @import("lsquic");
