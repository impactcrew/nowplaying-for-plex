import SwiftUI
import Combine

@main
struct PlexWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// Custom NSWindow subclass that can accept keyboard input in borderless mode
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var onboardingWindow: NSWindow?
    private var statusBarItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var plexAPI: PlexAPI?
    private lazy var settings = WidgetSettings.shared
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var layoutObserver: AnyCancellable?
    private var currentLayout: LayoutStyle = .side

    private let windowPositionXKey = "windowPositionX"
    private let windowPositionYKey = "windowPositionY"

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["PLEX_WIDGET_TEST_HOST"] != "1" else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: NSApp
        )

        let savedConnection = ConfigManager.shared.loadSavedConnection()
        if let config = savedConnection.config {
            NSApp.setActivationPolicy(.accessory)
            showMainWidget(config: config)
        } else {
            showOnboarding(savedConnection: savedConnection)
        }

        // Create menu bar item with Plex chevron icon
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusBarItem?.button {
            // Create the Plex chevron icon from SVG path
            let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
                NSColor.black.setFill()
                let path = NSBezierPath()
                // Plex chevron polygon: "117.9,33.9 104.1,13.5 118.3,13.5 132,33.9 118.3,54.2 104.1,54.2"
                // Translate to origin and scale to fit 18x18
                let scale: CGFloat = 0.44
                let offsetX: CGFloat = -104.1 * scale
                let offsetY: CGFloat = -13.5 * scale

                path.move(to: NSPoint(x: 117.9 * scale + offsetX, y: 33.9 * scale + offsetY))
                path.line(to: NSPoint(x: 104.1 * scale + offsetX, y: 13.5 * scale + offsetY))
                path.line(to: NSPoint(x: 118.3 * scale + offsetX, y: 13.5 * scale + offsetY))
                path.line(to: NSPoint(x: 132.0 * scale + offsetX, y: 33.9 * scale + offsetY))
                path.line(to: NSPoint(x: 118.3 * scale + offsetX, y: 54.2 * scale + offsetY))
                path.line(to: NSPoint(x: 104.1 * scale + offsetX, y: 54.2 * scale + offsetY))
                path.close()
                path.fill()
                return true
            }
            image.isTemplate = true
            button.image = image
            button.action = #selector(toggleSettings)
            button.target = self
        }
    }

    private func showOnboarding(savedConnection: SavedPlexConnection? = nil) {
        if let onboardingWindow, onboardingWindow.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            onboardingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let savedConnection = savedConnection ?? ConfigManager.shared.loadSavedConnection()
        let currentConfig = savedConnection.config
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let size = NSSize(width: 520, height: 600)
        let setupWindow = KeyableWindow(
            contentRect: NSRect(
                x: screenFrame.midX - size.width / 2,
                y: screenFrame.midY - size.height / 2,
                width: size.width,
                height: size.height
            ),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        setupWindow.isOpaque = false
        setupWindow.backgroundColor = .clear
        setupWindow.level = .floating
        let savedConnectionMessage: String?
        let retrySavedConnection: (() -> Bool)?
        switch savedConnection {
        case .unavailable:
            savedConnectionMessage = "Unable to read your saved Plex connection. Check Keychain access, then retry it here."
            retrySavedConnection = { [weak self, weak setupWindow] in
                guard let self, let setupWindow,
                      let config = ConfigManager.shared.loadSavedConnection().config else { return false }
                self.finishOnboarding(setupWindow, config: config)
                return true
            }
        case .needsReview:
            savedConnectionMessage = "The saved server address and Plex token could not be matched. Check your server address and enter its token to reconnect."
            retrySavedConnection = nil
        case .available, .missing:
            savedConnectionMessage = nil
            retrySavedConnection = nil
        }

        let onboardingView = OnboardingView(
            onComplete: { [weak self, weak setupWindow] config in
                guard let self, let setupWindow else { return }
                self.finishOnboarding(setupWindow, config: config)
            },
            onClose: { [weak self, weak setupWindow] in
                guard let self, let setupWindow else { return }
                self.finishOnboarding(setupWindow)
            },
            initialServerURL: currentConfig?.plexServerUrl ?? ConfigManager.shared.getServerUrl() ?? "",
            initialAllowsLocalHTTP: currentConfig?.allowsLocalHTTP ?? false,
            savedConnectionMessage: savedConnectionMessage,
            retrySavedConnection: retrySavedConnection
        )
        setupWindow.contentView = NSHostingView(rootView: onboardingView)
        onboardingWindow = setupWindow

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        setupWindow.makeKeyAndOrderFront(nil)
    }

    private func finishOnboarding(_ setupWindow: NSWindow, config: PlexConfig? = nil) {
        // AppKit may still be dispatching the hosted view's button action.
        DispatchQueue.main.async { [weak self, weak setupWindow] in
            guard let self, let setupWindow, self.onboardingWindow === setupWindow else { return }
            setupWindow.orderOut(nil)
            self.onboardingWindow = nil

            if let config {
                NSApp.setActivationPolicy(.accessory)
                self.showMainWidget(config: config)
            } else if let window = self.window {
                NSApp.setActivationPolicy(.accessory)
                window.orderFront(nil)
            } else {
                NSApp.terminate(nil)
            }
        }
    }

    private func showMainWidget(config: PlexConfig) {
        plexAPI?.stopUpdating()
        let api = PlexAPI(serverUrl: config.plexServerUrl, token: config.plexToken, allowsLocalHTTP: config.allowsLocalHTTP)
        plexAPI = api

        let widgetWindow = window ?? makeWidgetWindow()
        widgetWindow.contentView = NSHostingView(rootView: ContentView(plexAPI: api, settings: settings))
        widgetWindow.orderFront(nil)
    }

    private func makeWidgetWindow() -> NSWindow {
        let size = windowSizeForLayout(settings.layoutStyle)
        let screens = visibleScreenFrames
        var frame = WidgetWindowPlacement.defaultFrame(size: size, on: screens.first)
        let defaults = UserDefaults.standard
        if let savedX = defaults.object(forKey: windowPositionXKey) as? NSNumber,
           let savedY = defaults.object(forKey: windowPositionYKey) as? NSNumber,
           savedX.doubleValue.isFinite, savedY.doubleValue.isFinite {
            frame.origin = CGPoint(x: savedX.doubleValue, y: savedY.doubleValue)
        }

        let widgetWindow = NSWindow(
            contentRect: WidgetWindowPlacement.visibleFrame(frame, screens: screens),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        widgetWindow.isOpaque = false
        widgetWindow.backgroundColor = .clear
        widgetWindow.level = .floating
        widgetWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .transient]
        widgetWindow.isMovable = true
        // The player draws its own shadows.
        widgetWindow.hasShadow = false
        window = widgetWindow

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: widgetWindow
        )

        currentLayout = settings.layoutStyle
        layoutObserver = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                guard let self, self.settings.layoutStyle != self.currentLayout else { return }
                self.currentLayout = self.settings.layoutStyle
                self.resizeWindowForLayout(self.currentLayout)
            }
        return widgetWindow
    }

    private var visibleScreenFrames: [CGRect] {
        NSScreen.screens.map(\.visibleFrame)
    }

    private func windowSizeForLayout(_ layout: LayoutStyle) -> CGSize {
        switch layout {
        case .side, .overlay:
            return CGSize(width: 592, height: 232)
        case .mini:
            return CGSize(width: 320, height: 100)
        }
    }

    private func resizeWindowForLayout(_ layout: LayoutStyle) {
        guard let window else { return }
        let size = windowSizeForLayout(layout)
        let frame = window.frame
        positionWidget(
            at: CGRect(x: frame.maxX - size.width, y: frame.minY, width: size.width, height: size.height),
            animate: true
        )
    }

    @objc private func screenParametersDidChange() {
        guard let window else { return }
        positionWidget(at: window.frame)
    }

    private func resetWidgetPosition() {
        positionWidget(at: WidgetWindowPlacement.defaultFrame(
            size: windowSizeForLayout(settings.layoutStyle),
            on: visibleScreenFrames.first
        ), animate: true)
    }

    private func positionWidget(at proposedFrame: CGRect, animate: Bool = false) {
        guard let window else { return }
        let frame = WidgetWindowPlacement.visibleFrame(proposedFrame, screens: visibleScreenFrames)
        if window.frame != frame {
            window.setFrame(frame, display: true, animate: animate)
        }
        savePosition(frame.origin)
    }

    @objc private func windowDidMove(_ notification: Notification) {
        guard let movedWindow = notification.object as? NSWindow, movedWindow === window else { return }
        savePosition(movedWindow.frame.origin)
    }

    private func savePosition(_ origin: CGPoint) {
        UserDefaults.standard.set(origin.x, forKey: windowPositionXKey)
        UserDefaults.standard.set(origin.y, forKey: windowPositionYKey)
    }

    @objc private func toggleSettings() {
        if settingsWindow?.isVisible == true {
            dismissSettings(restoreKeyboardFocus: true)
        } else if onboardingWindow?.isVisible == true || plexAPI == nil {
            showOnboarding()
        } else {
            showSettings()
        }
    }

    private func showSettings() {
        guard let button = statusBarItem?.button, let plexAPI else { return }
        dismissSettings()
        let buttonFrame = statusButtonFrame
        let settingsView = SettingsView(
            settings: settings,
            plexAPI: plexAPI,
            changeServer: { [weak self] in
                self?.dismissSettings()
                self?.showOnboarding()
            },
            resetPosition: { [weak self] in self?.resetWidgetPosition() },
            dismiss: { [weak self] in self?.dismissSettings(restoreKeyboardFocus: true) }
        )
        let hostingView = NSHostingView(rootView: settingsView)
        let size = hostingView.fittingSize
        let screen = button.window?.screen?.visibleFrame
        let x = screen.map { max($0.minX, min(buttonFrame.minX, $0.maxX - size.width)) } ?? buttonFrame.minX
        let panel = KeyableWindow(
            contentRect: NSRect(x: x, y: buttonFrame.minY - size.height, width: size.width, height: size.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.contentView = hostingView
        panel.initialFirstResponder = hostingView
        settingsWindow = panel

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismissSettingsForOutsideClick()
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self, let eventWindow = event.window, eventWindow === self.window {
                self.dismissSettingsForOutsideClick()
            }
            return event
        }
    }

    private var statusButtonFrame: NSRect {
        guard let button = statusBarItem?.button, let buttonWindow = button.window else { return .zero }
        return buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func dismissSettingsForOutsideClick() {
        guard let settingsWindow, settingsWindow.isVisible else { return }
        let location = NSEvent.mouseLocation
        if !settingsWindow.frame.contains(location) && !statusButtonFrame.contains(location) {
            dismissSettings()
        }
    }

    private func dismissSettings(restoreKeyboardFocus: Bool = false) {
        settingsWindow?.orderOut(nil)
        settingsWindow = nil
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
        if restoreKeyboardFocus, let button = statusBarItem?.button {
            button.window?.makeFirstResponder(button)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

enum WidgetWindowPlacement {
    static func defaultFrame(size: CGSize, on screen: CGRect?) -> CGRect {
        let visible = screen ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        return CGRect(
            x: max(visible.minX, visible.maxX - size.width - 20),
            y: min(visible.minY + 20, max(visible.minY, visible.maxY - size.height)),
            width: size.width,
            height: size.height
        )
    }

    static func visibleFrame(_ frame: CGRect, screens: [CGRect]) -> CGRect {
        guard let primary = screens.first else { return frame }
        let overlapping = screens.max { overlapArea(frame, $0) < overlapArea(frame, $1) }
        guard let screen = overlapping, overlapArea(frame, screen) > 0 else {
            return defaultFrame(size: frame.size, on: primary)
        }
        return CGRect(
            x: max(screen.minX, min(frame.minX, screen.maxX - frame.width)),
            y: max(screen.minY, min(frame.minY, screen.maxY - frame.height)),
            width: frame.width,
            height: frame.height
        )
    }

    private static func overlapArea(_ frame: CGRect, _ screen: CGRect) -> CGFloat {
        let overlap = frame.intersection(screen)
        return overlap.width * overlap.height
    }
}
