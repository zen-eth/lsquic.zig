const EngineError = error{ CreationFailed, InvalidSettings };

pub const EngineFlags = struct {
    pub const SERVER = c.LSENG_SERVER;
    pub const HTTP = c.LSENG_HTTP;
};

const PacketsOutFn = ?*const fn (
    packets_out_ctx: ?*anyopaque,
    specs: [*c]const lsquic.OutSpec,
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

const lsquic = @import("lsquic.zig");

pub const Settings = extern struct {
    es_versions: c_uint,
    es_cfcw: c_uint,
    es_sfcw: c_uint,
    es_max_cfcw: c_uint,
    es_max_sfcw: c_uint,
    es_max_streams_in: c_uint,
    es_handshake_to: c_ulong,
    es_idle_conn_to: c_ulong,
    es_silent_close: c_int,
    es_max_header_list_size: c_uint,
    es_ua: [*c]const u8,
    es_sttl: u64,
    es_pdmd: u32,
    es_aead: u32,
    es_kexs: u32,
    es_max_inchoate: c_uint,
    es_support_srej: c_int,
    es_support_push: c_int,
    es_support_tcid0: c_int,
    es_support_nstp: c_int,
    es_honor_prst: c_int,
    es_send_prst: c_int,
    es_progress_check: c_uint,
    es_rw_once: c_int,
    es_proc_time_thresh: c_uint,
    es_pace_packets: c_int,
    es_clock_granularity: c_uint,
    es_cc_algo: c_uint,
    es_cc_rtt_thresh: c_uint,
    es_noprogress_timeout: c_uint,
    es_init_max_data: c_uint,
    es_init_max_stream_data_bidi_remote: c_uint,
    es_init_max_stream_data_bidi_local: c_uint,
    es_init_max_stream_data_uni: c_uint,
    es_init_max_streams_bidi: c_uint,
    es_init_max_streams_uni: c_uint,
    es_idle_timeout: c_uint,
    es_ping_period: c_uint,
    es_scid_len: c_uint,
    es_scid_iss_rate: c_uint,
    es_qpack_dec_max_size: c_uint,
    es_qpack_dec_max_blocked: c_uint,
    es_qpack_enc_max_size: c_uint,
    es_qpack_enc_max_blocked: c_uint,
    es_ecn: c_int,
    es_allow_migration: c_int,
    es_retry_token_duration: c_uint,
    es_ql_bits: c_int,
    es_spin: c_int,
    es_delayed_acks: c_int,
    es_timestamps: c_int,
    es_max_udp_payload_size_rx: c_ushort,
    es_grease_quic_bit: c_int,
    es_dplpmtud: c_int,
    es_base_plpmtu: c_ushort,
    es_max_plpmtu: c_ushort,
    es_mtu_probe_timer: c_uint,
    es_datagrams: c_int,
    es_optimistic_nat: c_int,
    es_ext_http_prio: c_int,
    es_qpack_experiment: c_int,
    es_ptpc_periodicity: c_uint,
    es_ptpc_max_packtol: c_uint,
    es_ptpc_dyn_target: c_int,
    es_ptpc_target: f32,
    es_ptpc_prop_gain: f32,
    es_ptpc_int_gain: f32,
    es_ptpc_err_thresh: f32,
    es_ptpc_err_divisor: f32,
    es_delay_onclose: c_int,
    es_max_batch_size: c_uint,
    es_check_tp_sanity: c_int,
    es_amp_factor: c_int,
    es_send_verneg: c_int,
    es_preferred_address: [24]u8,

    pub fn init(settings: *Settings, flags: c_uint) void {
        c.lsquic_engine_init_settings(@ptrCast(settings), flags);
    }

    pub fn check(settings: *Settings, flags: c_uint, err_buf: []u8) bool {
        return c.lsquic_engine_check_settings(@ptrCast(settings), flags, @ptrCast(err_buf), err_buf.len) != 0;
    }
};

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
    ea_lookup_cert: ?LookupCertFn,
    ea_cert_lu_ctx: ?*anyopaque = null,

    // SSL context callback
    /// Function to fetch SSL context. Optional in client-mode.
    ea_get_ssl_ctx: ?GetSslCtxFn,

    // Other optional callbacks
    ea_hsi_if: ?*const c.lsquic_hset_if,
    ea_hsi_ctx: ?*anyopaque,
    ea_alpn: ?[*:0]const u8,

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
        var c_api: c.lsquic_engine_api = .{
            .ea_settings = @ptrCast(api.ea_settings),
            .ea_packets_out = api.ea_packets_out,
            .ea_packets_out_ctx = api.ea_packets_out_ctx,
            .ea_stream_if = @ptrCast(&api.ea_stream_if),
            .ea_stream_if_ctx = api.ea_stream_if_ctx,
            .ea_lookup_cert = if (api.ea_lookup_cert) |luc| luc else null,
            .ea_cert_lu_ctx = api.ea_cert_lu_ctx,
            .ea_get_ssl_ctx = if (api.ea_get_ssl_ctx) |gsc| gsc else null,
            .ea_hsi_if = api.ea_hsi_if,
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
        version: lsquic.LsquicVersion,
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
        return @ptrCast(c.lsquic_engine_connect(
            @ptrCast(self),
            @intFromEnum(version),
            local_sa,
            peer_sa,
            peer_ctx,
            conn_ctx,
            @ptrCast(hostname.?),
            if (base_plpmtu) |bp| bp else c.LSQUIC_DF_BASE_PLPMTU,
            @ptrCast(sess_resume),
            if (sess_resume_len) |l| l else 0,
            @ptrCast(token),
            if (token_sz) |s| s else 0,
        ));
    }
    /// Returns true if there are connections to be processed, false otherwise.
    ///
    pub fn earliestAdvTick(self: *Engine, diff: [*c]c_int) bool {
        return c.lsquic_engine_earliest_adv_tick(@ptrCast(self), diff) != 0;
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
    const packetsOut: PacketsOutFn = undefined;
    const stream_if: StreamIf = .{};
    const api = EngineApi.init(packetsOut, stream_if, null, null);
    try std.testing.expectError(EngineError.InvalidSettings, Engine.new(EngineFlags.SERVER, &api));
}

const std = @import("std");
const testing = std.testing;
const StreamIf = @import("stream.zig").StreamIf;
const Connection = @import("connection.zig").Connection;
const SockAddr = @import("lsquic.zig").SockAddr;

pub const Settings2 = c.lsquic_engine_settings;

const c = @cImport({
    @cInclude("lsquic.h");
    @cInclude("lsquic_types.h");
    @cInclude("lsxpack_header.h");
});
