import Foundation
import UIKit

/// Shared between the main app and the broadcast extension.
/// The extension writes JPEG frames into the App Group container;
/// the main app polls for them, sends them to Claude, and speaks the answer.
enum FrameBridge {

    /// MUST match the App Group you create in the Apple Developer portal
    /// and enable on BOTH targets (app + broadcast extension).
    static let appGroupID = "group.com.kanehedges.sight"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static var frameURL: URL? {
        containerURL?.appendingPathComponent("latest_frame.jpg")
    }

    static var stateURL: URL? {
        containerURL?.appendingPathComponent("state.json")
    }

    // MARK: - Extension side

    /// Called by the broadcast extension for each captured frame it decides to keep.
    static func writeFrame(_ data: Data) {
        guard let url = frameURL else { return }
        let tmp = url.appendingPathExtension("tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            // Atomic swap so the app never reads a half-written file
            _ = try? FileManager.default.replaceItemAt(url, withItemAt: tmp)
        } catch {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func setBroadcasting(_ active: Bool) {
        guard let url = stateURL else { return }
        let payload = ["broadcasting": active, "updated": Date().timeIntervalSince1970] as [String: Any]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - App side

    /// Returns the newest frame plus its modification date, or nil if none.
    static func readFrame() -> (image: Data, modified: Date)? {
        guard let url = frameURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date
        else { return nil }
        return (data, modified)
    }

    static func isBroadcasting() -> Bool {
        guard let url = stateURL,
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let active = obj["broadcasting"] as? Bool,
              let updated = obj["updated"] as? TimeInterval
        else { return false }
        // Treat a stale flag as stopped
        return active && Date().timeIntervalSince1970 - updated < 15
    }

    static func clear() {
        if let url = frameURL { try? FileManager.default.removeItem(at: url) }
    }
}
