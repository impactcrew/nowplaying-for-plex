import CoreText
import SwiftUI

struct NowPlayingView: View {
    let nowPlaying: NowPlaying
    @ObservedObject var plexAPI: PlexAPI
    @ObservedObject var settings: WidgetSettings

    @StateObject private var artwork = AlbumArtwork()
    @State private var displayTime: Int = 0
    @State private var timer: Timer?

    var progress: Double {
        guard nowPlaying.duration > 0 else { return 0 }
        return Double(displayTime) / Double(nowPlaying.duration)
    }

    // Theme colors based on settings
    var isDarkMode: Bool {
        settings.theme == .dark
    }

    var backgroundColor: Color {
        isDarkMode ? Color(red: 13/255, green: 13/255, blue: 13/255).opacity(0.80) : Color.white
    }

    var titleColor: Color {
        isDarkMode ? Color.white : Color(hex: "1d1d1f")
    }

    var subtitleColor: Color {
        isDarkMode ? Color.white.opacity(0.85) : Color(hex: "86868b")
    }

    var shadowColors: [(Color, CGFloat, CGFloat, CGFloat)] {
        let isMini = settings.layoutStyle == .mini
        if isDarkMode {
            return [
                (Color.black.opacity(isMini ? 0.3 : 0.4), isMini ? 2 : 15, 0, isMini ? 1 : 5),
                (Color.black.opacity(isMini ? 0.2 : 0.3), isMini ? 1 : 6, 0, isMini ? 0 : 2)
            ]
        } else {
            return [
                (Color.black.opacity(isMini ? 0.1 : 0.15), isMini ? 2 : 15, 0, isMini ? 1 : 5),
                (Color.black.opacity(isMini ? 0.05 : 0.1), isMini ? 1 : 6, 0, isMini ? 0 : 2)
            ]
        }
    }

