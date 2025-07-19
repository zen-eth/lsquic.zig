/// Connection wrapper
pub const Conn = extern struct {
    pub fn getId(self: *const Conn) *const Cid {
        const conn_ptr: *const c.lsquic_conn_t = @ptrCast(self);
        return c.lsquic_conn_id(conn_ptr);
    }

    pub fn getEngine(self: *Conn) *Engine {
        const conn_ptr: *c.lsquic_conn_t = @ptrCast(self);
        return @ptrCast(c.lsquic_conn_get_engine(conn_ptr));
    }

    pub fn getContext(self: *Conn) void {
        _ = self;
    }

    pub fn makeStream(self: *Conn) void {
        c.lsquic_conn_make_stream(@ptrCast(self));
    }

    pub fn wantDatagramWrite(self: *Conn, is_want: c_int) c_int {
        return c.lsquic_conn_want_datagram_write(@ptrCast(self), is_want);
    }
    pub fn close(self: *Conn) void {
        return c.lsquic_conn_close(@ptrCast(self));
    }
};

// Enum for send headers state
pub const SendHeadersState = enum(u8) {
    SSHS_BEGIN = 0,
    SSHS_ENC_SENDING = 1,
    SSHS_HBLOCK_SENDING = 2,
};

pub const ConnCap = extern struct {
    cc_max: u64,
    cc_sent: u64,
    cc_tosend: u64,
    cc_blocked: bool,
    cc_limited: bool,
};

// Additional forward declarations
pub const StreamsTailq = extern struct {
    tqh_first: ?*StreamRaw,
    tqh_last: ?**StreamRaw,
};
// Queue/List types
pub const TailqEntry = extern struct {
    tqe_next: ?*anyopaque,
    tqe_prev: ?*anyopaque,
};

pub const StailqHead = extern struct {
    stqh_first: ?*anyopaque,
    stqh_last: ?*anyopaque,
};

pub const SlistHead = extern struct {
    slh_first: ?*anyopaque,
};

pub const RttStats = extern struct {
    srtt: u32,
    rttvar: u32,
    min_rtt: u32,
    max_ack_delay: u32,
};

pub const EnginePublic = opaque {};
pub const Malo = opaque {};
pub const Mm = opaque {};
pub const HeadersStream = opaque {};
pub const QpackEncHdl = opaque {};
pub const QpackDecHdl = opaque {};
pub const HcsoWriter = opaque {};
pub const ConnStats = opaque {};

pub const ConnPublicFlags = enum(c_uint) {
    CP_STREAM_UNBLOCKED = 1 << 0,
    _,
};

pub const ConnPublic = extern struct {
    sending_streams: StreamsTailq,
    read_streams: StreamsTailq,
    write_streams: StreamsTailq,
    service_streams: StreamsTailq,
    all_streams: ?*Hash,
    cfcw: Cfcw,
    conn_cap: ConnCap,
    rtt_stats: RttStats,
    enpub: ?*EnginePublic,
    packet_out_malo: ?*Malo,
    lconn: ?*Conn,
    mm: ?*Mm,
    u: extern union {
        gquic: extern struct {
            hs: ?*HeadersStream,
        },
        ietf: extern struct {
            qeh: ?*QpackEncHdl,
            qdh: ?*QpackDecHdl,
            hcso: ?*HcsoWriter,
            promises: ?*Hash,
        },
    },
    cp_flags: ConnPublicFlags,
    send_ctl: ?*SendCtl,
    conn_stats: if (LSQUIC_CONN_STATS) ?*ConnStats else void,
    path: ?*NetworkPath,
    stream_frame_bytes: if (LSQUIC_EXTRA_CHECKS) c_ulong else void,
    wtp_level: if (LSQUIC_EXTRA_CHECKS) c_uint else void,
    bytes_in: c_uint,
    bytes_out: c_uint,
    last_tick: Time,
    last_prog: Time,
    max_peer_ack_usec: c_uint,
    n_special_streams: u8,
};
pub const Cfcw = extern struct {
    max_recv_off: u64,
    recv_off: u64,
    read_off: u64,
    max_recv_win: usize,
};

pub const StreamFlowControlWindow = extern struct {
    cfcw: Cfcw,
    sf_max_recv_off: u64,
    sf_recv_off: u64,
    sf_read_off: u64,
    sf_last_updated: Time,
    sf_conn_pub: [*c]ConnPublic,
    sf_max_recv_win: usize,
    sf_stream_id: StreamId,
};

