import CoreBluetooth
import LumenApplication

/// Unchecked: every property is touched only on `queue`, which CoreBluetooth also uses for callbacks.
public final class MacProximityScanner: NSObject, ProximityPort, CBCentralManagerDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "lumen.proximity.scanner")
    private var manager: CBCentralManager?
    private var continuation: AsyncStream<Int>.Continuation?

    override public init() {
        super.init()
    }

    public func rssiReadings() async -> AsyncStream<Int> {
        let (stream, continuation) = AsyncStream.makeStream(of: Int.self, bufferingPolicy: .bufferingNewest(1))
        queue.async {
            self.continuation = continuation
            if let manager = self.manager {
                self.scan(on: manager)
            } else {
                self.manager = CBCentralManager(delegate: self, queue: self.queue)
            }
        }
        return stream
    }

    public func stop() async {
        queue.async {
            self.manager?.stopScan()
            self.continuation?.finish()
            self.continuation = nil
        }
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        scan(on: central)
    }

    public func centralManager(
        _: CBCentralManager,
        didDiscover _: CBPeripheral,
        advertisementData _: [String: Any],
        rssi RSSI: NSNumber
    ) {
        continuation?.yield(RSSI.intValue)
    }

    private func scan(on central: CBCentralManager) {
        guard central.state == .poweredOn, continuation != nil else { return }
        central.scanForPeripherals(
            withServices: [CBUUID(string: ProximityService.uuid)],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }
}
