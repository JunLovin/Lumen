public extension PeerLabSession {
    func sendFiles(paths: [String]) async {
        guard let offer = await fileSource.prepareBatch(paths: paths, isDirect: true) else { return }
        updatesContinuation.yield(.sendingFiles(offer))
        guard isConnected else {
            waitingOffers.append(offer)
            updatesContinuation.yield(.waitingOffers(count: waitingOffers.count))
            return
        }
        await link.send(.transferOffer(offer))
    }

    func sendTuning(name: String, value: Float) async {
        await link.send(.tuneToken(name: name, value: value))
    }

    internal func sendWaitingOffers() async {
        let offers = waitingOffers
        waitingOffers = []
        updatesContinuation.yield(.waitingOffers(count: 0))
        for offer in offers {
            await link.send(.transferOffer(offer))
        }
    }
}
