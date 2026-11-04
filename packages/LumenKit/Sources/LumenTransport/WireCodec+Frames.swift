import Foundation
import LumenDomain
import LumenProtocol

extension WireCodec {
    static func wire(_ sample: DragFrameSample) -> Lumen_DragFrame {
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

    static func domain(_ frame: Lumen_DragFrame) -> DragFrameSample {
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