    var body: some View {
        Group {
            switch settings.layoutStyle {
            case .side:
                sideLayout
            case .overlay:
                overlayLayout
            case .mini:
                miniLayout
            }
        }
        .onAppear {
            displayTime = nowPlaying.viewOffset
            startTimer()
        }
        .onChange(of: nowPlaying.viewOffset) { newValue in
            displayTime = newValue
        }
        .onChange(of: nowPlaying.state) { newState in
            if newState == "playing" {
                startTimer()
            } else {
                timer?.invalidate()
                timer = nil
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
        .task(id: nowPlaying.albumArtUrl) {
            await artwork.load(url: nowPlaying.albumArtUrl) { url in
                guard let data = await plexAPI.fetchAlbumArt(url: url) else { return nil }
                return NSImage(data: data)
            }
        }
    }

    var overlayLayout: some View {
        ZStack(alignment: .leading) {
            // Album art positioned absolutely
            AlbumArtView(image: artwork.image)
                .frame(width: 190, height: 190)
                .clipped()  // Ensure content doesn't overflow
                .clipShape(settings.albumArtShape == .circular ?
                    AnyShape(Circle()) :
                    AnyShape(RoundedRectangle(cornerRadius: 20)))
                .shadow(color: .black.opacity(0.25), radius: 12.5, x: 0, y: 3.75)
                .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 1.25)
                .offset(x: -75, y: 0)
                .zIndex(10)

            // Main content card with left padding for album art overlap
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    // Track info
                    VStack(alignment: .leading, spacing: 2) {
                        titleLine(fontSize: 20, height: 24)

                        Text(nowPlaying.artist)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(subtitleColor)
                            .lineLimit(1)

                        Text(nowPlaying.album)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(subtitleColor)
                            .lineLimit(1)
                            .padding(.top, 2)
                    }

                    // Progress bar with time
                    VStack(spacing: 2) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: "e5e5e5"))
                                    .frame(height: 6)

                                // Fill with gradient
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(hex: "ffcb7d"),
                                                Color(hex: "ff920c")
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * progress, height: 6)
                            }
                        }
                        .frame(height: 6)

                        // Time codes
                        HStack {
                            Text(formatTime(displayTime))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(subtitleColor)

                            Spacer()

                            Text(formatTime(nowPlaying.duration))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(subtitleColor)
                        }
                        .padding(.horizontal, 2)
                    }
                    .padding(.top, 5)
                }
                .frame(width: 320)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .padding(.horizontal, 16)
            }
            .padding(.leading, 125)
            .background(
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    .overlay(backgroundColor)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .compositingGroup()
            .applyConditionalShadows(
                baseShadows: shadowColors,
                glowEnabled: settings.blueGlowEnabled,
                glowColour: settings.glowColour
            )
        }
        .frame(height: 140)
        .padding(.leading, 75)  // Increased to accommodate artwork extending left
    }

    var sideLayout: some View {
        HStack(spacing: 0) {
            // Album art on the left - 140px (square to match height)
            AlbumArtView(image: artwork.image)
                .frame(width: 140, height: 140)
                .clipped()
                .clipShape(
                    UnevenRoundedRectangle(cornerRadii: .init(
                        topLeading: 28,
                        bottomLeading: 28,
                        bottomTrailing: settings.albumArtShape == .circular ? 20 : 4,
                        topTrailing: settings.albumArtShape == .circular ? 20 : 4
                    ))
                )

            // Content area - 260px width, padding: 20px 16px 12px 16px
            VStack(alignment: .leading, spacing: 8) {
                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    titleLine(fontSize: 20, height: 24)

                    Text(nowPlaying.artist)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(subtitleColor)
                        .lineLimit(1)

                    Text(nowPlaying.album)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(subtitleColor)
                        .lineLimit(1)
                }

                Spacer()

                // Progress bar with time
                VStack(spacing: 2) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: "e5e5e5"))
                                .frame(height: 6)

                            // Fill with gradient
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(hex: "ffcb7d"),
                                            Color(hex: "ff920c")
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress, height: 6)
                        }
                    }
                    .frame(height: 6)

                    // Time codes
                    HStack {
                        Text(formatTime(displayTime))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(subtitleColor)

                        Spacer()

                        Text(formatTime(nowPlaying.duration))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(subtitleColor)
                    }
                    .padding(.horizontal, 2)
                }
            }
            .frame(width: 320)
            .padding(.top, 20)
            .padding(.bottom, 12)
            .padding(.horizontal, 16)
        }
        .frame(height: 140)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .overlay(backgroundColor)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .compositingGroup()
        .applyConditionalShadows(
            baseShadows: shadowColors,
            glowEnabled: settings.blueGlowEnabled,
            glowColour: settings.glowColour
        )
    }

    var miniLayout: some View {
        HStack(spacing: 0) {
            // Compact album art - 70px
            AlbumArtView(image: artwork.image)
                .frame(width: 70, height: 70)
                .clipped()  // Ensure content doesn't overflow
                .clipShape(settings.albumArtShape == .circular ?
                    AnyShape(UnevenRoundedRectangle(cornerRadii: .init(
                        topLeading: 16,
                        bottomLeading: 16,
                        bottomTrailing: 12,
                        topTrailing: 12
                    ))) :
                    AnyShape(UnevenRoundedRectangle(cornerRadii: .init(
                        topLeading: 16,
                        bottomLeading: 16,
                        bottomTrailing: 0,
                        topTrailing: 0
                    ))))

            // Compact content area
            VStack(alignment: .leading, spacing: 4) {
                // Track info - tighter spacing
                VStack(alignment: .leading, spacing: 1) {
                    titleLine(fontSize: 14, height: 17)

                    PlaybackMarquee(
                        text: "\(nowPlaying.artist) \u{2014} \(nowPlaying.album)",
                        font: .systemFont(ofSize: 11),
                        color: subtitleColor,
                        isPlaying: nowPlaying.state == "playing",
                        pointsPerSecond: 40
                    )
                    .equatable()
                    .frame(height: 14)
                }

                // Compact progress bar
                VStack(spacing: 1) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "e5e5e5"))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(hex: "ffcb7d"),
                                            Color(hex: "ff920c")
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)

                    // Time codes - smaller
                    HStack {
                        Text(formatTime(displayTime))
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(subtitleColor)

                        Spacer()

                        Text(formatTime(nowPlaying.duration))
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(subtitleColor)
                    }
                }
            }
            .frame(width: 220)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
        }
        .frame(height: 70)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .overlay(backgroundColor)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .compositingGroup()
        .applyConditionalShadows(
            baseShadows: shadowColors,
            glowEnabled: settings.blueGlowEnabled,
            glowColour: settings.glowColour
        )
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Only update progress when actually playing
            if nowPlaying.state == "playing" && displayTime < nowPlaying.duration {
                displayTime += 1000
            }
        }
    }

    private func formatTime(_ milliseconds: Int) -> String {
        let seconds = milliseconds / 1000
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func titleLine(fontSize: CGFloat, height: CGFloat) -> some View {
        PlaybackMarquee(
            text: nowPlaying.title,
            font: .systemFont(ofSize: fontSize, weight: .semibold),
            color: titleColor,
            isPlaying: nowPlaying.state == "playing",
            pointsPerSecond: 50
        )
        .equatable()
        .frame(height: height)
    }
}

