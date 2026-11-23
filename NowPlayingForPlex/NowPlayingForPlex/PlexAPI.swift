import Darwin
import Foundation
import Combine

private struct PlexSessionsResponse: Decodable {
    let MediaContainer: Container

    struct Container: Decodable {
        let size: Int?
        let Metadata: [Track]?
    }
}

struct Track: Decodable, Identifiable {
    let id: String?
    let type: String?
    let title: String?
    let grandparentTitle: String?
    let originalTitle: String?
    let parentTitle: String?
    let thumb: String?
    let parentThumb: String?
    let grandparentThumb: String?
    let duration: Int?
    let viewOffset: Int?
    let sessionKey: String?
    let Player: Player?
    let Session: Session?
    let User: PlexUser?

    enum CodingKeys: String, CodingKey {
        case id = "ratingKey"
        case type, title, thumb, duration, viewOffset, sessionKey
        case grandparentTitle, originalTitle, parentTitle
        case parentThumb, grandparentThumb
        case Player, Session, User
    }
}

struct Player: Decodable {
    let state: String?
    let machineIdentifier: String?
    let address: String?
    let port: String?
    let `protocol`: String?
    let product: String?
    let title: String?
    let userID: String?

    private enum CodingKeys: String, CodingKey {
        case state, machineIdentifier, address, port, `protocol`, product, title, userID
    }

    init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        state = try fields.decodeIfPresent(String.self, forKey: .state)
        machineIdentifier = try fields.decodeIfPresent(String.self, forKey: .machineIdentifier)
        address = try fields.decodeIfPresent(String.self, forKey: .address)
        port = fields.textOrNumericID(forKey: .port)
        `protocol` = try fields.decodeIfPresent(String.self, forKey: .protocol)
        product = try fields.decodeIfPresent(String.self, forKey: .product)
        title = try fields.decodeIfPresent(String.self, forKey: .title)
        userID = fields.textOrNumericID(forKey: .userID)
    }
}

struct Session: Decodable {
    let id: String?
}

struct PlexUser: Decodable {
    let id: String?
    let title: String?

    private enum CodingKeys: String, CodingKey {
        case id, title
    }

    init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        id = fields.textOrNumericID(forKey: .id)
        title = try fields.decodeIfPresent(String.self, forKey: .title)
    }
}

private extension KeyedDecodingContainer {
    func textOrNumericID(forKey key: Key) -> String? {
        if let text = try? decode(String.self, forKey: key) { return text }
        if let number = try? decode(Int.self, forKey: key) { return String(number) }
        return nil
    }
}

struct PlexPlaybackSource: Identifiable, Equatable {
    let id: String
    let label: String
}

enum PlexSessionSelection {
    static func sources(in tracks: [Track]) -> [PlexPlaybackSource] {
        let sources = tracks.filter(isEligible).flatMap(playbackSources).sorted {
            ($0.label, $0.id) < ($1.label, $1.id)
        }
        var seen = Set<String>()
        return sources.filter { seen.insert($0.id).inserted }
    }

    static func track(in tracks: [Track], preferredSourceID: String?) -> Track? {
        tracks.filter { track in
            guard isEligible(track) else { return false }
            guard let preferredSourceID else { return true }
            return playbackSources(track).contains { $0.id == preferredSourceID }
        }.min { sortKey($0) < sortKey($1) }
    }

    static func identity(of track: Track) -> String {
        track.Session?.id ?? track.sessionKey ?? [
            track.Player?.machineIdentifier ?? "",
            track.User?.id ?? track.Player?.userID ?? "",
            track.id ?? track.title ?? ""
        ].joined(separator: ":")
    }

    private static func isEligible(_ track: Track) -> Bool {
        track.type == "track" && ["playing", "paused"].contains(track.Player?.state?.lowercased() ?? "")
    }

    private static func sortKey(_ track: Track) -> (Int, String, String, String) {
        (track.Player?.state?.lowercased() == "playing" ? 0 : 1, identity(of: track), track.id ?? "", track.title ?? "")
    }

