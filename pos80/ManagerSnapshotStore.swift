import Foundation

struct SharedManagerSnapshotPayload: Codable {
    let snapshot: ManagerOperationalSnapshot
    let currentUser: CurrentUser?
    let tenantSlug: String?
    let exportedAt: Date
}

@MainActor
final class ManagerSnapshotStore {
    static let shared = ManagerSnapshotStore()

    static let appGroupInfoPlistKey = "AmposSharedAppGroup"
    static let payloadDefaultsKey = "ampos.shared.managerSnapshot"
    static let exportedAtDefaultsKey = "ampos.shared.managerSnapshot.exportedAt"

    private init() {}

    func save(snapshot: ManagerOperationalSnapshot, currentUser: CurrentUser?, tenantSlug: String?) {
        let payload = SharedManagerSnapshotPayload(
            snapshot: snapshot,
            currentUser: currentUser,
            tenantSlug: tenantSlug,
            exportedAt: Date()
        )

        guard let data = try? JSONEncoder().encode(payload) else { return }
        for defaults in defaultsTargets() {
            defaults.set(data, forKey: Self.payloadDefaultsKey)
            defaults.set(payload.exportedAt, forKey: Self.exportedAtDefaultsKey)
        }
    }

    func clear() {
        for defaults in defaultsTargets() {
            defaults.removeObject(forKey: Self.payloadDefaultsKey)
            defaults.removeObject(forKey: Self.exportedAtDefaultsKey)
        }
    }

    func load() -> SharedManagerSnapshotPayload? {
        for defaults in defaultsTargets() {
            guard let data = defaults.data(forKey: Self.payloadDefaultsKey),
                  let payload = try? JSONDecoder().decode(SharedManagerSnapshotPayload.self, from: data) else {
                continue
            }
            return payload
        }
        return nil
    }

    var configuredAppGroupIdentifier: String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: Self.appGroupInfoPlistKey) as? String else {
            return nil
        }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func defaultsTargets() -> [UserDefaults] {
        var targets = [UserDefaults.standard]
        if let appGroup = configuredAppGroupIdentifier,
           let sharedDefaults = UserDefaults(suiteName: appGroup) {
            targets.append(sharedDefaults)
        }
        return targets
    }
}
