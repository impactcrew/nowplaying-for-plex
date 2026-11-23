import AppKit
import XCTest
@testable import PlexWidget

final class WindowAndArtworkTests: XCTestCase {
    func testWidgetFromDisconnectedDisplayMovesToPrimaryVisibleArea() {
        let primary = CGRect(x: 0, y: 40, width: 1440, height: 820)
        let savedFrame = CGRect(x: 1850, y: 40, width: 592, height: 232)

        let restored = WidgetWindowPlacement.visibleFrame(savedFrame, screens: [primary])

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

        XCTAssertEqual(WidgetWindowPlacement.visibleFrame(original, screens: [screen]), original)
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
