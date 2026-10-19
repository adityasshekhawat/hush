import Foundation
import HushCore
import HushMac

/// Per-lane model overrides (Agent ▸ Models), stored in UserDefaults as `laneModel.<lane>`.
enum LaneSettings {
    private static func key(_ id: LaneID) -> String { "laneModel.\(id.rawValue)" }

    static func spec(_ id: LaneID) -> LaneSpec {
        LaneRegistry.spec(id, modelOverride: UserDefaults.standard.string(forKey: key(id)))
    }

    /// nil goes back to the default.
    @MainActor static func setModel(_ model: String?, for id: LaneID) {
        if let model { UserDefaults.standard.set(model, forKey: key(id)) }
        else { UserDefaults.standard.removeObject(forKey: key(id)) }
        DiagnosticsLog.write("lanes: \(id.rawValue) model → \(spec(id).model)")
    }
}