    private static func playbackSources(_ track: Track) -> [PlexPlaybackSource] {
        var sources: [PlexPlaybackSource] = []
        if let userID = track.User?.id ?? track.Player?.userID, !userID.isEmpty {
            sources.append(PlexPlaybackSource(id: "user:\(userID)", label: "User: \(track.User?.title ?? userID)"))
        }
        if let player = track.Player, let playerID = player.machineIdentifier, !playerID.isEmpty {
            sources.append(PlexPlaybackSource(id: "player:\(playerID)", label: "Player: \(player.title ?? player.product ?? playerID)"))
        }
        return sources
    }
}

struct NowPlaying: Identifiable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let albumArtUrl: String?
    let state: String
    let duration: Int
    let viewOffset: Int
    let sessionKey: String?
    let playerAddress: String?
    let playerPort: String?
    let playerProtocol: String?
    let machineIdentifier: String?
}

struct PlexServerAddress {
    let url: URL
    let sessionsURL: URL

    init(_ input: String, allowsLocalHTTP: Bool = false) throws {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = components.host?.lowercased(), !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.port.map({ (1...65535).contains($0) }) ?? true else {
            throw PlexConnectionError.invalidAddress
        }

        if scheme == "http" {
            guard Self.isLocalHost(host) else { throw PlexConnectionError.insecureRemoteAddress }
            guard allowsLocalHTTP else { throw PlexConnectionError.localHTTPNeedsApproval }
        }

        components.scheme = scheme
        components.host = host
        if (scheme == "https" && components.port == 443) || (scheme == "http" && components.port == 80) {
            components.port = nil
        }

        let path = components.percentEncodedPath
        let lastPathCharacter = path.lastIndex(where: { $0 != "/" })
        components.percentEncodedPath = lastPathCharacter.map { String(path[...$0]) } ?? ""
        guard let url = components.url else { throw PlexConnectionError.invalidAddress }
        components.percentEncodedPath += "/status/sessions"
        guard let sessionsURL = components.url else { throw PlexConnectionError.invalidAddress }

        self.url = url
        self.sessionsURL = sessionsURL
    }

    static func isLegacyLocalHTTP(_ input: String) -> Bool {
        guard let components = URLComponents(string: input), components.scheme?.lowercased() == "http",
              let host = components.host else { return false }
        return isLocalHost(host.lowercased())
    }

    func artworkURL(_ path: String) -> URL? {
        guard !path.isEmpty, var reference = URLComponents(string: path) else { return nil }
        if reference.scheme == nil && reference.host == nil {
            let referencePath = reference.percentEncodedPath
            guard referencePath.hasPrefix("/"), let base = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
            reference.scheme = base.scheme
            reference.host = base.host
            reference.port = base.port
            reference.percentEncodedPath = base.percentEncodedPath + referencePath
        } else if reference.scheme == nil {
            reference.scheme = url.scheme
        }

        if let queryItems = reference.queryItems {
            let filtered = queryItems.filter { $0.name.caseInsensitiveCompare("X-Plex-Token") != .orderedSame }
            if filtered.count != queryItems.count {
                reference.queryItems = filtered.isEmpty ? nil : filtered
            }
        }
        reference.fragment = nil

        guard let artworkURL = reference.url, permitsRequest(to: artworkURL) else { return nil }
        return artworkURL
    }

    func permitsRequest(to target: URL) -> Bool {
        Self.sameOrigin(url, target)
    }

    fileprivate static func sameOrigin(_ source: URL, _ target: URL) -> Bool {
        guard let scheme = source.scheme?.lowercased(), let host = source.host?.lowercased(),
              !host.isEmpty,
              target.scheme?.lowercased() == scheme, target.host?.lowercased() == host,
              target.user == nil, target.password == nil else {
            return false
        }
        let defaultPort = scheme == "https" ? 443 : 80
        return (source.port ?? defaultPort) == (target.port ?? defaultPort)
    }

