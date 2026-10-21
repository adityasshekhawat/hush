import AppKit
import HushCore
import HushMac

/// New versions (ADR-036). Hush asks GitHub for the latest release when you choose "Check for updates…", or once a
/// day if you said yes to that (asked once, in the menu bar panel; Settings ▸ General). The request is a plain GET
/// with no cookies and nothing about you. "Update" opens Terminal in the folder you built Hush from and runs
/// `git pull --ff-only && ./scripts/bundle.sh`, so you see every step; nothing updates on its own.
@MainActor
final class UpdateController: ObservableObject {
    enum Status: Equatable { case idle, checking, upToDate, available(Updates.Release), failed }
    @Published private(set) var status: Status = .idle

    private let defaults = UserDefaults.standard
    private var timer: Timer?

    /// nil until you've answered "Tell you about new versions?".
    var consent: Bool? {
        get { defaults.object(forKey: "updateCheckConsent") as? Bool }
        set { defaults.set(newValue, forKey: "updateCheckConsent"); objectWillChange.send(); if newValue == true { checkIfDue() } }
    }

    var current: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }

    /// The clone this copy was built from (bundle.sh records it), if it's still there.
    var sourceFolder: String? {
        guard let f = Bundle.main.object(forInfoDictionaryKey: "HushSourceFolder") as? String,
              FileManager.default.isExecutableFile(atPath: f + "/scripts/bundle.sh") else { return nil }
        return f
    }

    var available: Updates.Release? { if case .available(let r) = status { r } else { nil } }

    func start() {
        // A newer version found earlier stays on show until you have it.
        if let v = defaults.string(forKey: "updateAvailableVersion"), let page = defaults.url(forKey: "updateAvailablePage"),
           Updates.isNewer(v, than: current) {
            status = .available(.init(version: v, page: page))
        }
        checkIfDue()
        // Hourly look at the clock; the check itself runs at most once in 20 hours, and only with your yes.
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        }
        timer?.tolerance = 600
    }

    private func checkIfDue() {
        guard Updates.shouldCheck(consent: consent, lastCheck: defaults.object(forKey: "updateLastCheck") as? Date, now: Date()) else { return }
        Task { await check(manual: false) }
    }

    func check(manual: Bool) async {
        guard status != .checking else { return }
        let before = status
        status = .checking
        defaults.set(Date(), forKey: "updateLastCheck")
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = ["Accept": "application/vnd.github+json", "User-Agent": "Hush/\(current)"]
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, response) = try? await session.data(from: Updates.latestReleaseURL),
              (response as? HTTPURLResponse)?.statusCode == 200, let latest = Updates.release(fromJSON: data) else {
            DiagnosticsLog.write("updates: couldn't read the latest release")
            status = manual ? .failed : before
            return
        }
        DiagnosticsLog.write("updates: latest \(latest.version), this is \(current)")
        if Updates.isNewer(latest.version, than: current) {
            defaults.set(latest.version, forKey: "updateAvailableVersion")
            defaults.set(latest.page, forKey: "updateAvailablePage")
            status = .available(latest)
        } else {
            defaults.removeObject(forKey: "updateAvailableVersion")
            status = manual ? .upToDate : .idle
        }
    }

    /// Clears "You're up to date" / "Couldn't check" once the panel closes.
    func settle() { if status == .upToDate || status == .failed { status = .idle } }

    /// Opens Terminal running the update in your clone. Without a known clone, copies the command instead.
    /// Returns false when it copied.
    @discardableResult
    func update() -> Bool {
        guard let folder = sourceFolder else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("git pull --ff-only && ./scripts/bundle.sh", forType: .string)
            return false
        }
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Hush")
        let script = dir.appendingPathComponent("update.command")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Updates.updateScript(folder: folder).write(to: script, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        } catch {
            DiagnosticsLog.write("updates: couldn't write the update script: \(error.localizedDescription)")
            return false
        }
        let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open([script], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
        DiagnosticsLog.write("updates: opened Terminal to update in \(folder)")
        return true
    }
}
