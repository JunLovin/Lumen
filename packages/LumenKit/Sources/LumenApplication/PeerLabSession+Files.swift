extension PeerLabSession {
    public func sendFiles(paths: [String]) async {
        guard let offer = await fileSource.prepareBatch(paths: paths, isDirect: true) else { return }
        updatesContinuation.yield(.sendingFiles(offer))
        guard isConnected else {
            waitingOffers.append(offer)
            return
        }
        await link.send(.transferOffer(offer))
    }

    func sendWaitingOffers() async {
        let offers = waitingOffers
        waitingOffers = []
        for offer in offers {
            await link.send(.transferOffer(offer))
        }
    }
}
