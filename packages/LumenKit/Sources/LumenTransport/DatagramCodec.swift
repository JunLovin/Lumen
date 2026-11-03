import Foundation
import LumenApplication
import LumenDomain
import LumenProtocol

public enum DatagramCodec {
    public static func encode(_ message: PeerMessage) -> Data? {
        var datagram = Lumen_Datagram()
        datagram.message = wire(message)
        return try? datagram.serializedData()
    }

    public static func decode(_ data: Data) -> PeerMessage? {
        guard let message = try? Lumen_Datagram(serializedBytes: data).message else { return nil }
        return domain(message)
    }

    private static func wire(_ message: PeerMessage) -> Lumen_Datagram.OneOf_Message {
        switch message {
        case let .hello(version):
            .hello(.with { $0.protocolVersion = .init(rawValue: Int(version.rawValue)) ?? .unspecified })
        case let .clockPing(originNs):
            .clockPing(.with { $0.originNs = originNs })
        case let .clockPong(originNs, receiveNs, transmitNs):
            .clockPong(.with {
                $0.originNs = originNs
                $0.receiveNs = receiveNs
                $0.transmitNs = transmitNs
            })
        case let .dragFrame(sample):
            .dragFrame(wire(sample))
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
        }
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
        }
    }

    private static func domain(_ message: Lumen_Datagram.OneOf_Message) -> PeerMessage {
        switch message {
        case let .hello(hello):
            .hello(ProtocolVersion(rawValue: Int32(hello.protocolVersion.rawValue)))
        case let .clockPing(ping):
            .clockPing(originNs: ping.originNs)
        case let .clockPong(pong):
            .clockPong(originNs: pong.originNs, receiveNs: pong.receiveNs, transmitNs: pong.transmitNs)
        case let .dragFrame(frame):
            .dragFrame(domain(frame))
        case let .playChirpPair(request):
            .playChirpPair(requestID: request.requestID)
        case let .acousticReport(report):
            .acousticReport(AcousticReading(
                requestID: report.requestID,
                tauMicroseconds: report.tauUs,
                levelDifferenceDecibels: report.levelDifferenceDb,
                snrDecibels: report.snrDb,
                acceptedPairs: report.acceptedPairs
            ))
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
            rotationRadians: frame.rotationRad
        )
    }
}
