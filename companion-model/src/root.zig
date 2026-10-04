const model = @import("layout-model");
const protocol = @import("device-protocol");

pub const State = struct {
    dimensions: model.KeymapDimensions,
    pressed: [128]bool = @splat(false),
    active_layers: u16 = 1,
    highest_layer: model.LayerIndex = 0,
    modifiers: model.Modifiers = .{},
    last_sequence: ?u16 = null,
    needs_resync: bool = false,

    pub fn init(dimensions: model.KeymapDimensions) protocol.ProtocolError!State {
        try protocol.validate(.{ .sequence = 0, .event = .{ .layers = .{ .active_layers = 1, .highest_layer = 0, .modifiers = .{} } } }, dimensions);
        return .{ .dimensions = dimensions };
    }

    pub fn apply(self: *State, message: protocol.Message) !void {
        try protocol.validate(message, self.dimensions);
        if (self.needs_resync) return error.ResyncRequired;
        if (self.last_sequence) |last| {
            if (message.sequence != last +% 1) {
                self.needs_resync = true;
                return error.SequenceDiscontinuity;
            }
        }
        switch (message.event) {
            .key => |key| {
                self.pressed[key.key_index] = key.pressed;
                self.modifiers = key.modifiers;
            },
            .layers => |layers| {
                self.active_layers = layers.active_layers;
                self.highest_layer = layers.highest_layer;
                self.modifiers = layers.modifiers;
            },
        }
        self.last_sequence = message.sequence;
    }

    pub fn receive(self: *State, bytes: []const u8) !void {
        try self.apply(try protocol.decode(bytes, self.dimensions));
    }
};

pub const Phase = enum { disconnected, negotiating, synchronizing, live, recovering, incompatible };
pub const Action = union(enum) { send: protocol.Packet, signal: protocol.SignalKind };
pub const Actions = struct {
    items: [2]Action = undefined,
    count: u2 = 0,
    pub fn slice(self: *const Actions) []const Action {
        return self.items[0..self.count];
    }
    fn add(self: *Actions, action: Action) void {
        self.items[self.count] = action;
        self.count += 1;
    }
};
pub const timeout_ms = 500;
pub const refresh_ms = 1000;
pub const max_attempts = 3;
pub const pending_capacity = 8;

