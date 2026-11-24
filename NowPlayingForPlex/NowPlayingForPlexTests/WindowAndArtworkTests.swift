import AppKit
import XCTest
@testable import PlexWidget

final class WindowAndArtworkTests: XCTestCase {
    @MainActor
    func testDragSurfaceAcceptsFirstMouseInAnInactiveWindow() {
        XCTAssertTrue(WindowDragView().acceptsFirstMouse(for: nil))
    }

    @MainActor
    func testDraggingPassesTheInitialMouseEventToAppKit() throws {
        _ = NSApplication.shared
        let window = DragRecordingWindow(
            contentRect: CGRect(x: 0, y: 0, width: 100, height: 50),
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )
        let dragView = WindowDragView()
        window.contentView = dragView
        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: CGPoint(x: 10, y: 10),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))

        dragView.mouseDown(with: event)

        XCTAssertTrue(window.dragEvent === event)
    }

    func testWidgetFromDisconnectedDisplayMovesToPrimaryVisibleArea() {
        let primary = CGRect(x: 0, y: 40, width: 1440, height: 820)
        let savedFrame = CGRect(x: 1850, y: 40, width: 592, height: 232)

        let restored = WidgetWindowPlacement.restoredFrame(savedFrame, screens: [primary])

        XCTAssertTrue(primary.contains(restored))
        XCTAssertEqual(restored.origin, CGPoint(x: 828, y: 60))
    }

    func testResizingKeepsWidgetOnDisplayWithNegativeOrigin() {
        let primary = CGRect(x: 0, y: 40, width: 1440, height: 820)
        let secondary = CGRect(x: -1920, y: 24, width: 1920, height: 1056)
        let resizedFrame = CGRect(x: -2050, y: 50, width: 592, height: 232)

        let restored = WidgetWindowPlacement.visibleFrame(resizedFrame, screens: [primary, secondary])

        XCTAssertTrue(secondary.contains(restored))
        XCTAssertEqual(restored.origin.x, secondary.minX)
    }

    func testPositionInsideVisibleAreaIsPreserved() {
        let screen = CGRect(x: 0, y: 40, width: 1440, height: 820)
        let original = CGRect(x: 25, y: 76, width: 592, height: 232)

        XCTAssertEqual(WidgetWindowPlacement.restoredFrame(original, screens: [screen]), original)
    }

    func testWidgetRestoresADraggedPositionNearTheDock() {
        let screen = CGRect(x: 0, y: 60, width: 1440, height: 820)
        let savedFrame = CGRect(x: 800, y: 24, width: 592, height: 232)

        XCTAssertEqual(WidgetWindowPlacement.restoredFrame(savedFrame, screens: [screen]), savedFrame)
    }

    func testWidgetRestoresADraggedPositionAtTheEdgeOfASecondaryDisplay() {
        let primary = CGRect(x: 0, y: 40, width: 1440, height: 820)
        let secondary = CGRect(x: -1920, y: 24, width: 1920, height: 1056)
        let savedFrame = CGRect(x: -1944, y: 62, width: 592, height: 232)

        XCTAssertEqual(WidgetWindowPlacement.restoredFrame(savedFrame, screens: [primary, secondary]), savedFrame)
    }

    func testWidgetWithOnlyAnEdgeOnScreenIsMovedIntoReach() {
        let screen = CGRect(x: 0, y: 60, width: 1440, height: 820)
        let savedFrame = CGRect(x: 1436, y: 72, width: 592, height: 232)

        let restored = WidgetWindowPlacement.restoredFrame(savedFrame, screens: [screen])

        XCTAssertTrue(screen.contains(restored))
    }

    @MainActor
    func testLateArtworkCannotReplaceNewerCover() async {
        let artwork = AlbumArtwork()
        let oldCover = NSImage(size: NSSize(width: 10, height: 10))
        let newCover = NSImage(size: NSSize(width: 20, height: 20))
        let pending = PendingArtwork()
        let oldRequest = Task { await artwork.load(url: "previous", fetch: pending.wait) }

        await pending.waitUntilStarted()
        await artwork.load(url: "current") { _ in newCover }
        pending.complete(with: oldCover)
        await oldRequest.value

        XCTAssertTrue(artwork.image === newCover)
    }

    @MainActor
    func testLateArtworkCannotReplaceIdlePlaceholder() async {
        let artwork = AlbumArtwork()
        let pending = PendingArtwork()
        let oldRequest = Task { await artwork.load(url: "previous", fetch: pending.wait) }

        await pending.waitUntilStarted()
        await artwork.load(url: nil) { _ in
            XCTFail("Idle playback must not fetch artwork")
            return nil
        }
        pending.complete(with: NSImage(size: NSSize(width: 10, height: 10)))
        await oldRequest.value

        XCTAssertNil(artwork.image)
    }

    @MainActor
    func testCurrentArtworkFailureClearsPreviousCover() async {
        let artwork = AlbumArtwork()
        let previous = NSImage(size: NSSize(width: 10, height: 10))
        await artwork.load(url: "previous") { _ in previous }

        await artwork.load(url: "current") { _ in nil }

        XCTAssertNil(artwork.image)
    }

    @MainActor
    func testCancelledArtworkRequestLeavesImageUnchanged() async {
        let artwork = AlbumArtwork()
        let pending = PendingArtwork()
        let request = Task { await artwork.load(url: "current", fetch: pending.wait) }

        await pending.waitUntilStarted()
        request.cancel()
        pending.complete(with: NSImage(size: NSSize(width: 10, height: 10)))
        await request.value

        XCTAssertNil(artwork.image)
    }
}

private final class DragRecordingWindow: NSWindow {
    private(set) var dragEvent: NSEvent?

    override func performDrag(with event: NSEvent) {
        dragEvent = event
    }
}

@MainActor
private final class PendingArtwork {
    private var request: CheckedContinuation<NSImage?, Never>?
    private var started: CheckedContinuation<Void, Never>?

    func wait(_ url: String) async -> NSImage? {
        await withCheckedContinuation { continuation in
            request = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        guard request == nil else { return }
        await withCheckedContinuation { started = $0 }
    }

    func complete(with image: NSImage) {
        request?.resume(returning: image)
        request = nil
    }
}
