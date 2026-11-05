import CoreBluetooth

/// Unchecked: every property is touched only on `queue`, which CoreBluetooth also uses for callbacks.
public final class PhoneProximityAdvertiser: NSObject, CBPeripheralManagerDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "lumen.proximity.advertiser")
    private var manager: CBPeripheralManager?
    private var wantsAdvertising = false

    override public init() {
        super.init()
    }

    public func start() {
        queue.async {
            self.wantsAdvertising = true
            if let manager = self.manager {
                self.advertise(on: manager)
            } else {
                self.manager = CBPeripheralManager(delegate: self, queue: self.queue)
            }
        }
    }

    public func stop() {
        queue.async {
            self.wantsAdvertising = false
            self.manager?.stopAdvertising()
        }
    }

    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        advertise(on: peripheral)
    }

    private func advertise(on manager: CBPeripheralManager) {
        guard wantsAdvertising, manager.state == .poweredOn, !manager.isAdvertising else { return }
        manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: ProximityService.uuid)],
        ])
    }
}
