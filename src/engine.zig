const EngineError = error{
    CreationFailed,
    InvalidSettings,
    MissingLookupCert,
};

pub const EngineFlags = struct {
    pub const SERVER = c.LSENG_SERVER;
    pub const HTTP = c.LSENG_HTTP;
};

// Callback types use anyopaque to avoid cross-@cImport type mismatches
// when consumed from a different module.
const PacketsOutFn = ?*const fn (
    packets_out_ctx: ?*anyopaque,
    specs: ?*const anyopaque,
    count: c_uint,
) callconv(.c) c_int;

const LookupCertFn = ?*const fn (
    cert_lu_ctx: ?*anyopaque,
    sock_addr: ?*const anyopaque,
    sni: [*c]const u8,
) callconv(.c) ?*anyopaque;

const GetSslCtxFn = ?*const fn (
    peer_ctx: ?*anyopaque,
    local_addr: ?*const anyopaque,
) callconv(.c) ?*anyopaque;

const lsquic = @import("lsquic.zig");

/// Use C type directly to guarantee layout compatibility.
pub const Settings = c.lsquic_engine_settings;

pub fn initSettings(settings: *Settings, flags: c_uint) void {
    c.lsquic_engine_init_settings(settings, flags);
}

/// Returns true if settings are valid, false otherwise.
pub fn checkSettings(settings: *Settings, flags: c_uint, err_buf: []u8) bool {
    return c.lsquic_engine_check_settings(settings, flags, @ptrCast(err_buf), err_buf.len) == 0;
}

pub const EngineApi = struct {
    // Settings
    ea_settings: ?*const Settings,

    /// Functions linked to `Connection` and `Stream` events. These are mandatory.
    ea_stream_if: *const StreamIf,
    ea_stream_if_ctx: ?*anyopaque,

    /// Function to send packets out.
    ea_packets_out: PacketsOutFn,
    ea_packets_out_ctx: ?*anyopaque,

    /// Function to look up certificate to use. Necessary in server-mode.
    ea_lookup_cert: ?LookupCertFn = null,
    ea_cert_lu_ctx: ?*anyopaque = null,

    // SSL context callback
    /// Function to fetch SSL context. Optional in client-mode.
    ea_get_ssl_ctx: ?GetSslCtxFn,

    // Other optional callbacks
    ea_hsi_if: ?*const anyopaque = null,
    ea_hsi_ctx: ?*anyopaque = null,
    ea_alpn: ?[*:0]const u8 = null,

    /// The `PacketsOutFn` function and `StreamIf` struct of functions are mandatory on initialization.
    ///
    /// In server mode, `LookupCertFn` is mandatory.
    /// In client mode, `GetSslCtxFn` is optional.
    pub fn init(
        settings: *Settings,
        stream_if: *const StreamIf,
        stream_if_ctx: ?*anyopaque,
        packets_out: PacketsOutFn,
        packets_out_ctx: ?*anyopaque,
        lookup_cert: ?LookupCertFn,
        get_ssl_ctx: ?GetSslCtxFn,
    ) EngineApi {
        return .{
            .ea_settings = settings,
            .ea_packets_out = packets_out,
            .ea_packets_out_ctx = packets_out_ctx,
            .ea_stream_if = stream_if,
            .ea_stream_if_ctx = stream_if_ctx,
            .ea_lookup_cert = lookup_cert,
            .ea_get_ssl_ctx = get_ssl_ctx,
            .ea_hsi_if = null,
            .ea_hsi_ctx = null,
            .ea_alpn = null,
        };
    }
};

