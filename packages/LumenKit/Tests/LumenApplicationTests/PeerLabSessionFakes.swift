@testable import LumenApplication
import LumenDomain

actor FakeLink: PeerLinkPort {
    nonisolated let events = AsyncStream<PeerEvent> { _ in }
    private(set) var sent: [PeerMessage] = []

    func start() async -> Bool {
        true
    }

    func send(_ message: PeerMessage) async {
        sent.append(message)
    }
}

struct FakeClock: ClockPort {
    let now: UInt64

    func nowNanoseconds() -> UInt64 {
        now
    }
}

actor FakeChirpPlayer: ChirpPlayerPort {
    private(set) var amplitudes: [Float] = []

    private(set) var toneChannels: [AudioChannel] = []

    func playPair(amplitude: Float) async {
        amplitudes.append(amplitude)
    }

    func playTestTone(on channel: AudioChannel) async {
        toneChannels.append(channel)
    }
}

struct FakeRoute: AudioRoutePort {
    let canPlay: Bool

    func canPlayUltrasound() async -> Bool {
        canPlay
    }
}

actor FakePlacementStore: PlacementStorePort {
    private(set) var saved: PlacementDistribution?

    func load() async -> PlacementDistribution? {
        nil
    }

    func save(_ distribution: PlacementDistribution) async {
        saved = distribution
    }
}

actor FakeFileSink: FileSinkPort {
    nonisolated let updates = AsyncStream<TransferUpdate> { _ in }
    private(set) var offers: [TransferOffer] = []
    private(set) var cancelled: [UInt32] = []

    func register(_ offer: TransferOffer) async {
        offers.append(offer)
    }

    func resumeOffset(transferID _: UInt32, resourceIndex _: UInt32) async -> UInt64? {
        0
    }

    func append(_: [UInt8], transferID _: UInt32, resourceIndex _: UInt32) async -> Bool {
        true
    }

    func finish(transferID _: UInt32, resourceIndex _: UInt32, sha256 _: [UInt8]) async -> Bool {
        true
    }

    func cancel(transferID: UInt32) async {
        cancelled.append(transferID)
    }
}

actor FakeFileSource: FileSourcePort {
    private(set) var discarded: [UInt32] = []

    func prepareBatch(paths: [String], isDirect: Bool) async -> TransferOffer? {
        paths.isEmpty ? nil : TransferOffer(transferID: 5, resources: [], isDirect: isDirect)
    }

    func discard(transferID: UInt32) async {
        discarded.append(transferID)
    }
}

func makeSession(
    link: FakeLink = FakeLink(),
    player: FakeChirpPlayer = FakeChirpPlayer(),
    canPlay: Bool = true,
    store: FakePlacementStore = FakePlacementStore(),
    sink: FakeFileSink = FakeFileSink(),
    source: FakeFileSource = FakeFileSource(),
    now: UInt64 = 0
) -> PeerLabSession {
    PeerLabSession(
        link: link,
        clock: FakeClock(now: now),
        chirpPlayer: player,
        audioRoute: FakeRoute(canPlay: canPlay),
        placementStore: store,
        fileSink: sink,
        fileSource: source,
        chirpAmplitude: 0.25
    )
}