    private static func isLocalHost(_ address: String) -> Bool {
        let dnsName = address.hasSuffix(".") ? String(address.dropLast()) : address
        if dnsName == "localhost" || dnsName.hasSuffix(".localhost") || dnsName.hasSuffix(".local") {
            return true
        }

        let host = address.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        var ipv4 = in_addr()
        if inet_pton(AF_INET, host, &ipv4) == 1 {
            let bytes = withUnsafeBytes(of: &ipv4) { Array($0) }
            return [10, 127].contains(bytes[0])
                || (bytes[0] == 172 && (16...31).contains(bytes[1]))
                || (bytes[0] == 192 && bytes[1] == 168)
                || (bytes[0] == 169 && bytes[1] == 254)
        }

        let ipv6Host = host.split(separator: "%", maxSplits: 1).first.map(String.init) ?? host
        var ipv6 = in6_addr()
        if inet_pton(AF_INET6, ipv6Host, &ipv6) == 1 {
            let bytes = withUnsafeBytes(of: &ipv6) { Array($0) }
            return (bytes.dropLast().allSatisfy { $0 == 0 } && bytes.last == 1)
                || bytes[0] & 0xfe == 0xfc
                || (bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80)
        }

        return false
    }
}

enum PlexConnectionError: LocalizedError {
    case invalidAddress
    case insecureRemoteAddress
    case localHTTPNeedsApproval
    case invalidResponse
    case invalidSessions
    case redirected
    case unauthorized
    case serverStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            "Enter a Plex server address with an optional port and path. Put the Plex token in its own field."
        case .insecureRemoteAddress:
            "Use an HTTPS address for a remote Plex server."
        case .localHTTPNeedsApproval:
            "Use HTTPS or select Allow HTTP on my local network."
        case .invalidResponse:
            "Plex did not return an HTTP response."
        case .invalidSessions:
            "This address did not return a Plex sessions list. Check the server address and any proxy sign-in."
        case .redirected:
            "Use the final Plex server address if your server redirects to a different address or port."
        case .unauthorized:
            "Plex did not authorize this token to view active sessions."
        case .serverStatus(let status):
            "The Plex server returned HTTP \(status)."
        }
    }
}

struct PlexClient {
    private static let networkSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        return URLSession(configuration: configuration, delegate: PlexRedirectDelegate(), delegateQueue: nil)
    }()

    let address: PlexServerAddress
    private let token: String
    private let clientIdentifier: String
    private let transport: (URLRequest) async throws -> (Data, URLResponse)

    init(
        address: PlexServerAddress,
        token: String,
        clientIdentifier: String,
        transport: ((URLRequest) async throws -> (Data, URLResponse))? = nil
    ) {
        self.address = address
        self.token = token
        self.clientIdentifier = clientIdentifier
        self.transport = transport ?? { try await Self.networkSession.data(for: $0) }
    }

    func sessions() async throws -> [Track] {
        var request = request(url: address.sessionsURL, timeout: 5)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let response = try await response(to: request)
        guard let container = try? JSONDecoder().decode(PlexSessionsResponse.self, from: response).MediaContainer else {
            throw PlexConnectionError.invalidSessions
        }
        if let tracks = container.Metadata { return tracks }
        if container.size == 0 { return [] }
        throw PlexConnectionError.invalidSessions
    }

    func artwork(at url: URL) async throws -> Data {
        guard address.permitsRequest(to: url) else { throw PlexConnectionError.redirected }
        return try await response(to: request(url: url, timeout: 10))
    }

    private func request(url: URL, timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.setValue(token, forHTTPHeaderField: "X-Plex-Token")
        request.setValue(clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
        return request
    }

    private func response(to request: URLRequest) async throws -> Data {
        let (data, response) = try await transport(request)
        guard let response = response as? HTTPURLResponse else { throw PlexConnectionError.invalidResponse }
        guard response.url.map(address.permitsRequest) == true else { throw PlexConnectionError.redirected }
        switch response.statusCode {
        case 200: return data
        case 300..<400: throw PlexConnectionError.redirected
        case 401, 403: throw PlexConnectionError.unauthorized
        default: throw PlexConnectionError.serverStatus(response.statusCode)
        }
    }
}

