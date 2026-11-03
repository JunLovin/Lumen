public struct LocalIdentity: Sendable, Equatable, Codable {
    public let deviceID: [UInt8]
    public let name: String
    public let signingPrivateKey: [UInt8]
    public let signingPublicKey: [UInt8]

    public init(deviceID: [UInt8], name: String, signingPrivateKey: [UInt8], signingPublicKey: [UInt8]) {
        self.deviceID = deviceID
        self.name = name
        self.signingPrivateKey = signingPrivateKey
        self.signingPublicKey = signingPublicKey
    }
}

public struct PairedDevice: Sendable, Equatable, Codable {
    public let deviceID: [UInt8]
    public let name: String
    public let signingPublicKey: [UInt8]
    public let pairingSecret: [UInt8]

    public init(deviceID: [UInt8], name: String, signingPublicKey: [UInt8], pairingSecret: [UInt8]) {
        self.deviceID = deviceID
        self.name = name
        self.signingPublicKey = signingPublicKey
        self.pairingSecret = pairingSecret
    }
}
