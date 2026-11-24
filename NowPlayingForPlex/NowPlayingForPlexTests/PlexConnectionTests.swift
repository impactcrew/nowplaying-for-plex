import Foundation
import XCTest
@testable import PlexWidget

final class PlexConnectionTests: XCTestCase {
    func testFailedCredentialReplacementKeepsTheWorkingConnection() throws {
        let (manager, store, defaults) = fixtureConfigManager()
        XCTAssertTrue(manager.saveConfig(serverUrl: "https://old.example.test", token: "fixture-original"))

        store.rejectSaves = true
        XCTAssertFalse(manager.saveConfig(serverUrl: "https://new.example.test", token: "fixture-replacement"))

        let config = try XCTUnwrap(ConfigManager(defaults: defaults, store: store).loadConfig())
        XCTAssertEqual(config.plexServerUrl, "https://old.example.test")
        XCTAssertEqual(config.plexToken, "fixture-original")
    }

    func testMigratesExistingCredentialsAndPreservesTheOlderAppLogin() throws {
        let (manager, store, defaults) = fixtureConfigManager()
        defaults.set("http://192.168.1.3:32400", forKey: "plex-server-url")
        store.records["plex-token"] = Data("fixture-token".utf8)

        let config = try XCTUnwrap(manager.loadConfig())
        XCTAssertEqual(config.plexToken, "fixture-token")
        XCTAssertTrue(config.allowsLocalHTTP)
        XCTAssertEqual(store.records["plex-token"], Data("fixture-token".utf8))
        XCTAssertEqual(store.records.count, 2)
        XCTAssertEqual(ConfigManager(defaults: defaults, store: store).loadConfig()?.plexServerUrl, config.plexServerUrl)
    }

    func testSavingANewConnectionDoesNotChangeTheOlderAppLogin() throws {
        let (manager, store, defaults) = fixtureConfigManager()
        defaults.set("https://old.example.test", forKey: "plex-server-url")
        store.records["plex-token"] = Data("fixture-original".utf8)

        XCTAssertTrue(manager.saveConfig(serverUrl: "https://new.example.test", token: "fixture-new"))

        XCTAssertEqual(defaults.string(forKey: "plex-server-url"), "https://old.example.test")
        XCTAssertEqual(store.records["plex-token"], Data("fixture-original".utf8))
        XCTAssertEqual(manager.loadConfig()?.plexServerUrl, "https://new.example.test")
        XCTAssertEqual(manager.getServerUrl(), "https://new.example.test")
    }

    func testMigratesLegacyDebugTokenAndRemovesItsPlaintextCopy() throws {
        let (manager, store, defaults) = fixtureConfigManager()
        defaults.set("https://debug.example.test", forKey: "plex-server-url")
        defaults.set("fixture-debug-token", forKey: "plex-token-debug")

        XCTAssertEqual(manager.loadConfig()?.plexToken, "fixture-debug-token")
        XCTAssertEqual(store.records.count, 1)
        XCTAssertNil(defaults.object(forKey: "plex-token-debug"))
    }

    func testAmbiguousLegacyCredentialsDoNotGetPairedWithTheWrongServer() {
        let (manager, store, defaults) = fixtureConfigManager()
        defaults.set("https://new.example.test", forKey: "plex-server-url")
        defaults.set("fixture-debug-token", forKey: "plex-token-debug")
        store.records["plex-token"] = Data("fixture-release-token".utf8)

        guard case .needsReview = manager.loadSavedConnection() else {
            return XCTFail("An ambiguous token must not be paired with a server.")
        }
        XCTAssertEqual(manager.getServerUrl(), "https://new.example.test")
    }

    func testSavedTokenWithoutItsAddressIsPreserved() {
        let (manager, store, defaults) = fixtureConfigManager()
        defaults.set("https://different.example.test", forKey: "plex-connection-server-url")
        store.records["plex-token"] = Data("fixture-original".utf8)

        guard case .needsReview = manager.loadSavedConnection() else {
            return XCTFail("An old token must not be sent to an unmatched server.")
        }
        XCTAssertEqual(store.records["plex-token"], Data("fixture-original".utf8))
        XCTAssertNil(store.records["plex-connection"])
    }

    func testKeychainAccessFailureCanBeRetried() {
        let (manager, store, defaults) = fixtureConfigManager()
        defaults.set("https://old.example.test", forKey: "plex-server-url")
        store.records["plex-token"] = Data("fixture-original".utf8)
        store.rejectReads = true

        guard case .unavailable = manager.loadSavedConnection() else {
            return XCTFail("Keychain access failure must be distinguishable from first run.")
        }
        XCTAssertEqual(store.records["plex-token"], Data("fixture-original".utf8))

        store.rejectReads = false
        XCTAssertEqual(manager.loadSavedConnection().config?.plexToken, "fixture-original")
    }

    func testAddressDefaultsToHTTPSAndBuildsSessionsUnderTheProxyPath() throws {
        let address = try PlexServerAddress(" media.example.test:32400/plex/ ")

        XCTAssertEqual(address.url.absoluteString, "https://media.example.test:32400/plex")
        XCTAssertEqual(address.sessionsURL.absoluteString, "https://media.example.test:32400/plex/status/sessions")
    }

    func testHTTPRequiresLocalAddressAndExplicitOptIn() throws {
        XCTAssertThrowsError(try PlexServerAddress("http://192.168.1.3:32400"))
        XCTAssertNoThrow(try PlexServerAddress("http://192.168.1.3:32400", allowsLocalHTTP: true))
        XCTAssertNoThrow(try PlexServerAddress("http://[::1]:32400", allowsLocalHTTP: true))
        XCTAssertThrowsError(try PlexServerAddress("http://media.example.test", allowsLocalHTTP: true))
        XCTAssertThrowsError(try PlexServerAddress("http://192.168.1.3.example.test", allowsLocalHTTP: true))
    }

