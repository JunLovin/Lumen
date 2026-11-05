import Foundation
import LumenApplication
import LumenDomain
import LumenProtocol

public enum WireCodec {
    public static func encodeDatagram(_ sample: DragFrameSample) -> Data? {
        var datagram = Lumen_Datagram()
        datagram.message = .dragFrame(wire(sample))
        return try? datagram.serializedData()
    }

    public static func decodeDatagram(_ data: Data) -> PeerMessage? {
        guard let message = try? Lumen_Datagram(serializedBytes: data).message else { return nil }
        switch message {
        case let .hello(hello):
            return .hello(ProtocolVersion(rawValue: Int32(hello.protocolVersion.rawValue)))
        case let .dragFrame(frame):
            return .dragFrame(domain(frame))
        }
    }

    public static func encodeControl(_ message: PeerMessage) -> Data? {
        guard let wireMessage = wire(message) else { return nil }
        var control = Lumen_ControlMessage()
        control.message = wireMessage
        return try? control.serializedData()
    }

    public static func decodeControl(_ data: Data) -> PeerMessage? {
        guard let message = try? Lumen_ControlMessage(serializedBytes: data).message else { return nil }
        switch message {
        case let .clockPing(ping):
            return .clockPing(originNs: ping.originNs)
        case let .clockPong(pong):
            return .clockPong(originNs: pong.originNs, receiveNs: pong.receiveNs, transmitNs: pong.transmitNs)
        case let .playChirpPair(request):
            return .playChirpPair(requestID: request.requestID)
        case let .acousticReport(report):
            return .acousticReport(AcousticReading(
                requestID: report.requestID,
                tauMicroseconds: report.tauUs,
                levelDifferenceDecibels: report.levelDifferenceDb,
                snrDecibels: report.snrDb,
                acceptedPairs: report.acceptedPairs
            ))
        case .motionSettled:
            return .motionSettled
        case .beginLocate:
            return .beginLocate
        case let .edgeExit(exit):
            return PhoneEdge(rawValue: exit.edge.rawValue).map { .edgeExit($0) }
        case let .placementUpdate(update):
            return .placementUpdate(domain(update))
        case let .dragBegan(began):
            return .dragBegan(DragStart(
                session: began.session,
                thumbnailJPEG: Array(began.thumbnailJpeg),
                phoneHeightMillimeters: began.phoneHeightMm
            ))
        case let .dragEnded(ended):
            return .dragEnded(DragEnd(
                session: ended.session,
                crossed: ended.crossed,
                velocityXMillimetersPerSecond: ended.velocityXMmS,
                velocityYMillimetersPerSecond: ended.velocityYMmS
            ))
        case let .landed(landed):
            return .landed(session: landed.session)
        case .hello, .sessionKey, .sessionReady, .incompatibleVersion:
            return nil
        }
    }

    private static func wire(_ message: PeerMessage) -> Lumen_ControlMessage.OneOf_Message? {
        switch message {
        case let .clockPing(originNs):
            .clockPing(.with { $0.originNs = originNs })
        case let .clockPong(originNs, receiveNs, transmitNs):
            .clockPong(.with {
                $0.originNs = originNs
                $0.receiveNs = receiveNs
                $0.transmitNs = transmitNs
            })
        case let .playChirpPair(requestID):
            .playChirpPair(.with { $0.requestID = requestID })
        case let .acousticReport(reading):
            .acousticReport(.with {
                $0.requestID = reading.requestID
                $0.tauUs = reading.tauMicroseconds
                $0.levelDifferenceDb = reading.levelDifferenceDecibels
                $0.snrDb = reading.snrDecibels
                $0.acceptedPairs = reading.acceptedPairs
            })
        case .motionSettled:
            .motionSettled(Lumen_MotionSettled())
        case .beginLocate:
            .beginLocate(Lumen_BeginLocate())
        case let .edgeExit(edge):
            .edgeExit(.with { $0.edge = Lumen_PhoneEdge(rawValue: edge.rawValue) ?? .top })
        case let .placementUpdate(placement):
            .placementUpdate(.with {
                $0.side = Lumen_PlacementSide(rawValue: placement.side.rawValue) ?? .unknown
                $0.confidence = Float(placement.confidence)
                $0.probabilities = placement.distribution.probabilities.map { Float($0) }
                $0.isDetached = placement.isDetached
            })
        case let .dragBegan(start):
            .dragBegan(.with {
                $0.session = start.session
                $0.thumbnailJpeg = Data(start.thumbnailJPEG)
                $0.phoneHeightMm = start.phoneHeightMillimeters
            })
        case let .dragEnded(end):
            .dragEnded(.with {
                $0.session = end.session
                $0.crossed = end.crossed
                $0.velocityXMmS = end.velocityXMillimetersPerSecond
                $0.velocityYMmS = end.velocityYMillimetersPerSecond
            })
        case let .landed(session):
            .landed(.with { $0.session = session })
        case .hello, .dragFrame:
            nil
        }
    }

    private static func domain(_ update: Lumen_PlacementUpdate) -> Placement {
        Placement(
            side: PlacementSide(rawValue: update.side.rawValue) ?? .unknown,
            confidence: Double(update.confidence),
            distribution: PlacementDistribution(probabilities: update.probabilities.map { Double($0) }),
            isDetached: update.isDetached
        )
    }

    private static func wire(_ sample: DragFrameSample) -> Lumen_DragFrame {
        .with {
            $0.session = sample.session
            $0.sequence = sample.sequence
            $0.timestampNs = sample.timestampNs
            $0.xMm = sample.xMillimeters
            $0.yMm = sample.yMillimeters
            $0.velocityXMmS = sample.velocityXMillimetersPerSecond
            $0.velocityYMmS = sample.velocityYMillimetersPerSecond
            $0.edgeProximity = sample.edgeProximity
            $0.objectWidthMm = sample.objectWidthMillimeters
            $0.objectHeightMm = sample.objectHeightMillimeters
            $0.rotationRad = sample.rotationRadians
            $0.edge = Lumen_PhoneEdge(rawValue: sample.edge.rawValue) ?? .top
        }
    }

    private static func domain(_ frame: Lumen_DragFrame) -> DragFrameSample {
        DragFrameSample(
            session: frame.session,
            sequence: frame.sequence,
            timestampNs: frame.timestampNs,
            xMillimeters: frame.xMm,
            yMillimeters: frame.yMm,
            velocityXMillimetersPerSecond: frame.velocityXMmS,
            velocityYMillimetersPerSecond: frame.velocityYMmS,
            edgeProximity: frame.edgeProximity,
            objectWidthMillimeters: frame.objectWidthMm,
            objectHeightMillimeters: frame.objectHeightMm,
            rotationRadians: frame.rotationRad,
            edge: PhoneEdge(rawValue: frame.edge.rawValue) ?? .top
        )
    }
}
