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
    _ = sz;
    var s: i32 = 0;
    if (conn) |c| s = c.wantDatagramWrite(0);
    std.debug.assert(s == 1);

    @memcpy(@constCast(@as([*]u8, @ptrCast(@constCast(buf)))), "quack-ack");
    if (conn) |c| c.close();

    return s;
}

fn serverOnDatagram(
    conn: ?*lsquic.Conn,
    buf: *const anyopaque,
    sz: usize,
) callconv(.c) void {
    _ = sz;
    std.debug.print("Received expected response: {s}\n", .{buf});
    if (conn) |c| _ = c.wantDatagramWrite(1);
}

var server_callbacks = lsquic.StreamIf{
    .on_new_conn = serverOnNewConn,
    .on_conn_closed = serverOnConnClosed,
    .on_dg_write = serverOnDgWrite,
    .on_datagram = serverOnDatagram,
};

const Server = struct {
    loop: xev.Loop,
    udp: xev.UDP,
    engine: *lsquic.engine.Engine,
    timer: xev.Timer,
    allocator: std.mem.Allocator,
    sockfd: std.posix.socket_t,
    state: xev.UDP.State = undefined,
    recv_buf: [65535]u8 = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        const loop = try xev.Loop.init(.{});
        const addr = try std.net.Address.parseIp4("0.0.0.0", 1992);

        const udp = try xev.UDP.init(addr);
        try udp.bind(addr);
        const timer = try xev.Timer.init();

        try lsquic.globalInit(lsquic.GlobalInitFlags.SERVER);

        var eapi = lsquic.engine.EngineApi.init(send_packets_out, server_callbacks);
        eapi.packetsOutCtx = undefined;
        eapi.streamIfCtx = undefined;

        const engine = try lsquic.engine.Engine.new(lsquic.engine.EngineFlags.SERVER, &eapi);

        return Self{
            .loop = loop,
            .udp = udp,
            .engine = engine,
            .timer = timer,
            .allocator = allocator,
            .sockfd = undefined,
        };
    }

    pub fn deinit(self: *Self) void {
        self.loop.deinit();
        lsquic.globalCleanup();
    }

    pub fn run(self: *Self) !void {
        var recv_completion: xev.Completion = undefined;
        var timer_completion: xev.Completion = undefined;

        // Start reading packets
        self.udp.read(
            &self.loop,
            &recv_completion,
            &self.state,
            .{ .slice = &self.recv_buf },
            Self,
            self,
            readCallback,
        );

        // Start timer for connection processing
        self.timer.run(&self.loop, &timer_completion, 1000, Self, self, timerCallback);

        try self.loop.run(.until_done);
    }

    fn readCallback(
        _: ?*Self,
        loop: *xev.Loop,
        completion: *xev.Completion,
        _: *xev.UDP.State,
        _: std.net.Address,
        _: xev.UDP,
        buffer: xev.ReadBuffer,
        result: xev.ReadError!usize,
    ) xev.CallbackAction {
        _ = loop;
        _ = completion;
        _ = buffer;

        const bytes_read = result catch |err| {
            std.debug.print("Read error: {}\n", .{err});
            return .disarm;
        };

        if (bytes_read > 0) {
            // Process incoming packet through LSQUIC engine
            // This would involve calling lsquic_engine_packet_in()
            std.debug.print("Received {} bytes\n", .{bytes_read});
        }

        return .rearm;
    }

    fn timerCallback(
        self_: ?*Self,
        loop: *xev.Loop,
        completion: *xev.Completion,
        result: xev.Timer.RunError!void,
    ) xev.CallbackAction {
        _ = result catch return .disarm;

        const self = self_.?;
        std.debug.print("waiting...\n", .{});

        // Restart timer
        self.timer.run(loop, completion, 1000, Self, self, timerCallback);
        return .disarm;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Initializing LSQUIC server with xev event loop...\n", .{});

    var server = try Server.init(allocator);
    defer server.deinit();

    try server.run();
}

const fd_t = std.posix.system.fd_t;
const sendmsg = std.posix.sendmsg;
const msghdr_const = std.posix.msghdr_const;
const std = @import("std");
const lsquic = @import("lsquic");
const xev = @import("xev");