/// Stream wrapper
pub const Stream = extern struct {
    sm_hash_el: HashElement,
    id: StreamId,
    stream_flags: StreamFlags,
    sm_bflags: StreamBFlags,
    sm_qflags: StreamQFlags,
    n_unacked: u32,

    stream_if: ?*const StreamIf,
    st_ctx: ?*StreamContext,
    conn_pub: ?*ConnPublic,

    // TAILQ entries for various linked lists
    next_send_stream: TailqEntry,
    next_read_stream: TailqEntry,
    next_write_stream: TailqEntry,
    next_service_stream: TailqEntry,
    next_prio_stream: TailqEntry,

    tosend_off: u64,
    sm_payload: u64,
    max_send_off: u64,
    sm_last_recv_off: u64,
    error_code: u64,

    data_in: ?*DataIn,
    read_offset: u64,
    fc: StreamFlowControlWindow,

    sm_hq_frames: StailqHead,
    sm_hq_frame_arr: [NUM_ALLOCED_HQ_FRAMES]StreamHqFrame,
    sm_hq_filter: HqFilter,
    sm_hq_arr: ?*HqArr,

    sm_flush_to: u64,
    sm_flush_to_payload: u64,
    blocked_off: u64,

    uh: ?*UncompressedHeaders,
    push_req: ?*UncompressedHeaders,
    sm_hblock_ctx: ?*HblockCtx,

    sm_buf: ?*u8,
    sm_onnew_arg: ?*anyopaque,

    sm_header_block: ?*u8,
    sm_hb_compl: u64,

    sm_fin_off: u64,

    // Function pointers
    sm_frame_header_sz: ?*const fn (*const Stream, u32) usize,
    sm_write_to_packet: ?*const fn (*FrameGenCtx, usize) SwtpStatus,
    sm_write_avail: ?*const fn (*Stream) usize,
    sm_readable: ?*const fn (*Stream) c_int,
    sm_get_packet_for_stream: ?*const fn (*SendCtl, u32, *const NetworkPath, *const Stream) ?*PacketOut,

    sm_sfi: ?*const StreamFilterIf,

    sm_promise: ?*PushPromise,
    sm_promises: SlistHead,

    sm_last_frame_off: u64,

    sm_last_prog: Time,

    sm_cont_len: c_ulonglong,
    sm_data_in: c_ulonglong,

    sm_hblock_sz: u32,
    sm_hblock_off: u32,

    sm_n_buffered: u16,
    sm_n_allocated: u16,

    sm_priority: u8,
    sm_enc_level: u8,
    sm_send_headers_state: SendHeadersState,
    sm_dflags: StreamDFlags,
    sm_saved_want_write: i8,
    sm_has_frame: i8,

    webtransport_session_stream_id: if (LSQUIC_WEBTRANSPORT_SERVER_SUPPORT) StreamId else void,
    sm_hist_idx: if (LSQUIC_KEEP_STREAM_HISTORY) HistIdx else void,
    sm_hist_buf: if (LSQUIC_KEEP_STREAM_HISTORY) [1 << SM_HIST_BITS]u8 else void,

    /// Get the connection this stream belongs to
    pub fn getConnection(self: *const Stream) *Conn {
        const stream_ptr: *const c.lsquic_stream_t = @ptrCast(self);
        return @ptrCast(c.lsquic_stream_conn(stream_ptr));
    }

    pub fn read(self: *Stream, buf: []u8, buflen: usize) void {
        _ = c.lsquic_stream_read(@ptrCast(self), @ptrCast(buf), buflen);
    }

    pub fn write(self: *Stream, buf: []u8, buflen: usize) void {
        _ = c.lsquic_stream_write(@ptrCast(@alignCast(self)), @ptrCast(buf), buflen);
    }
};

pub const StreamRaw = Stream;

pub const OnNewConnFn = ?*const fn (?*anyopaque, ?*Conn) callconv(.c) ?*ConnectionContext;
pub const OnGoawayReceivedFn = ?*const fn (?*Conn) callconv(.c) void;
pub const OnConnClosedFn = ?*const fn (?*Conn) callconv(.c) void;
pub const OnNewStreamFn = ?*const fn (?*anyopaque, ?*StreamRaw) callconv(.c) ?*StreamContext;
pub const OnReadFn = ?*const fn (?*StreamRaw, ?*StreamContext) callconv(.c) void;
pub const OnWriteFn = ?*const fn (?*StreamRaw, ?*StreamContext) callconv(.c) void;
pub const OnCloseFn = ?*const fn (?*StreamRaw, ?*StreamContext) callconv(.c) void;
pub const OnDgWriteFn = ?*const fn (?*Conn, *const anyopaque, usize) callconv(.c) isize;
pub const OnDatagramFn = ?*const fn (?*Conn, *const anyopaque, usize) callconv(.c) void;
pub const OnHskDoneFn = ?*const fn (?*Conn, HskStatus) callconv(.c) void;
pub const OnNewTokenFn = ?*const fn (?*Conn, [*c]const u8, usize) callconv(.c) void;
pub const OnSessResumeInfoFn = ?*const fn (?*Conn, [*c]const u8, usize) callconv(.c) void;
pub const OnResetFn = ?*const fn (?*StreamRaw, ?*StreamContext, c_int) callconv(.c) void;
pub const OnConnCloseFrameReceivedFn = ?*const fn (?*Conn, c_int, u64, [*c]const u8, c_int) callconv(.c) void;

