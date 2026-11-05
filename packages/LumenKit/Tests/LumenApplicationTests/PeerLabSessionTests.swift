@testable import LumenApplication
import LumenDomain
import Testing

private actor FakeLink: PeerLinkPort {
    nonisolated let events = AsyncStream<PeerEvent> { _ in }
    private(set) var sent: [PeerMessage] = []

    func start() async -> Bool {
        true
    }

    func send(_ message: PeerMessage) async {
        sent.append(message)
    }
}

private struct FakeClock: ClockPort {
    let now: UInt64

    func nowNanoseconds() -> UInt64 {
        now
    }
}

private actor FakeChirpPlayer: ChirpPlayerPort {
    private(set) var amplitudes: [Float] = []

    private(set) var toneChannels: [AudioChannel] = []

    func playPair(amplitude: Float) async {
        amplitudes.append(amplitude)
    }

    func playTestTone(on channel: AudioChannel) async {
        toneChannels.append(channel)
    }
}

private struct FakeRoute: AudioRoutePort {
    let canPlay: Bool

    func canPlayUltrasound() async -> Bool {
        canPlay
    }
}

private actor FakePlacementStore: PlacementStorePort {
    private(set) var saved: PlacementDistribution?

    func load() async -> PlacementDistribution? {
        nil
    }

    func save(_ distribution: PlacementDistribution) async {
        saved = distribution
    }
}

private actor FakeFileSink: FileSinkPort {
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

private func makeSession(
    link: FakeLink = FakeLink(),
    player: FakeChirpPlayer = FakeChirpPlayer(),
    canPlay: Bool = true,
    store: FakePlacementStore = FakePlacementStore(),
    sink: FakeFileSink = FakeFileSink(),
    now: UInt64 = 0
) -> PeerLabSession {
    PeerLabSession(
        link: link,
        clock: FakeClock(now: now),
        chirpPlayer: player,
        audioRoute: FakeRoute(canPlay: canPlay),
        placementStore: store,
        fileSink: sink,
        chirpAmplitude: 0.25
    )
}

@Test func answersClockPingsWithItsOwnTime() async {
    let link = FakeLink()
    let session = makeSession(link: link, now: 500)
    await session.handle(.received(.clockPing(originNs: 7)))
    #expect(await link.sent == [.clockPong(originNs: 7, receiveNs: 500, transmitNs: 500)])
}

@Test func playsChirpsAtTheCurrentAmplitude() async {
    let player = FakeChirpPlayer()
    let session = makeSession(player: player)
    await session.setChirpAmplitude(0.5)
    await session.handle(.received(.playChirpPair(requestID: 1)))
    #expect(await player.amplitudes == [0.5])
}

@Test func playsTestTonesOnTheRequestedChannel() async {
    let player = FakeChirpPlayer()
    let session = makeSession(player: player)
    await session.playTestTone(on: .right)
    #expect(await player.toneChannels == [.right])
}

@Test func skipsChirpsWhenTheSpeakersAreNotUsable() async {
    let player = FakeChirpPlayer()
    let session = makeSession(player: player, canPlay: false)
    await session.handle(.received(.playChirpPair(requestID: 1)))
    #expect(await player.amplitudes.isEmpty)
}

@Test func anEdgeExitUpdatesThePhoneAndTheStore() async {
    let link = FakeLink()
    let store = FakePlacementStore()
    let session = makeSession(link: link, store: store)
    await session.handle(.received(.edgeExit(.right)))
    let sent = await link.sent
    guard case let .placementUpdate(placement)? = sent.last else {
        Issue.record("expected a placement update")
        return
    }
    #expect(placement.side == .left)
    #expect(await store.saved != nil)
}

@Test func settlingAsksThePhoneToLocateOnlyWhenChirpsCanPlay() async {
    let usable = FakeLink()
    await makeSession(link: usable).handle(.received(.motionSettled))
    #expect(await usable.sent.contains(.beginLocate))

    let silent = FakeLink()
    await makeSession(link: silent, canPlay: false).handle(.received(.motionSettled))
    #expect(await !silent.sent.contains(.beginLocate))
}

@Test func anAcousticReportMovesThePlacement() async {
    let link = FakeLink()
    let reading = AcousticReading(
        requestID: 1,
        tauMicroseconds: -220,
        levelDifferenceDecibels: -9,
        snrDecibels: 40,
        acceptedPairs: 3
    )
    await makeSession(link: link).handle(.received(.acousticReport(reading)))
    guard case let .placementUpdate(placement)? = await link.sent.last else {
        Issue.record("expected a placement update")
        return
    }
    #expect(placement.side == .right)
    #expect(placement.confidence >= 0.8)
}

@Test func offersAndCancelsReachTheFileSink() async {
    let sink = FakeFileSink()
    let session = makeSession(sink: sink)
    let offer = TransferOffer(transferID: 3, resources: [])
    await session.handle(.received(.transferOffer(offer)))
    await session.handle(.received(.transferCancel(transferID: 3)))
    #expect(await sink.offers == [offer])
    #expect(await sink.cancelled == [3])
}
