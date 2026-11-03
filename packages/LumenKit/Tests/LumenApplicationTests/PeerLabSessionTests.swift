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

    func playPair(amplitude: Float) async {
        amplitudes.append(amplitude)
    }
}

@Test func answersClockPingsWithItsOwnTime() async {
    let link = FakeLink()
    let session = PeerLabSession(
        link: link,
        clock: FakeClock(now: 500),
        chirpPlayer: FakeChirpPlayer(),
        chirpAmplitude: 0.25
    )
    await session.handle(.received(.clockPing(originNs: 7)))
    #expect(await link.sent == [.clockPong(originNs: 7, receiveNs: 500, transmitNs: 500)])
}

@Test func playsChirpsAtTheCurrentAmplitude() async {
    let player = FakeChirpPlayer()
    let session = PeerLabSession(
        link: FakeLink(),
        clock: FakeClock(now: 0),
        chirpPlayer: player,
        chirpAmplitude: 0.25
    )
    await session.setChirpAmplitude(0.5)
    await session.handle(.received(.playChirpPair(requestID: 1)))
    #expect(await player.amplitudes == [0.5])
}
