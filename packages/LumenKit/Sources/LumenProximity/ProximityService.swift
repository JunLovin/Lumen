public enum ProximityService {
    public static let uuid = "6F1B4A52-8C3D-4E7A-9B21-5D0C7E3A1F48"
    /// Roughly "almost touching" on an iPhone 14 next to a MacBook Air; calibrated on hardware.
    public static let nearRSSI = -50
    public static let nearDwellNanoseconds: UInt64 = 1_000_000_000
}