    func testRejectsCredentialsAndOtherAmbiguousBaseURLComponents() {
        for url in ["https://user:password@media.example.test", "https://media.example.test?token=secret", "https://media.example.test/#plex", "file:///var/plex"] {
            XCTAssertThrowsError(try PlexServerAddress(url))
        }
    }

    func testArtworkAndRedirectsStayOnTheConfiguredOrigin() throws {
        let address = try PlexServerAddress("https://media.example.test/plex")

        XCTAssertEqual(address.artworkURL("/thumb/42?width=120")?.absoluteString, "https://media.example.test/plex/thumb/42?width=120")
        XCTAssertNil(address.artworkURL("//images.example.test/thumb/42"))
        XCTAssertNil(address.artworkURL("http://media.example.test/thumb/42"))
        XCTAssertNil(address.artworkURL("https://media.example.test:8443/thumb/42"))
        let artwork = try XCTUnwrap(address.artworkURL("/thumb/42?width=120&X-Plex-Token=example"))
        XCTAssertEqual(artwork.query, "width=120")
        XCTAssertTrue(address.permitsRequest(to: try XCTUnwrap(URL(string: "https://media.example.test:443/redirect"))))
        XCTAssertFalse(address.permitsRequest(to: try XCTUnwrap(URL(string: "https://images.example.test/redirect"))))
        XCTAssertFalse(address.permitsRequest(to: try XCTUnwrap(URL(string: "http://media.example.test/redirect"))))
    }

    func testSharedValidationAcceptsEmptyPlexSessionsAndRejectsOtherSuccessBodies() async throws {
        let address = try PlexServerAddress("https://media.example.test")
        let fixtures = [
            (#"{"MediaContainer":{"size":0}}"#, true),
            (#"{"MediaContainer":{"Metadata":[]}}"#, true),
            (#"{"MediaContainer":{"size":1}}"#, false),
            (#"{"status":"ok"}"#, false),
            ("<html>Sign in</html>", false)
        ]
        for (body, isPlex) in fixtures {
            let client = PlexClient(address: address, token: "fixture-credential", clientIdentifier: "tests") { request in
                XCTAssertEqual(request.url, address.sessionsURL)
                XCTAssertEqual(request.value(forHTTPHeaderField: "X-Plex-Token"), "fixture-credential")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
                let response = try XCTUnwrap(HTTPURLResponse(url: address.sessionsURL, statusCode: 200, httpVersion: nil, headerFields: nil))
                return (Data(body.utf8), response)
            }
            do {
                let tracks = try await client.sessions()
                XCTAssertTrue(isPlex, "Accepted a response that didn't contain Plex sessions: \(body)")
                XCTAssertTrue(tracks.isEmpty)
            } catch {
                XCTAssertFalse(isPlex, "Rejected an empty Plex session list: \(error)")
            }
        }
    }

    func testPlaybackPrefersPlayingAndUsesAStableOrderForTies() throws {
        let tracks = try trackFixtures()

        XCTAssertEqual(PlexSessionSelection.track(in: tracks, preferredSourceID: nil)?.title, "Playing A")
        XCTAssertEqual(PlexSessionSelection.track(in: tracks.reversed(), preferredSourceID: nil)?.title, "Playing A")
    }

    func testUserOrPlayerSelectionDoesNotFallBackToDifferentListeners() throws {
        let tracks = try trackFixtures()
        let sources = PlexSessionSelection.sources(in: tracks)

        XCTAssertTrue(sources.contains { $0.label.contains("Guest") })
        XCTAssertTrue(sources.contains { $0.label.contains("Living Room") })
        XCTAssertEqual(PlexSessionSelection.track(in: tracks, preferredSourceID: "user:12")?.title, "Paused")
        XCTAssertEqual(PlexSessionSelection.track(in: tracks, preferredSourceID: "player:kitchen")?.title, "Playing B")
        XCTAssertNil(PlexSessionSelection.track(in: tracks, preferredSourceID: "user:999"))
    }

    private func trackFixtures() throws -> [Track] {
        try JSONDecoder().decode([Track].self, from: Data("""
            [
              {"type":"track","title":"Paused","sessionKey":"00","User":{"id":"12","title":"Guest"},"Player":{"state":"paused","machineIdentifier":"living-room","title":"Living Room"}},
              {"type":"track","title":"Playing B","sessionKey":"20","User":{"id":13,"title":"Owner"},"Player":{"state":"playing","machineIdentifier":"kitchen","title":"Kitchen"}},
              {"type":"track","title":"Playing A","sessionKey":"10","User":{"id":"13","title":"Owner"},"Player":{"state":"playing","machineIdentifier":"office","title":"Office"}},
              {"type":"movie","title":"Movie","sessionKey":"01","Player":{"state":"playing","machineIdentifier":"tv","title":"TV"}}
            ]
            """.utf8))
    }

    private func fixtureConfigManager() -> (ConfigManager, FixtureCredentialStore, UserDefaults) {
        let suite = "PlexConnectionTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let store = FixtureCredentialStore()
        return (ConfigManager(defaults: defaults, store: store), store, defaults)
    }
}

private final class FixtureCredentialStore: PlexCredentialStore {
    var records: [String: Data] = [:]
    var rejectSaves = false
    var rejectReads = false

    func read(account: String) throws -> Data? {
        if rejectReads { throw CocoaError(.fileReadNoPermission) }
        return records[account]
    }

    func save(_ data: Data, account: String) throws {
        if rejectSaves { throw CocoaError(.fileWriteNoPermission) }
        records[account] = data
    }

}
