import SwiftUI

struct SettingsView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject var settings: WidgetSettings
    @StateObject private var launchAtLogin = LaunchAtLoginManager.shared
    @State private var isServerReachable: Bool = true
    @State private var showResetConfirmation: Bool = false

    // Mask the native material as well as its SwiftUI background.
    private static let backgroundMask: NSImage = {
        let radius: CGFloat = 20
        let size = NSSize(width: radius * 2 + 1, height: radius * 2 + 1)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            NSBezierPath(rect: NSRect(x: 0, y: radius, width: rect.width, height: rect.height - radius)).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }()

    private var serverUrl: String {
        ConfigManager.shared.getServerUrl() ?? "Not configured"
    }

    private var displayUrl: String {
        // Strip http:// or https:// and show just host:port
        var url = serverUrl
        if url.hasPrefix("http://") {
            url = String(url.dropFirst(7))
        } else if url.hasPrefix("https://") {
            url = String(url.dropFirst(8))
        }
        // Remove trailing slash if present
        if url.hasSuffix("/") {
            url = String(url.dropLast())
        }
        return url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                // Theme
                VStack(alignment: .leading, spacing: 10) {
                    Text("Theme")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    SegmentedControl(
                        options: [Theme.light, Theme.dark],
                        selection: $settings.theme
                    )
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Theme")

                // Layout Style
                VStack(alignment: .leading, spacing: 10) {
                    Text("Layout Style")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    SegmentedControl(
                        options: [LayoutStyle.side, LayoutStyle.overlay, LayoutStyle.mini],
                        selection: $settings.layoutStyle
                    )
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Layout Style")

                // Album Art Shape
                VStack(alignment: .leading, spacing: 10) {
                    Text("Album Art Shape")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    SegmentedControl(
                        options: [AlbumArtShape.square, AlbumArtShape.circular],
                        selection: $settings.albumArtShape
                    )
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Album Art Shape")

                // Glow Effect
                VStack(alignment: .leading, spacing: 10) {
                    Text("Glow Effect")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    SegmentedControlBool(
                        labels: ["On", "Off"],
                        selection: $settings.blueGlowEnabled
                    )
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Glow Effect")

                // Glow Colour (only visible when Glow Effect is On)
                if settings.blueGlowEnabled {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Glow Colour")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)

                        ColourPicker(selection: $settings.glowColour)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Glow colour")
                }

                // Divider
                Divider()

                // Launch at Login
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        Text("Start widget when you log in")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    PlexToggle(isOn: $launchAtLogin.isEnabled)
                        .accessibilityLabel("Launch at login")
                }
                .padding(12)
                .background(SettingsAppearance.controlFill)
                .cornerRadius(10)

                // Server Status + Quit
                HStack(alignment: .top) {
                    // Left side: Server info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isServerReachable ?
                                    Color(red: 40/255, green: 200/255, blue: 120/255) :
                                    Color(red: 255/255, green: 80/255, blue: 150/255))
                                .frame(width: 8, height: 8)

                            Text(displayUrl)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Server \(displayUrl)")
                        .accessibilityValue(isServerReachable ? "Connected" : "Unavailable")

                        Button(action: {
                            showResetConfirmation = true
                        }) {
                            Text("Change Server")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(minHeight: 28, alignment: .leading)
                        .padding(.leading, 14)
                    }
                    .alert("Reset Server Configuration?", isPresented: $showResetConfirmation) {
                        Button("Cancel", role: .cancel) { }
                        Button("Reset", role: .destructive) {
                            ConfigManager.shared.clearConfig()
                            NotificationCenter.default.post(name: NSNotification.Name("ShowOnboarding"), object: nil)
                        }
                    } message: {
                        Text("This will clear your server settings and show the setup screen.")
                    }

                    Spacer()

                    // Right side: Quit button
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "power")
                                .font(.system(size: 12, weight: .medium))
                            Text("Quit")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(SettingsAppearance.controlFill)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(24)
        }
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
        .modifier(SettingsPanelSurface(reduceTransparency: reduceTransparency, maskImage: Self.backgroundMask))
        .onAppear {
            launchAtLogin.checkStatus()
            checkServerReachability()
        }
    }

    private func checkServerReachability() {
        guard let config = ConfigManager.shared.loadConfig(),
              let url = URL(string: "\(config.plexServerUrl)/status/sessions") else {
            isServerReachable = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue(config.plexToken, forHTTPHeaderField: "X-Plex-Token")
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    isServerReachable = (200...299).contains(httpResponse.statusCode)
                } else {
                    isServerReachable = false
                }
            }
        }.resume()
    }
}

private enum SettingsAppearance {
    static let accent = Color(red: 229/255, green: 160/255, blue: 13/255)
    static let controlFill = Color(nsColor: .labelColor).opacity(0.07)
}

private struct SettingsPanelSurface: ViewModifier {
    let reduceTransparency: Bool
    let maskImage: NSImage

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 20,
            bottomTrailingRadius: 20,
            topTrailingRadius: 0
        )
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .windowBackgroundColor), in: shape)
        } else if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(
                VisualEffectView(material: .popover, blendingMode: .behindWindow, maskImage: maskImage)
                    .clipShape(shape)
            )
        }
    }
}

// MARK: - Segmented Control
struct SegmentedControl<T: RawRepresentable & Equatable>: View where T.RawValue == String {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let options: [T]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isSelected = selection == option
                Button(action: {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        selection = option
                    }
                }) {
                    Text(option.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? .black : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(isSelected ? SettingsAppearance.accent : .clear)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(SettingsAppearance.controlFill)
        .cornerRadius(10)
    }
}

// MARK: - Boolean Segmented Control (for On/Off)
struct SegmentedControlBool: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let labels: [String]
    @Binding var selection: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<labels.count, id: \.self) { index in
                let isOn = index == 0
                let isSelected = selection == isOn
                Button(action: {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        selection = isOn
                    }
                }) {
                    Text(labels[index])
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? .black : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(isSelected ? SettingsAppearance.accent : .clear)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(SettingsAppearance.controlFill)
        .cornerRadius(10)
    }
}

// MARK: - Colour Picker
struct ColourPicker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: GlowColour

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
            ForEach(GlowColour.allCases, id: \.self) { colour in
                Button(action: {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        selection = colour
                    }
                }) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colour.gradient)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if selection == colour {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary, lineWidth: 2)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 1)
                            }
                        }
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(colour.rawValue.capitalized)
                .accessibilityAddTraits(selection == colour ? .isSelected : [])
            }
        }
    }
}

// MARK: - Plex Toggle Switch
struct PlexToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("Launch at login", isOn: $isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(SettingsAppearance.accent)
            .frame(minWidth: 40, minHeight: 28)
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            SettingsView(settings: WidgetSettings.shared)
        }
        .frame(width: 500, height: 700)
    }
}
