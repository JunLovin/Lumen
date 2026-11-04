@testable import LumenApplication
import LumenDomain
import Testing

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

@Test func droppedFilesAreOfferedToThePhone() async {
    let link = FakeLink()
    await makeSession(link: link).sendFiles(paths: ["/tmp/a.pdf"])
    #expect(await link.sent == [.transferOffer(TransferOffer(transferID: 5, resources: [], isDirect: true))])
}

@Test func nothingIsOfferedWithoutFiles() async {
    let link = FakeLink()
    await makeSession(link: link).sendFiles(paths: [])
    #expect(await link.sent.isEmpty)
}

@Test func aCancelFromThePhoneDiscardsTheOutgoingBatch() async {
    let source = FakeFileSource()
    await makeSession(source: source).handle(.received(.transferCancel(transferID: 8)))
    #expect(await source.discarded == [8])
}