struct PlaybackMarquee: View, Equatable {
    fileprivate static let gap: CGFloat = 30

    let text: String
    let font: NSFont
    let color: Color
    let isPlaying: Bool
    let pointsPerSecond: Double

    func scrollDistance(in availableWidth: CGFloat) -> CGFloat? {
        guard isPlaying, availableWidth > 0 else { return nil }
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        return textWidth > availableWidth ? textWidth + Self.gap : nil
    }

    var body: some View {
        GeometryReader { geometry in
            let label = Text(text).font(Font(font as CTFont)).foregroundColor(color)
            if let distance = scrollDistance(in: geometry.size.width) {
                MarqueeCycle(label: label, distance: distance, pointsPerSecond: pointsPerSecond)
                    .id(text)
                    .id(distance)
            } else {
                label.lineLimit(1)
            }
        }
        .clipped()
    }
}

private struct MarqueeCycle: View {
    let label: Text
    let distance: CGFloat
    let pointsPerSecond: Double
    @State private var offset: CGFloat = 0

    var body: some View {
        HStack(spacing: PlaybackMarquee.gap) {
            label.lineLimit(1).fixedSize(horizontal: true, vertical: false)
            label.lineLimit(1).fixedSize(horizontal: true, vertical: false).accessibilityHidden(true)
        }
        .offset(x: offset)
        .task {
            let duration = Double(distance) / pointsPerSecond
            do {
                while !Task.isCancelled {
                    offset = 0
                    try await Task.sleep(for: .seconds(1))
                    withAnimation(.linear(duration: duration)) {
                        offset = -distance
                    }
                    try await Task.sleep(for: .seconds(duration + 2))
                }
            } catch {
                // SwiftUI cancels the task when the scrolling line changes or disappears.
            }
        }
    }
}

@MainActor
final class AlbumArtwork: ObservableObject {
    @Published private(set) var image: NSImage?
    private var latestRequest: UUID?

    func load(url: String?, fetch: (String) async -> NSImage?) async {
        guard !Task.isCancelled else { return }
        let request = UUID()
        latestRequest = request
        guard let url else {
            image = nil
            return
        }

        let loadedImage = await fetch(url)
        guard !Task.isCancelled, latestRequest == request else { return }
        image = loadedImage
    }
}

struct AlbumArtView: View {
    let image: NSImage?

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let scale = size / 140  // Base size is 140

