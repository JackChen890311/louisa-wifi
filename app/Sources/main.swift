import AppKit
import CoreWLAN

final class AppDelegate: NSObject, NSApplicationDelegate, CWEventDelegate {
    private var menu: MenuController!
    private var launchedAtLogin = false

    /// Login items get 'logi' in the open-application event, so stay out of the
    /// menu bar until the user opens the app themselves.
    func applicationWillFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        let prop = event?.paramDescriptor(forKeyword: AEKeyword(0x70726474)) // 'prdt'
        launchedAtLogin = prop?.enumCodeValue == OSType(0x6C6F6769) // 'logi'
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["autoConnect": true])
        menu = MenuController()
        if !launchedAtLogin { menu.showIcon() }
        Joiner.shared.onStatus = { [weak self] in self?.menu.update($0) }
        Notifier.setUp()
        Tracker.shared.start()
        Updater.shared.start()

        Locator.shared.onChange = { Joiner.shared.autoConnect() }
        Locator.shared.start()

        CWWiFiClient.shared().delegate = self
        try? CWWiFiClient.shared().startMonitoringEvent(with: .linkDidChange)
        Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in Joiner.shared.autoConnect() }
        Joiner.shared.autoConnect()
        debugLog("started: \(Stores.all.count) stores")
    }

    nonisolated func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        Joiner.shared.autoConnect()
    }

    /// Opening the app while it's already running shows the menu bar icon again.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menu.showIcon()
        return true
    }

    /// louisawifi://connect?store=延平門市, louisawifi://nearest, louisawifi://stats, louisawifi://update, louisawifi://show
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            switch url.host {
            case "connect":
                if let name = query?.first(where: { $0.name == "store" })?.value, let store = Stores.named(name) {
                    Joiner.shared.connect(to: store)
                }
            case "nearest":
                Joiner.shared.connectNearest()
            case "stats":
                menu.showStats()
            case "show":
                menu.showIcon()
            case "hide":
                menu.hideIcon()
            case "update":
                if Updater.shared.available == nil { Updater.shared.check(manual: true) } else { Updater.shared.install() }
            default:
                break
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
