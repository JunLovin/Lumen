#if os(macOS)
    import Foundation
    import LumenApplication
    import LumenDomain

    public struct UserDefaultsPlacementStore: PlacementStorePort {
        private static let key = "lumen.placement.distribution"

        public init() {}

        public func load() async -> PlacementDistribution? {
            guard let data = UserDefaults.standard.data(forKey: Self.key) else { return nil }
            return try? JSONDecoder().decode(PlacementDistribution.self, from: data)
        }

        public func save(_ distribution: PlacementDistribution) async {
            guard let data = try? JSONEncoder().encode(distribution) else { return }
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
#endif
