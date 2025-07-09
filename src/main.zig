/// A quick tutorial demonstrating usage of lsquic.
///
/// Sources:
/// - https://lsquic.readthedocs.io/en/latest/tutorial.html
/// - https://github.com/dtikhonov/lsquic-tutorial
fn ea_packets_out(
    _: ?*anyopaque,
    specs: [*c]const lsquic.out_spec,
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

const TutorialClient = struct {};

fn client_on_new_conn(stream_if_ctx: ?*anyopaque, conn: ?*lsquic.lsquic_conn_t) callconv(.c) ?*lsquic.ConnectionContext {
    _ = stream_if_ctx;
    _ = conn;

    return null;
}

fn client_on_hsk_done() void {}
fn client_on_conn_closed() void {}
fn client_on_new_stream() void {}
fn client_on_read() void {}
fn client_on_write() void {}
fn client_on_close() void {}

var client_callbacks = lsquic.engine.StreamIf{
    .on_new_conn = client_on_new_conn,
    // .on_hsk_done = client_on_hsk_done,
    // .on_conn_closed = client_on_conn_closed,
    // .on_new_stream = client_on_new_stream,
    // .on_read = client_on_read,
    // .on_write = client_on_write,
    // .on_close = client_on_close,
};

pub fn main() !void {
    std.debug.print("Initializing LSQUIC library...\n", .{});

    try lsquic.globalInit(lsquic.GlobalInitFlags.CLIENT);
    defer lsquic.globalCleanup();
    var eapi = lsquic.engine.EngineApi.init(ea_packets_out, client_callbacks);

    eapi.ea_packets_out_ctx = undefined;
    eapi.ea_stream_if_ctx = undefined;

    _ = try lsquic.engine.Engine.new(lsquic.engine.EngineFlags.SERVER, &eapi);
}

const fd_t = std.posix.system.fd_t;
const sendmsg = std.posix.sendmsg;
const msghdr_const = std.posix.msghdr_const;
const std = @import("std");
const lsquic = @import("lsquic");
