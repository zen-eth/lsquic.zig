const EngineError = error{CreationFailed};

pub const EngineFlags = struct {
    pub const SERVER = c.LSENG_SERVER;
    pub const HTTP = c.LSENG_HTTP;
};

const PacketsOutFn = ?*const fn (
    packets_out_ctx: ?*anyopaque,
    specs: [*c]const c.lsquic_out_spec,
    count: c_uint,
) callconv(.C) c_int;

const LookupCertFn = ?*const fn (
    cert_lu_ctx: ?*anyopaque,
    sock_addr: ?*const c.sockaddr,
    sni: [*c]const u8,
) callconv(.C) ?*c.ssl_ctx_st;

const GetSslCtxFn = ?*const fn (
    peer_ctx: ?*anyopaque,
    local_addr: ?*const c.sockaddr,
) callconv(.C) ?*c.ssl_ctx_st;

pub const StreamIf = c.lsquic_stream_if;

pub const EngineApi = struct {
    /// Function to send packets out.
    ea_packets_out: PacketsOutFn,

    ea_packets_out_ctx: ?*anyopaque,

    /// Functions linked to `Connection` and `Stream` events. These are mandatory.
    ea_stream_if: StreamIf,
    ea_stream_if_ctx: ?*anyopaque,

    // Settings
    ea_settings: ?*const c.lsquic_engine_settings,

    /// Function to look up certificate to use. Necessary in server-mode.
    ea_lookup_cert: LookupCertFn,
    ea_cert_lu_ctx: ?*anyopaque,

    // SSL context callback
    /// Function to fetch SSL context. Optional in client-mode.
    ea_get_ssl_ctx: GetSslCtxFn,

    // Other optional callbacks
    ea_hsi_if: ?*const c.lsquic_hset_if,
    ea_hsi_ctx: ?*anyopaque,
    ea_alpn: ?[*:0]const u8,

    /// The `PacketsOutFn` function and `StreamIf` struct of functions are mandatory on initialization.
    ///
    /// In server mode, `LookupCertFn` is mandatory.
    /// In client mode, `GetSslCtxFn` is optional.
    pub fn init(
        packets_out: PacketsOutFn,
        stream_if: StreamIf,
    ) EngineApi {
        return .{
            .ea_packets_out = packets_out,
            .ea_packets_out_ctx = null,
            .ea_stream_if = stream_if,
            .ea_stream_if_ctx = null,
            .ea_settings = null,
            .ea_lookup_cert = null,
            .ea_cert_lu_ctx = null,
            .ea_get_ssl_ctx = null,
            .ea_hsi_if = null,
            .ea_hsi_ctx = null,
            .ea_alpn = null,
        };
    }
};

/// LSQUIC Engine wrapper
pub const Engine = opaque {
    pub fn new(flags: c_uint, api: *const EngineApi) EngineError!*Engine {
        // Convert our Zig EngineApi to C's lsquic_engine_api
        var c_api: c.lsquic_engine_api = .{
            .ea_packets_out = api.ea_packets_out,
            .ea_packets_out_ctx = api.ea_packets_out_ctx,
            .ea_stream_if = api.ea_stream_if,
            .ea_stream_if_ctx = api.ea_stream_if_ctx,
            .ea_settings = api.ea_settings,
            .ea_lookup_cert = api.ea_lookup_cert,
            .ea_cert_lu_ctx = api.ea_cert_lu_ctx,
            .ea_get_ssl_ctx = api.ea_get_ssl_ctx,
            .ea_hsi_if = api.ea_hsi_if,
            .ea_hsi_ctx = api.ea_hsi_ctx,
            .ea_alpn = api.ea_alpn,
        };

        const engine_ptr = c.lsquic_engine_new(flags, &c_api);
        if (engine_ptr == null) return EngineError.CreationFailed;

        return @ptrCast(engine_ptr.?);
    }

    /// Destroy the engine and free all resources
    pub fn destroy(self: *Engine) void {
        const engine_ptr: *c.lsquic_engine_t = @ptrCast(self);
        c.lsquic_engine_destroy(engine_ptr);
    }
};

const std = @import("std");
const testing = std.testing;

const c = @cImport({
    @cInclude("lsquic.h");
    @cInclude("lsquic_types.h");
    @cInclude("lsxpack_header.h");
});