/// Pure bounded live-session reducer. All times are monotonic milliseconds.
pub const Session = struct {
    expected: protocol.Identity,
    state: State,
    phase: Phase = .disconnected,
    stale: bool = true,
    token: u32 = 0,
    request_counter: u16 = 0,
    request: u16 = 0,
    attempts: u8 = 0,
    deadline: u64 = 0,
    refresh_at: u64 = 0,
    exhausted: bool = false,
    identity_body: [38]u8 = @splat(0),
    identity_seen: u3 = 0,
    snapshot_body: [20]u8 = @splat(0),
    snapshot_seen: u2 = 0,
    boundary: ?u16 = null,
    pending: [pending_capacity]protocol.Packet = undefined,
    pending_count: u4 = 0,
    expected_sequence: u16 = 0,
    last_error: ?protocol.ProtocolError = null,

    pub fn init(expected: protocol.Identity) protocol.ProtocolError!Session {
        try protocol.validateIdentity(expected);
        return .{ .expected = expected, .state = try State.init(expected.dimensions) };
    }
    fn clearAssembly(self: *Session) void {
        self.identity_seen = 0;
        self.snapshot_seen = 0;
        self.boundary = null;
        self.pending_count = 0;
    }
    pub fn disconnect(self: *Session) void {
        self.phase = .disconnected;
        self.stale = true;
        self.state.needs_resync = true;
        self.token = 0;
        self.exhausted = false;
        self.clearAssembly();
    }
    fn hello(self: *Session, now: u64, nonce: u32) Actions {
        self.token = nonce;
        self.request_counter = 1;
        self.request = 1;
        self.phase = .negotiating;
        self.stale = true;
        self.state.needs_resync = true;
        self.attempts = 1;
        self.deadline = now +| timeout_ms;
        self.exhausted = false;
        self.clearAssembly();
        var actions = Actions{};
        actions.add(.{ .send = .{ .session = 0, .request = self.request, .nonce = nonce, .payload = .hello } });
        return actions;
    }
    pub fn connect(self: *Session, now: u64, nonce: u32) protocol.ProtocolError!Actions {
        if (nonce == 0 or nonce == self.token) return error.InvalidSession;
        return self.hello(now, nonce);
    }
    fn allocateRequest(self: *Session, now: u64) bool {
        if (self.request_counter == 65535) {
            self.phase = .recovering;
            self.stale = true;
            self.state.needs_resync = true;
            self.exhausted = true;
            self.deadline = now;
            self.clearAssembly();
            return false;
        }
        self.request_counter += 1;
        self.request = self.request_counter;
        return true;
    }
    fn startSnapshot(self: *Session, now: u64, recovering: bool, retry: bool) Actions {
        var actions = Actions{};
        self.stale = true;
        self.state.needs_resync = true;
        self.clearAssembly();
        if (!self.allocateRequest(now)) return actions;
        self.phase = if (recovering) .recovering else .synchronizing;
        if (!retry) self.attempts = 1;
        self.deadline = now +| timeout_ms;
        self.exhausted = false;
        actions.add(.{ .send = .{ .session = self.token, .request = self.request, .payload = .snapshot_request } });
        return actions;
    }
    fn failTransaction(self: *Session, now: u64) Actions {
        if (self.attempts >= max_attempts) {
            self.stale = true;
            self.state.needs_resync = true;
            self.phase = .recovering;
            self.exhausted = true;
            self.deadline = now +| refresh_ms;
            self.clearAssembly();
            return .{};
        }
        self.attempts += 1;
        if (self.phase == .negotiating) {
            var actions = Actions{};
            self.clearAssembly();
            if (!self.allocateRequest(now)) return actions;
            self.phase = .negotiating;
            self.deadline = now +| timeout_ms;
            actions.add(.{ .send = .{ .session = 0, .request = self.request, .nonce = self.token, .payload = .hello } });
            return actions;
        }
        return self.startSnapshot(now, true, true);
    }
    pub fn tick(self: *Session, now: u64, fresh_nonce: u32) protocol.ProtocolError!Actions {
        switch (self.phase) {
            .disconnected, .incompatible => return .{},
            .live => if (now >= self.refresh_at) return self.startSnapshot(now, false, false),
            .negotiating, .synchronizing, .recovering => {
                if (now < self.deadline) return .{};
                if (self.exhausted) {
                    if (fresh_nonce == 0 or fresh_nonce == self.token) return error.InvalidSession;
                    return self.hello(now, fresh_nonce);
                }
                return self.failTransaction(now);
            },
        }
        return .{};
    }
    fn malformed(self: *Session, now: u64, err: protocol.ProtocolError) Actions {
        self.last_error = err;
        if (err == error.UnsupportedVersion and self.phase != .disconnected) {
            self.phase = .incompatible;
            self.stale = true;
            self.state.needs_resync = true;
            self.clearAssembly();
            return .{};
        }
        return switch (self.phase) {
            .live => self.startSnapshot(now, true, false),
            .negotiating, .synchronizing, .recovering => if (self.exhausted) .{} else self.failTransaction(now),
            .disconnected, .incompatible => .{},
        };
    }
    /// Framing errors are recorded and trigger recovery actions, rather than escaping
    /// before an adapter has a chance to mark the displayed model stale.
    pub fn receive(self: *Session, bytes: []const u8, now: u64) Actions {
        const packet = protocol.decodePacket(bytes, self.expected.dimensions, .device_to_host) catch |err| return self.malformed(now, err);
        return self.apply(packet, now);
    }
    pub fn apply(self: *Session, packet: protocol.Packet, now: u64) Actions {
        protocol.validatePacket(packet, self.expected.dimensions, .device_to_host) catch |err| return self.malformed(now, err);
        if (self.phase == .disconnected or self.phase == .incompatible or self.exhausted or packet.session != self.token) return .{};
        switch (packet.payload) {
            .identity => |part| {
                if (self.phase != .negotiating or packet.request != self.request) return .{};
                const bit = @as(u3, 1) << @as(u2, @intCast(part.index));
                const length: usize = if (part.index == 2) 6 else 16;
                const destination = self.identity_body[@as(usize, part.index) * 16 ..][0..length];
                if (self.identity_seen & bit != 0) {
                    if (!@import("std").mem.eql(u8, destination, part.bytes[0..length])) return self.failTransaction(now);
                    return .{};
                }
                @memcpy(destination, part.bytes[0..length]);
                self.identity_seen |= bit;
                if (self.identity_seen != 7) return .{};
                const identity = protocol.decodeIdentityBody(self.identity_body, self.token) catch |err| return self.malformed(now, err);
                if (!@import("std").meta.eql(identity, self.expected)) {
                    self.phase = .incompatible;
                    self.stale = true;
                    self.state.needs_resync = true;
                    self.clearAssembly();
                    return .{};
                }
                return self.startSnapshot(now, false, false);
            },
            .snapshot => |part| {
                if ((self.phase != .synchronizing and self.phase != .recovering) or packet.request != self.request) return .{};
                if (self.boundary) |boundary| {
                    if (boundary != packet.sequence) return self.failTransaction(now);
                } else self.boundary = packet.sequence;
                const bit = @as(u2, 1) << @as(u1, @intCast(part.index));
                const destination = self.snapshot_body[@as(usize, part.index) * 10 ..][0..10];
                if (self.snapshot_seen & bit != 0) {
                    if (!@import("std").mem.eql(u8, destination, &part.bytes)) return self.failTransaction(now);
                    return .{};
                }
                @memcpy(destination, &part.bytes);
                self.snapshot_seen |= bit;
                if (self.snapshot_seen != 3) return .{};
                return self.commitSnapshot(now);
            },
            .key, .layers, .signal => {
                if (self.phase == .live) return self.liveDelta(packet, now);
                if (self.phase == .synchronizing or self.phase == .recovering) {
                    if (self.pending_count == pending_capacity) return self.failTransaction(now);
                    self.pending[self.pending_count] = packet;
                    self.pending_count += 1;
                }
                return .{};
            },
            .recovery => {
                if (self.phase == .negotiating) return .{};
                if (self.phase == .live) return self.startSnapshot(now, true, false);
                return self.failTransaction(now);
            },
            .hello, .snapshot_request => unreachable,
        }
    }
    fn applyDelta(candidate: *State, packet: protocol.Packet) void {
        switch (packet.payload) {
            .key => |key| {
                candidate.pressed[key.key_index] = key.pressed;
                candidate.modifiers = key.modifiers;
            },
            .layers => |layers| {
                candidate.active_layers = layers.active_layers;
                candidate.highest_layer = layers.highest_layer;
                candidate.modifiers = layers.modifiers;
            },
            .signal => {},
            else => unreachable,
        }
        candidate.last_sequence = packet.sequence;
    }
    fn commitSnapshot(self: *Session, now: u64) Actions {
        const snapshot = protocol.decodeSnapshotBody(self.snapshot_body, self.expected.dimensions) catch |err| return self.malformed(now, err);
        var candidate = State.init(self.expected.dimensions) catch unreachable;
        for (&candidate.pressed, 0..) |*pressed, index| pressed.* = snapshot.pressed[index / 8] & (@as(u8, 1) << @as(u3, @intCast(index % 8))) != 0;
        candidate.active_layers = snapshot.active_layers;
        candidate.highest_layer = snapshot.highest_layer;
        candidate.modifiers = snapshot.modifiers;
        var next = self.boundary.?;
        candidate.last_sequence = next -% 1;
        // A bounded Actions return cannot execute more than two pending signals.
        // Signal intent overflow invalidates the entire candidate atomically.
        var actions = Actions{};
        for (self.pending[0..self.pending_count]) |packet| {
            const difference = packet.sequence -% next;
            if (difference > 32768) continue;
            if (difference != 0) return self.failTransaction(now);
            applyDelta(&candidate, packet);
            next +%= 1;
            if (packet.payload == .signal and packet.payload.signal.pressed) {
                if (actions.count == 2) return self.failTransaction(now);
                actions.add(.{ .signal = packet.payload.signal.kind });
            }
        }
        self.state = candidate;
        self.expected_sequence = next;
        self.phase = .live;
        self.stale = false;
        self.exhausted = false;
        self.refresh_at = now +| refresh_ms;
        self.clearAssembly();
        return actions;
    }
    fn liveDelta(self: *Session, packet: protocol.Packet, now: u64) Actions {
        const difference = packet.sequence -% self.expected_sequence;
        if (difference > 32768) return .{};
        if (difference != 0) return self.startSnapshot(now, true, false);
        applyDelta(&self.state, packet);
        self.expected_sequence +%= 1;
        var actions = Actions{};
        if (packet.payload == .signal and packet.payload.signal.pressed) actions.add(.{ .signal = packet.payload.signal.kind });
        return actions;
    }
};