            Group {
                if let image = image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    // Vinyl placeholder with gradient - scales to container
                    ZStack {
                        Color(hex: "2a2a2a")

                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "ffcb7d"),
                                        Color(hex: "ff920c")
                                    ]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 80 * scale
                                )
                            )
                            .frame(width: 120 * scale, height: 120 * scale)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "444444"), lineWidth: 1)
                            )

                        // Vinyl grooves
                        ForEach([50, 38, 26], id: \.self) { radius in
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                .frame(width: CGFloat(radius) * 2 * scale, height: CGFloat(radius) * 2 * scale)
                        }

                        // Center label
                        Circle()
                            .fill(Color(hex: "444444"))
                            .frame(width: 26 * scale, height: 26 * scale)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "555555"), lineWidth: 1)
                            )

                        // Center hole
                        Circle()
                            .fill(Color(hex: "2a2a2a"))
                            .frame(width: 8 * scale, height: 8 * scale)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

// Custom shape for circular album art in side layout
// Creates shape matching CSS: border-radius: 28px 50% 50% 28px
// Left side: 28px rounded corners, Right side: semicircular (50%)
struct CircularSideShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 28

        // Start at top-left with corner radius
        path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))

        // Top edge to start of right semicircle
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        // Right side - semicircular (top-right to bottom-right)
        path.addArc(
            center: CGPoint(x: rect.maxX, y: rect.midY),
            radius: rect.height / 2,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: false
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))

        // Bottom-left corner - 28px radius
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )

        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))

        // Top-left corner - 28px radius
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        path.closeSubpath()

        return path
    }
}

// Visual Effect Blur for backdrop-filter effect
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// View extension for conditional shadows with coloured glow
extension View {
    func applyConditionalShadows(
        baseShadows: [(Color, CGFloat, CGFloat, CGFloat)],
        glowEnabled: Bool,
        glowColour: GlowColour
    ) -> some View {
        self.modifier(ConditionalShadowModifier(baseShadows: baseShadows, glowEnabled: glowEnabled, glowColour: glowColour))
    }
}

struct ConditionalShadowModifier: ViewModifier {
    let baseShadows: [(Color, CGFloat, CGFloat, CGFloat)]
    let glowEnabled: Bool
    let glowColour: GlowColour

    var glowColors: (Color, Color) {
        switch glowColour {
        case .blue:
            return (Color(red: 20/255, green: 120/255, blue: 255/255), Color(red: 40/255, green: 140/255, blue: 255/255))
        case .purple:
            return (Color(red: 160/255, green: 80/255, blue: 200/255), Color(red: 180/255, green: 100/255, blue: 220/255))
        case .pink:
            return (Color(red: 255/255, green: 80/255, blue: 150/255), Color(red: 255/255, green: 100/255, blue: 170/255))
        case .orange:
            return (Color(red: 255/255, green: 140/255, blue: 40/255), Color(red: 255/255, green: 160/255, blue: 60/255))
        case .green:
            return (Color(red: 40/255, green: 200/255, blue: 120/255), Color(red: 60/255, green: 220/255, blue: 140/255))
        case .cyan:
            return (Color(red: 40/255, green: 200/255, blue: 220/255), Color(red: 60/255, green: 220/255, blue: 240/255))
        }
    }

    func body(content: Content) -> some View {
        Group {
            if glowEnabled {
                let colors = glowColors
                content
                    .shadow(color: baseShadows[0].0, radius: baseShadows[0].1, x: baseShadows[0].2, y: baseShadows[0].3)
                    .shadow(color: baseShadows[1].0, radius: baseShadows[1].1, x: baseShadows[1].2, y: baseShadows[1].3)
                    .shadow(color: colors.0.opacity(0.5), radius: 7.5, x: 0, y: 0)
                    .shadow(color: colors.0.opacity(0.4), radius: 3.75, x: 0, y: 0)
                    .shadow(color: colors.1.opacity(0.6), radius: 2, x: 0, y: 0)
            } else {
                content
                    .shadow(color: baseShadows[0].0, radius: baseShadows[0].1, x: baseShadows[0].2, y: baseShadows[0].3)
                    .shadow(color: baseShadows[1].0, radius: baseShadows[1].1, x: baseShadows[1].2, y: baseShadows[1].3)
            }
        }
    }
}

// Type-erased shape helper
struct AnyShape: Shape {
    private let _path: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

// Hex color extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
