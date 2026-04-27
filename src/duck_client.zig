/// A quick tutorial demonstrating usage of lsquic.
///
/// Sources:
/// - https://lsquic.readthedocs.io/en/latest/tutorial.html
/// - https://github.com/dtikhonov/lsquic-tutorial
fn send_packets_out(
    _: ?*anyopaque,
    specs_raw: ?*const anyopaque,
    count: c_uint,
) callconv(.c) c_int {
    const specs: [*]const lsquic.OutSpec = @ptrCast(@alignCast(specs_raw.?));
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

const TutorialClient = struct {};

/// # Behaviour
///
/// Client: `Connection` object is created before the handshake is attempted
/// Server: handshake is already known to succeed
fn clientOnNewConn(stream_if_ctx: ?*anyopaque, conn: ?*lsquic.Conn) callconv(.c) ?*lsquic.ConnectionContext {
    _ = stream_if_ctx;

    if (conn) |c| c.makeStream();

    return null;
}

fn client_on_hsk_done(conn: ?*lsquic.Conn, status: lsquic.HskStatus) callconv(.c) void {
    _ = conn;
    _ = status;
}

fn clientOnConnClosed(conn: ?*lsquic.Conn) callconv(.c) void {
    _ = conn;
}

fn clientOnNewStream(stream_if_ctx: ?*anyopaque, stream: ?*lsquic.StreamRaw) callconv(.c) ?*lsquic.StreamContext {
    _ = stream_if_ctx;
    _ = stream;
    return null;
}

fn clientOnRead(stream: ?*lsquic.Stream, stream_ctx: ?*lsquic.StreamContext) callconv(.c) void {
    _ = stream_ctx;
    var buf: [10]u8 = [_]u8{0} ** 10;
    if (stream) |s| _ = s.read(&buf, buf.len);
}

fn client_on_write(stream: ?*lsquic.StreamRaw, stream_ctx: ?*lsquic.StreamContext) callconv(.c) void {
    _ = stream;
    _ = stream_ctx;
}

fn client_on_close(stream: ?*lsquic.StreamRaw, stream_ctx: ?*lsquic.StreamContext) callconv(.c) void {
    _ = stream;
    _ = stream_ctx;
}

var client_callbacks = lsquic.StreamIf{
    .on_new_conn = clientOnNewConn,
    .on_hsk_done = client_on_hsk_done,
    .on_conn_closed = clientOnConnClosed,
    .on_new_stream = clientOnNewStream,
    .on_read = clientOnRead,
    .on_write = client_on_write,
    .on_close = client_on_close,
};

pub fn main() !void {
    std.debug.print("Initializing LSQUIC library...\n", .{});

    try lsquic.globalInit(lsquic.GlobalInitFlags.CLIENT);
    defer lsquic.globalCleanup();

    var settings: lsquic.engine.Settings = undefined;
    lsquic.engine.initSettings(&settings, 0);

    var eapi = lsquic.engine.EngineApi.init(
        &settings,
        &client_callbacks,
        null,
        send_packets_out,
        null,
        null,
        null,
    );

    _ = try lsquic.engine.Engine.new(lsquic.engine.EngineFlags.SERVER, &eapi);
}

const fd_t = std.posix.system.fd_t;
const sendmsg = std.posix.sendmsg;
const msghdr_const = std.posix.msghdr_const;
const std = @import("std");
const lsquic = @import("lsquic");
