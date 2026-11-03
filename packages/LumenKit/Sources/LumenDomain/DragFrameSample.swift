public struct DragFrameSample: Sendable, Equatable {
    public let session: UInt32
    public let sequence: UInt32
    public let timestampNs: UInt64
    public let xMillimeters: Float
    public let yMillimeters: Float
    public let velocityXMillimetersPerSecond: Float
    public let velocityYMillimetersPerSecond: Float
    public let edgeProximity: Float
    public let objectWidthMillimeters: Float
    public let objectHeightMillimeters: Float
    public let rotationRadians: Float
    public let edge: PhoneEdge

    public init(
        session: UInt32,
        sequence: UInt32,
        timestampNs: UInt64,
        xMillimeters: Float,
        yMillimeters: Float,
        velocityXMillimetersPerSecond: Float,
        velocityYMillimetersPerSecond: Float,
        edgeProximity: Float,
        objectWidthMillimeters: Float,
        objectHeightMillimeters: Float,
        rotationRadians: Float,
        edge: PhoneEdge
    ) {
        self.session = session
        self.sequence = sequence
        self.timestampNs = timestampNs
        self.xMillimeters = xMillimeters
        self.yMillimeters = yMillimeters
        self.velocityXMillimetersPerSecond = velocityXMillimetersPerSecond
        self.velocityYMillimetersPerSecond = velocityYMillimetersPerSecond
        self.edgeProximity = edgeProximity
        self.objectWidthMillimeters = objectWidthMillimeters
        self.objectHeightMillimeters = objectHeightMillimeters
        self.rotationRadians = rotationRadians
        self.edge = edge
    }
}

public struct DragStart: Sendable, Equatable {
    public let session: UInt32
    public let thumbnailJPEG: [UInt8]
    public let phoneHeightMillimeters: Float

    public init(session: UInt32, thumbnailJPEG: [UInt8], phoneHeightMillimeters: Float) {
        self.session = session
        self.thumbnailJPEG = thumbnailJPEG
        self.phoneHeightMillimeters = phoneHeightMillimeters
    }
}

public struct DragEnd: Sendable, Equatable {
    public let session: UInt32
    public let crossed: Bool
    public let velocityXMillimetersPerSecond: Float
    public let velocityYMillimetersPerSecond: Float

    public init(
        session: UInt32,
        crossed: Bool,
        velocityXMillimetersPerSecond: Float,
        velocityYMillimetersPerSecond: Float
    ) {
        self.session = session
        self.crossed = crossed
        self.velocityXMillimetersPerSecond = velocityXMillimetersPerSecond
        self.velocityYMillimetersPerSecond = velocityYMillimetersPerSecond
    }
}
