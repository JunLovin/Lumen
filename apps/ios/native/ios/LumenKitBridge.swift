import Foundation
import LumenApplication
import LumenDomain
import LumenSignal
import LumenTransport

@objc(LumenKitBridge)
public final class LumenKitBridge: NSObject, @unchecked Sendable {
    let session = LabSession()
    let media = MediaLibrary()
    private let haptics = Haptics()

    @objc public static func protocolVersion() -> Int32 {
        ProtocolInfoAdapter().localProtocolVersion.rawValue
    }

    @objc public static func deviceModel() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }

    @objc public func endDrag(session frameSession: Int32, crossed: Bool, velocityX: Float, velocityY: Float) {
        let session = session
        let end = DragEnd(
            session: UInt32(bitPattern: frameSession),
            crossed: crossed,
            velocityXMillimetersPerSecond: velocityX,
            velocityYMillimetersPerSecond: velocityY
        )
        Task {
            await session.send(.dragEnded(end))
            if crossed {
                await session.transfers.start(transferID: end.session)
            } else {
                await session.transfers.cancel(transferID: end.session)
            }
        }
    }

    @objc public func startUpload(session frameSession: Int32) {
        let transfers = session.transfers
        Task { await transfers.start(transferID: UInt32(bitPattern: frameSession)) }
    }

    @objc public func impact(style: Int) {
        haptics.impact(style: style)
    }

    @objc public func startLink() {
        let session = session
        Task { await session.start() }
    }

    @objc public func pairingStatus(_ completion: @escaping @Sendable (NSDictionary) -> Void) {
        let session = session
        Task { await completion(Self.dictionary(for: session.pairingStage)) }
    }

    @objc public func forgetPairing() {
        let session = session
        Task { await session.forgetPairing() }
    }

    @objc public func reconnect() {
        let session = session
        Task { await session.reconnect() }
    }

    @objc public func probeFileChannel(_ completion: @escaping @Sendable (Bool) -> Void) {
        let session = session
        Task { await completion(session.probeFileChannel()) }
    }

    private static func dictionary(for stage: PairingStage) -> NSDictionary {
        switch stage {
        case .idle:
            ["stage": "idle"]
        case .searching:
            ["stage": "searching"]
        case .exchanging:
            ["stage": "exchanging"]
        case let .awaitingConfirmation(pattern):
            ["stage": "awaitingConfirmation", "pattern": pattern.colorIndices]
        case let .paired(device):
            ["stage": "paired", "peerName": device.name]
        case .failed:
            ["stage": "failed"]
        }
    }

    @objc public func reportEdgeExit(_ edgeIndex: Int) {
        guard let edge = PhoneEdge(rawValue: edgeIndex) else { return }
        let session = session
        Task { await session.reportEdgeExit(edge) }
    }

    @objc public func linkStatus(_ completion: @escaping @Sendable (Bool) -> Void) {
        let session = session
        Task { await completion(session.connected) }
    }

    // swiftlint:disable:next function_parameter_count
    @objc public func sendDragFrame(
        session frameSession: Int32,
        sequence: Int32,
        ageMilliseconds: Double,
        xMillimeters: Float,
        yMillimeters: Float,
        velocityX: Float,
        velocityY: Float,
        edgeProximity: Float,
        objectWidth: Float,
        objectHeight: Float,
        rotation: Float,
        edge: Int
    ) {
        let age = UInt64(max(ageMilliseconds, 0) * 1_000_000)
        session.enqueue(DragFrameSample(
            session: UInt32(bitPattern: frameSession),
            sequence: UInt32(bitPattern: sequence),
            timestampNs: session.nowNanoseconds - age,
            xMillimeters: xMillimeters,
            yMillimeters: yMillimeters,
            velocityXMillimetersPerSecond: velocityX,
            velocityYMillimetersPerSecond: velocityY,
            edgeProximity: edgeProximity,
            objectWidthMillimeters: objectWidth,
            objectHeightMillimeters: objectHeight,
            rotationRadians: rotation,
            edge: PhoneEdge(rawValue: edge) ?? .right
        ))
    }

    @objc public func measurePlacement(
        resolve: @escaping @Sendable (NSDictionary) -> Void,
        reject: @escaping @Sendable (String) -> Void
    ) {
        let session = session
        Task {
            do {
                let measurement = try await session.measurePlacement()
                let estimate = measurement.estimate
                resolve([
                    "tauMicroseconds": estimate.tauSeconds * 1_000_000,
                    "levelDifferenceDecibels": estimate.levelDifferenceDecibels,
                    "snrDecibels": estimate.snrDecibels,
                    "acceptedPairs": estimate.acceptedPairs,
                    "pairs": measurement.pairs.map { pair in
                        [
                            "tauMicroseconds": pair.tauSeconds * 1_000_000,
                            "levelDifferenceDecibels": Double(pair.levelDifferenceDecibels),
                            "snrDecibels": Double(pair.snrDecibels),
                        ]
                    },
                    "curve": measurement.curve,
                ])
            } catch let error as PlacementError {
                reject(error.rawValue)
            } catch {
                reject(PlacementError.microphoneUnavailable.rawValue)
            }
        }
    }

    @objc public func exportLastRecording(
        resolve: @escaping @Sendable (String?) -> Void
    ) {
        #if DEBUG
            let session = session
            Task {
                let url = try? await session.exportLastRecording()
                resolve(url?.absoluteString)
            }
        #else
            resolve(nil)
        #endif
    }
}
