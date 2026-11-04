import Foundation
import LumenDomain

public extension LumenKitBridge {
    @objc func placementStatus(_ completion: @escaping @Sendable (NSDictionary) -> Void) {
        let session = session
        Task {
            let placement = await session.placement
            let edge = await session.facingEdge
            let failure = await session.locationFailure
            var status: [String: Any] = [
                "side": placement?.side.rawValue ?? PlacementSide.unknown.rawValue,
                "confidence": placement?.confidence ?? 0,
                "probabilities": placement?.distribution.probabilities ?? PlacementDistribution.uncertain.probabilities,
                "isDetached": placement?.isDetached ?? false,
                "facingEdge": edge?.rawValue ?? -1,
            ]
            if let failure {
                status["locationFailure"] = failure
            }
            if let locateMilliseconds = await session.lastLocateMilliseconds {
                status["locateMilliseconds"] = locateMilliseconds
            }
            completion(status as NSDictionary)
        }
    }
}
