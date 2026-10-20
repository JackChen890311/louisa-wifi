import AppKit
import CryptoKit
import Foundation

/// Checks GitHub Releases for a newer version and installs it in place.
final class Updater {
    static let shared = Updater()
    static let repo = "JackChen890311/louisa-wifi"

    /// Newer release, if any. Main thread only.
    private(set) var available: (version: String, zip: URL, sha: URL)?
    var onChange: (() -> Void)?

    var current: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }

    func start() {
        check()
        Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in self?.check() }
    }

    func check(manual: Bool = false) {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            let release = data.flatMap { try? JSONDecoder().decode(Release.self, from: $0) }
            let zip = release?.assets.first { $0.name == "LouisaWiFi.zip" }?.browser_download_url
            let sha = release?.assets.first { $0.name == "LouisaWiFi.zip.sha256" }?.browser_download_url
            DispatchQueue.main.async {
                guard let release, let zip, let sha else {
                    if manual { Notifier.post("檢查更新失敗，請稍後再試") }
                    return
                }
                let version = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
                guard version.compare(self.current, options: .numeric) == .orderedDescending else {
                    if manual { Notifier.post("目前已是最新版本（\(self.current)）") }
                    return
                }
                if self.available?.version != version || manual {
                    Notifier.post("有新版本 \(version)，請從 ☕ 選單選擇「更新到 \(version)」")
                }
                self.available = (version, zip, sha)
                self.onChange?()
            }
        }.resume()
    }

    /// Download, verify, unzip, swap the bundle after we quit, relaunch.
    func install() {
        guard let update = available else { return }
        let (version, zip, shaURL) = update
        let target = Bundle.main.bundleURL
        guard FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path) else {
            NSWorkspace.shared.open(URL(string: "https://github.com/\(Self.repo)/releases/latest")!)
            return
        }
        Notifier.post("正在下載 \(version)…")

        // The checksum comes from the same release, so it catches a corrupted
        // download or an accidentally swapped asset, not a compromised repo.
        URLSession.shared.dataTask(with: shaURL) { data, _, _ in
            guard let data, let expected = Self.parseHash(data) else {
                DispatchQueue.main.async { Notifier.post("更新檔缺少校驗碼，請到 GitHub 下載新版") }
                return
            }
            URLSession.shared.downloadTask(with: zip) { file, _, _ in
                do {
                    guard let file else { throw CocoaError(.fileNoSuchFile) }
                    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("LouisaWiFi-\(version)-\(UUID().uuidString)")
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let archive = dir.appendingPathComponent("LouisaWiFi.zip")
                    try FileManager.default.moveItem(at: file, to: archive)

                    let actual = try Self.sha256(of: archive)
                    guard actual == expected else { throw UpdateError.checksumMismatch }
                    debugLog("update \(version): sha256 ok")

                    try Self.run("/usr/bin/ditto", ["-x", "-k", archive.path, dir.path])
                    let fresh = dir.appendingPathComponent("LouisaWiFi.app")
                    guard FileManager.default.fileExists(atPath: fresh.path) else { throw CocoaError(.fileNoSuchFile) }
                    try Self.verifyBundle(fresh, version: version)

                    // Runs after we exit; child processes outlive the app.
                    let swap = Process()
                    swap.executableURL = URL(fileURLWithPath: "/bin/sh")
                    swap.arguments = ["-c", "sleep 1; rm -rf \"$1\" && mv \"$2\" \"$1\"; open \"$1\"",
                                      "sh", target.path, fresh.path]
                    try swap.run()
                    debugLog("updating to \(version)")
                    DispatchQueue.main.async { NSApp.terminate(nil) }
                } catch {
                    debugLog("update failed: \(error.localizedDescription)")
                    DispatchQueue.main.async { Notifier.post("更新失敗：\(error.localizedDescription)") }
                }
            }.resume()
        }.resume()
    }

    private enum UpdateError: LocalizedError {
        case checksumMismatch
        case badBundle

        var errorDescription: String? {
            switch self {
            case .checksumMismatch: return "SHA-256 不符，已取消更新"
            case .badBundle: return "更新檔簽章或版本不正確，已取消更新"
            }
        }
    }

    private static func sha256(of url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func parseHash(_ data: Data) -> String? {
        guard let text = String(data: data, encoding: .utf8),
              let token = text.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }).first
        else { return nil }
        let hash = token.lowercased()
        guard hash.count == 64, hash.allSatisfy({ $0.isHexDigit }) else { return nil }
        return hash
    }

    /// The app is ad-hoc signed, so `codesign` proves the bundle was not
    /// corrupted; the identifier and version pin it to this release.
    private static func verifyBundle(_ app: URL, version: String) throws {
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        let infoURL = app.appendingPathComponent("Contents/Info.plist")
        let data = try Data(contentsOf: infoURL)
        guard let info = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              info["CFBundleIdentifier"] as? String == "io.github.louisawifi",
              info["CFBundleShortVersionString"] as? String == version
        else { throw UpdateError.badBundle }
    }

    private static func run(_ tool: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw CocoaError(.fileReadCorruptFile) }
    }

    private struct Release: Decodable {
        let tag_name: String
        let assets: [Asset]
    }

    private struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
    }
}