private final class PlexRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let original = task.originalRequest?.url, let target = request.url,
              PlexServerAddress.sameOrigin(original, target) else {
            completionHandler(nil)
            return
        }

        completionHandler(request)
    }
}

@MainActor
final class PlexAPI: ObservableObject {
    @Published private(set) var nowPlaying: NowPlaying?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var availableSources: [PlexPlaybackSource] = []
    @Published var preferredSourceID: String? {
        didSet {
            guard preferredSourceID != oldValue else { return }
            if let preferenceKey {
                defaults.set(preferredSourceID, forKey: preferenceKey)
            }
            updateNowPlaying()
        }
    }

    private let client: Result<PlexClient, Error>
    private let defaults: UserDefaults
    private let preferenceKey: String?
    private var pollingTask: Task<Void, Never>?
    private var tracks: [Track] = []

    var displayServerURL: String? {
        (try? client.get())?.address.url.absoluteString
    }

    init(serverUrl: String, token: String, allowsLocalHTTP: Bool = false, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        client = Result {
            let address = try PlexServerAddress(serverUrl, allowsLocalHTTP: allowsLocalHTTP)
            return PlexClient(address: address, token: token, clientIdentifier: "plex-desktop-widget-\(UUID())")
        }
        preferenceKey = (try? client.get()).map { "plex-player-preference:\($0.address.url.absoluteString)" }
        preferredSourceID = preferenceKey.flatMap(defaults.string(forKey:))
    }

    deinit {
        pollingTask?.cancel()
    }

    func startUpdating(interval: TimeInterval = 5.0) {
        stopUpdating()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let delay = await self?.poll(interval: interval) else { return }
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    return
                }
            }
        }
    }

    func stopUpdating() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func poll(interval: TimeInterval) async -> TimeInterval {
        do {
            let sessions = try await client.get().sessions()
            guard !Task.isCancelled else { return interval }
            tracks = sessions
            let sources = PlexSessionSelection.sources(in: tracks)
            if availableSources != sources { availableSources = sources }
            updateNowPlaying()
            errorMessage = nil
        } catch {
            guard !Task.isCancelled else { return interval }
            tracks = []
            if !availableSources.isEmpty { availableSources = [] }
            nowPlaying = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
        return nowPlaying?.state == "playing" ? interval : interval * 2
    }

    private func updateNowPlaying() {
        guard let track = PlexSessionSelection.track(in: tracks, preferredSourceID: preferredSourceID),
              let client = try? client.get() else {
            nowPlaying = nil
            return
        }

        let thumbnail = [track.thumb, track.parentThumb, track.grandparentThumb]
            .lazy.compactMap { $0 }.compactMap(client.address.artworkURL).first
        nowPlaying = NowPlaying(
            id: track.id ?? PlexSessionSelection.identity(of: track),
            title: track.title ?? "Unknown Track",
            artist: track.originalTitle ?? track.grandparentTitle ?? "Unknown Artist",
            album: track.parentTitle ?? "Unknown Album",
            albumArtUrl: thumbnail?.absoluteString,
            state: track.Player?.state?.lowercased() ?? "playing",
            duration: track.duration ?? 0,
            viewOffset: track.viewOffset ?? 0,
            sessionKey: track.sessionKey ?? track.Session?.id,
            playerAddress: track.Player?.address,
            playerPort: track.Player?.port,
            playerProtocol: track.Player?.protocol,
            machineIdentifier: track.Player?.machineIdentifier
        )
    }

    func fetchAlbumArt(url: String) async -> Data? {
        guard let imageURL = URL(string: url) else { return nil }
        return try? await client.get().artwork(at: imageURL)
    }
}
