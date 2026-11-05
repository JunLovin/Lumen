public struct MacPoint: Sendable, Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct MacSpace: Sendable, Equatable {
    public let widthPoints: Double
    public let heightPoints: Double
    public let pointsPerMillimeter: Double
    public let entryStripFraction: Double

    public init(widthPoints: Double, heightPoints: Double, pointsPerMillimeter: Double, entryStripFraction: Double) {
        self.widthPoints = widthPoints
        self.heightPoints = heightPoints
        self.pointsPerMillimeter = pointsPerMillimeter
        self.entryStripFraction = entryStripFraction
    }

    /// World x is millimeters past the shared edge, toward the Mac. World y maps by relative
    /// height onto a strip of the Mac's edge, because the two screens have different heights.
    public func point(worldX: Double, worldY: Double, phoneHeightMillimeters: Double, edge: PhoneEdge) -> MacPoint {
        let depth = worldX * pointsPerMillimeter
        let relativeY = phoneHeightMillimeters > 0 ? worldY / phoneHeightMillimeters : 0.5
        let stripHeight = heightPoints * entryStripFraction
        let stripTop = (heightPoints - stripHeight) / 2
        return MacPoint(
            x: edge == .right ? depth : widthPoints - depth,
            y: stripTop + relativeY * stripHeight
        )
    }

    public func size(millimeters: Double) -> Double {
        millimeters * pointsPerMillimeter
    }

    public func depthSign(edge: PhoneEdge) -> Double {
        edge == .right ? 1 : -1
    }
}
