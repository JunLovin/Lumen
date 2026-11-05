import Foundation
import Network
import Security

enum SecureParameters {
    /// TLS_ECDHE_PSK_WITH_CHACHA20_POLY1305_SHA256. Network.framework refuses TLS 1.3 with an
    /// external pre-shared key, and this suite is the one that keeps forward secrecy.
    private static let streamCipherSuite: UInt16 = 0xCCAC
    private static let datagramCipherSuite: UInt16 = 0x00A8
    private static let pskIdentity = Data("lumen".utf8)

    static func plainStream() -> NWParameters {
        NWParameters(tls: nil, tcp: tcpOptions())
    }

    static func stream(psk: Data) -> NWParameters {
        NWParameters(tls: tlsOptions(psk: psk, version: .TLSv12, cipherSuite: streamCipherSuite), tcp: tcpOptions())
    }

    static func datagram(psk: Data) -> NWParameters {
        let parameters = NWParameters(
            dtls: tlsOptions(psk: psk, version: .DTLSv12, cipherSuite: datagramCipherSuite),
            udp: NWProtocolUDP.Options()
        )
        // Requests the Wi-Fi voice access category: drag frames were arriving in bursts at p95.
        parameters.serviceClass = .interactiveVoice
        return parameters
    }

    private static func tcpOptions() -> NWProtocolTCP.Options {
        let options = NWProtocolTCP.Options()
        options.noDelay = true
        return options
    }

    private static func tlsOptions(
        psk: Data,
        version: tls_protocol_version_t,
        cipherSuite: UInt16
    ) -> NWProtocolTLS.Options {
        let options = NWProtocolTLS.Options()
        let security = options.securityProtocolOptions
        let key = psk.withUnsafeBytes { DispatchData(bytes: $0) }
        let identity = pskIdentity.withUnsafeBytes { DispatchData(bytes: $0) }
        sec_protocol_options_add_pre_shared_key(security, key as __DispatchData, identity as __DispatchData)
        sec_protocol_options_set_min_tls_protocol_version(security, version)
        sec_protocol_options_set_max_tls_protocol_version(security, version)
        if let suite = tls_ciphersuite_t(rawValue: cipherSuite) {
            sec_protocol_options_append_tls_ciphersuite(security, suite)
        }
        return options
    }
}
