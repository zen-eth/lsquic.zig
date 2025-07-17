const EngineError = error{CreationFailed};

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
    /// Initial default connection flow control window
    es_cfcw: c_uint,
    /// Initial default stream flow control window
    es_sfcw: c_uint,
    /// Maximum allowed value CFCW is allowed to reach due to window auto-tuning
    es_max_cfcw: c_uint,
    /// Maximum value stream flow control window is allowed to reach
    es_max_sfcw: c_uint,
    /// Maximum incoming streams, aka MIDS.
    ///
    /// Google QUIC only.
    es_max_streams_in: c_uint,
    /// Handshake timeout in microseconds.
    es_handshake_to: c_ulong = c.LSQUIC_DF_HANDSHAKE_TO,
    /// Idle connection timeout, ICSL, in microseconds.
    ///
    /// Google QUIC only.
    es_idle_conn_to: c_ulong = c.LSQUIC_DF_IDLE_CONN_TO,
    /// When true, CONNECTION_CLOSE is not sent when connection times out.
    es_silent_close: c_int,
    /// Corresponds to `SETTINGS_MAX_HEADER_LIST_SIZE`: https://datatracker.ietf.org/doc/html/rfc7540.html#section-6.5.2
    es_max_header_list_size: c_uint = c.LSQUIC_DF_MAX_HEADER_LIST_SIZE,
    /// User-Agent ID
    es_ua: [*:0]const u8,
    /// Maximum number of incoming connections
    es_max_inchoate: c_uint,
    /// Enable/disable server push
    es_support_push: c_int,
    /// Support TCID0
    es_support_tcid0: c_int,
    /// Support NSTP
    es_support_nstp: c_int,
    /// Honor prst
    es_honor_prst: c_int,
    /// Send prst
    es_send_prst: c_int,
    /// Progress check
    es_progress_check: c_uint,
    /// Read/write once
    es_rw_once: c_int,
    /// Process time threshold
    es_proc_time_thresh: c_uint,
    /// Pace packets
    es_pace_packets: c_int,
    /// Clock granularity
    es_clock_granularity: c_uint,
    /// Congestion control algorithm
    es_cc_algo: c_uint,
    /// Congestion control RTT threshold
    es_cc_rtt_thresh: c_uint,
    /// No progress timeout
    es_noprogress_timeout: c_uint,
    /// Initial max data
    es_init_max_data: c_uint,
    /// Initial max stream data bidirectional remote
    es_init_max_stream_data_bidi_remote: c_uint,
    /// Initial max stream data bidirectional local
    es_init_max_stream_data_bidi_local: c_uint,
    /// Initial max stream data unidirectional
    es_init_max_stream_data_uni: c_uint,
    /// Initial max streams bidirectional
    es_init_max_streams_bidi: c_uint,
    /// Initial max streams unidirectional
    es_init_max_streams_uni: c_uint,
    /// Idle timeout
    es_idle_timeout: c_uint,
    /// Ping period
    es_ping_period: c_uint,
    /// Source Connection ID length
    es_scid_len: c_uint,
    /// Source Connection ID issuance rate
    es_scid_iss_rate: c_uint,
    /// QPACK decoder maximum size
    es_qpack_dec_max_size: c_uint,
    /// QPACK decoder maximum blocked
    es_qpack_dec_max_blocked: c_uint,
    /// QPACK encoder maximum size
    es_qpack_enc_max_size: c_uint,
    /// QPACK encoder maximum blocked
    es_qpack_enc_max_blocked: c_uint,
    /// Enable ECN support
    es_ecn: c_int,
    /// Allow migration
    es_allow_migration: c_int,
    /// QL bits
    es_ql_bits: c_int,
    /// Spin bit
    es_spin: c_int,
    /// Delayed ACKs
    es_delayed_acks: c_int,
    /// Timestamps
    es_timestamps: c_int,
    /// Maximum UDP payload size for RX
    es_max_udp_payload_size_rx: c_ushort,
    /// Grease QUIC bit
    es_grease_quic_bit: c_int,
};

pub const EngineApi = struct {
    /// Functions linked to `Connection` and `Stream` events. These are mandatory.
    streamIf: StreamIf,
    streamIfCtx: ?*anyopaque,

    /// Function to send packets out.
    packetsOut: PacketsOutFn,
    packetsOutCtx: ?*anyopaque,

    // Settings
    settings: ?*const c.lsquic_engine_settings,

    /// Function to look up certificate to use. Necessary in server-mode.
    lookupCert: LookupCertFn,
    certLuCtx: ?*anyopaque,

    // SSL context callback
    /// Function to fetch SSL context. Optional in client-mode.
    getSslCtx: GetSslCtxFn,

    // Other optional callbacks
    hsiIf: ?*const c.lsquic_hset_if,
    hsiCtx: ?*anyopaque,
    alpn: ?[*:0]const u8,

    /// The `PacketsOutFn` function and `StreamIf` struct of functions are mandatory on initialization.
    ///
    /// In server mode, `LookupCertFn` is mandatory.
    /// In client mode, `GetSslCtxFn` is optional.
    pub fn init(
        packets_out: PacketsOutFn,
        stream_if: StreamIf,
    ) EngineApi {
        return .{
            .packetsOut = packets_out,
            .packetsOutCtx = null,
            .streamIf = stream_if,
            .streamIfCtx = null,
            .settings = null,
            .lookupCert = null,
            .certLuCtx = null,
            .getSslCtx = null,
            .hsiIf = null,
            .hsiCtx = null,
            .alpn = null,
        };
    }
};

/// LSQUIC Engine wrapper
pub const Engine = extern struct {
    pub fn new(flags: c_uint, api: *const EngineApi) EngineError!*Engine {
        // Convert our Zig EngineApi to C's lsquic_engine_api
        var c_api: c.lsquic_engine_api = .{
            .ea_packets_out = api.packetsOut,
            .ea_packets_out_ctx = api.packetsOutCtx,
            .ea_stream_if = @ptrCast(&api.streamIf),
            .ea_stream_if_ctx = api.streamIfCtx,
            .ea_settings = api.settings,
            .ea_lookup_cert = api.lookupCert,
            .ea_cert_lu_ctx = api.certLuCtx,
            .ea_get_ssl_ctx = api.getSslCtx,
            .ea_hsi_if = api.hsiIf,
            .ea_hsi_ctx = api.hsiCtx,
            .ea_alpn = api.alpn,
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
        if (try c.lsquic_engine_packet_in(
            @ptrCast(self),
            data,
            data.len,
            local,
            peer,
            peer_ctx,
            ecn,
        ) == -1) return error.PacketInError;
    }

    /// Returns true if there are connections to be processed, false otherwise.
    pub fn earliestAdvTick(self: *Engine, diff: [*c]c_int) bool {
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
    pub fn hasUnsentPackets(self: *Engine) void {
        c.lsquic_engine_has_unsent_packets(@ptrCast(self));
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

const std = @import("std");
const testing = std.testing;
const StreamIf = @import("stream.zig").StreamIf;

const c = @cImport({
    @cInclude("lsquic.h");
    @cInclude("lsquic_types.h");
    @cInclude("lsxpack_header.h");
});