/// Zig translation of struct lsquic_stream_if
/// The definitions of callback functions called by lsquic_stream to process events.
pub const StreamIf = extern struct {
    /// Called when a new connection is established.
    /// Use lsquic_conn_get_ctx to get back the context.
    /// It is OK for this function to return null.
    on_new_conn: OnNewConnFn = null,

    /// Called when our side received GOAWAY frame. After this,
    /// new streams should not be created. This callback is optional.
    on_goaway_received: OnGoawayReceivedFn = null,

    /// Called when a connection is closed.
    on_conn_closed: OnConnClosedFn = null,

    /// Called when a new stream is created.
    /// If you need to initiate a connection, call lsquic_conn_make_stream().
    /// This will cause `on_new_stream' callback to be called when appropriate
    /// (this operation is delayed when maximum number of outgoing streams is reached).
    /// After `on_close' is called, the stream is no longer accessible.
    on_new_stream: OnNewStreamFn = null,

    /// Called when stream data is available for reading.
    on_read: OnReadFn = null,

    /// Called when stream is ready for writing.
    on_write: OnWriteFn = null,

    /// Called when a stream is closed.
    on_close: OnCloseFn = null,

    /// Called when datagram is ready to be written.
    on_dg_write: OnDgWriteFn = null,

    /// Called when datagram is read from a packet. This callback is required
    /// when es_datagrams is true. Take care to process it quickly, as this
    /// is called during lsquic_engine_packet_in().
    on_datagram: OnDatagramFn = null,

    /// Called when handshake is completed. This callback is only called in client mode.
    on_hsk_done: OnHskDoneFn = null,

    /// Called when client receives a token in NEW_TOKEN frame. This callback is optional.
    on_new_token: OnNewTokenFn = null,

    /// This optional callback lets client record information needed to
    /// perform a session resumption next time around.
    /// For IETF QUIC, this is called only if ea_get_ssl_ctx() is *not* set,
    /// in which case the library creates its own SSL_CTX.
    /// Note: this callback will be deprecated when gQUIC support is removed.
    on_sess_resume_info: OnSessResumeInfoFn = null,

    /// Called as soon as the peer resets a stream.
    /// The argument `how' is either 0, 1, or 2, meaning "read", "write", and
    /// "read and write", respectively (just like in shutdown(2)). This
    /// signals the user to stop reading, writing, or both.
    /// Note that resets differ in gQUIC and IETF QUIC. In gQUIC, `how' is
    /// always 2; in IETF QUIC, `how' is either 0 or 1 because one can reset
    /// just one direction in IETF QUIC.
    on_reset: OnResetFn = null,

    /// Called when a CONNECTION_CLOSE frame is received.
    /// This allows the application to log low-level diagnostic information about
    /// errors received with the CONNECTION_CLOSE frame. If app_error is -1 then
    /// it is considered unknown if this is an app_error or not.
    on_conncloseframe_received: OnConnCloseFrameReceivedFn = null,
};

fn newTestStream() Stream {}

test "stream" {}

// Type definitions for the stream struct
pub const StreamFlags = u32;
pub const StreamBFlags = u32;
pub const StreamQFlags = u32;
pub const StreamDFlags = u8;

const lsquic = @import("lsquic.zig");

const HashElement = lsquic.HashElement;
const Time = lsquic.Time;
const DataIn = lsquic.DataIn;

pub const StreamHqFrame = extern struct { data: [64]u8 };
pub const HqFilter = extern struct { data: [32]u8 };
pub const HqArr = opaque {};
pub const UncompressedHeaders = opaque {};
pub const HblockCtx = opaque {};
pub const FrameGenCtx = opaque {};
pub const NetworkPath = opaque {};
pub const PacketOut = opaque {};
pub const StreamFilterIf = opaque {};
pub const PushPromise = opaque {};
// Constants
pub const NUM_ALLOCED_HQ_FRAMES = 4;
pub const SM_HIST_BITS = 6;
pub const LSQUIC_WEBTRANSPORT_SERVER_SUPPORT = false;
pub const LSQUIC_KEEP_STREAM_HISTORY = false;

// Constants for conditional compilation
pub const LSQUIC_CONN_STATS = false;
pub const LSQUIC_EXTRA_CHECKS = false;

/// Equivalent to `lsquic_packno_t`.
pub const PackNo = u64;
/// Equivalent to `lsquic_ver_tag_t`.
pub const VerTag = u64;
pub const SwtpStatus = u32;
pub const HistIdx = u32;

pub const SendCtl = opaque {};
pub const Hash = opaque {};
const Engine = @import("engine.zig").Engine;
pub const HskStatus = c.lsquic_hsk_status;
pub const Cid = c.lsquic_cid_t;
pub const StreamId = u64;

pub const ConnectionContext = c.lsquic_conn_ctx_t;

pub const StreamContext = struct {};
const c = @cImport({
    @cInclude("lsquic.h");
    @cInclude("lsquic_types.h");
    @cInclude("lsxpack_header.h");
});