/// LSQUIC Engine wrapper
pub const Engine = extern struct {
    pub fn new(flags: c_uint, api: *const EngineApi) EngineError!*Engine {
        //TODO(bing): server should check that lookup cert exist
        //if (flags == EngineFlags.SERVER) {
        //    if (api.ea_lookup_cert == null) return error.MissingLookupCert;
        //}
        var c_api: c.lsquic_engine_api = .{
            .ea_settings = api.ea_settings,
            .ea_packets_out = @ptrCast(api.ea_packets_out),
            .ea_packets_out_ctx = api.ea_packets_out_ctx,
            .ea_stream_if = @ptrCast(api.ea_stream_if),
            .ea_stream_if_ctx = api.ea_stream_if_ctx,
            .ea_lookup_cert = if (api.ea_lookup_cert) |luc| @ptrCast(luc) else null,
            .ea_cert_lu_ctx = api.ea_cert_lu_ctx,
            .ea_get_ssl_ctx = if (api.ea_get_ssl_ctx) |gsc| @ptrCast(gsc) else null,
            .ea_hsi_if = @ptrCast(@alignCast(api.ea_hsi_if)),
            .ea_hsi_ctx = api.ea_hsi_ctx,
            .ea_alpn = api.ea_alpn,
        };

        const engine_ptr = c.lsquic_engine_new(flags, &c_api);
        if (engine_ptr == null) return EngineError.CreationFailed;

        return @ptrCast(engine_ptr.?);
    }

    pub fn packetIn(
        self: *Engine,
        data: *[:0]u8,
        local: ?*const c.sockaddr,
        peer: ?*const c.sockaddr,
        peer_ctx: anytype, // TODO: type?
        ecn: anytype,
    ) !void {
        if (c.lsquic_engine_packet_in(
            @ptrCast(self),
            @ptrCast(data),
            data.len,
            local,
            peer,
            peer_ctx,
            ecn,
        ) == -1) return error.PacketInError;
    }

    pub fn connect(
        self: *Engine,
        version: c_int,
        local_sa: ?*const SockAddr,
        peer_sa: ?*const SockAddr,
        peer_ctx: ?*anyopaque,
        conn_ctx: ?*lsquic.ConnectionContext,
        hostname: ?[]const u8,
        base_plpmtu: ?c_ushort,
        sess_resume: ?[]const u8,
        sess_resume_len: ?usize,
        token: ?[]const u8,
        token_sz: ?usize,
    ) ?*Connection {
        const conn = c.lsquic_engine_connect(
            @ptrCast(@alignCast(self)),
            @intCast(version),
            @ptrCast(@alignCast(local_sa)),
            @ptrCast(@alignCast(peer_sa)),
            @ptrCast(@alignCast(peer_ctx)),
            @ptrCast(@alignCast(conn_ctx)),
            // Optional arguments
            if (hostname) |hn| @ptrCast(hn) else "",
            if (base_plpmtu) |bp| bp else c.LSQUIC_DF_BASE_PLPMTU,
            if (sess_resume) |sr| @ptrCast(sr) else "",
            if (sess_resume_len) |l| l else 0,
            if (token) |t| @ptrCast(t) else "",
            if (token_sz) |s| s else 0,
        );

        return @ptrCast(conn);
    }
    /// Returns true if there are connections to be processed, false otherwise.
    ///
    pub fn earliestAdvTick(self: *Engine, diff: [*c]c_int) c_int {
        return c.lsquic_engine_earliest_adv_tick(@ptrCast(self), diff);
    }

    /// Closes all mini connections and marks all full connections as going away.
    /// In server mode, this also causes the engine to stop creating new connections.
    pub fn cooldown(self: *Engine) void {
        c.lsquic_engine_cooldown(@ptrCast(self));
    }

    /// Process tickable connections.
    /// This function must be called often enough so that packets and connections do not expire.
    ///
    /// The preferred method of doing so is by using lsquic_engine_earliest_adv_tick().
    pub fn processConns(self: *Engine) void {
        c.lsquic_engine_process_conns(@ptrCast(self));
    }

    /// Returns true if engine has some unsent packets.
    pub fn hasUnsentPackets(self: *Engine) bool {
        return c.lsquic_engine_has_unsent_packets(@ptrCast(self)) != 0;
    }

    /// Send out as many unsent packets as possible, until we are out of unsent packets or until ea_packets_out() fails.
    pub fn sendUnsentPackets(self: *Engine) void {
        c.lsquic_engine_send_unsent_packets(@ptrCast(self));
    }

    /// Destroy the engine and free all resources
    pub fn destroy(self: *Engine) void {
        const engine_ptr: *c.lsquic_engine_t = @ptrCast(self);
        c.lsquic_engine_destroy(engine_ptr);
    }
};

test "Engine creation fails with invalid settings" {
    const stream_if: StreamIf = .{};
    const api = EngineApi{
        .ea_settings = null,
        .ea_stream_if = &stream_if,
        .ea_stream_if_ctx = null,
        .ea_packets_out = null,
        .ea_packets_out_ctx = null,
        .ea_get_ssl_ctx = null,
    };
    try std.testing.expectError(EngineError.CreationFailed, Engine.new(EngineFlags.SERVER, &api));
}

const std = @import("std");
const testing = std.testing;
const StreamIf = @import("stream.zig").StreamIf;
const Connection = @import("connection.zig").Connection;
const SockAddr = @import("lsquic.zig").SockAddr;

const c = @cImport({
    @cInclude("lsquic.h");
    @cInclude("lsquic_types.h");
    @cInclude("lsxpack_header.h");
});
