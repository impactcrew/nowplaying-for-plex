import SwiftUI

struct SettingsView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject var settings: WidgetSettings
    @ObservedObject var plexAPI: PlexAPI
    @StateObject private var launchAtLogin = LaunchAtLoginManager.shared
    let changeServer: () -> Void
    let resetPosition: () -> Void
    let dismiss: () -> Void

    private var connectionStatus: String {
        if plexAPI.isLoading { return "Checking connection" }
        return plexAPI.errorMessage == nil ? "Connected" : "Unavailable"
    }

    private var connectionColor: Color {
        if plexAPI.isLoading { return .secondary }
        if plexAPI.errorMessage != nil { return Color(red: 1, green: 80/255, blue: 150/255) }
        return Color(red: 40/255, green: 200/255, blue: 120/255)
    }

    private var serverUrl: String {
        plexAPI.displayServerURL ?? "Plex server"
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
                    HStack {
                        Text("Layout Style")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)

                        Spacer()

                        Button(action: resetPosition) {
                            Text("Reset Position")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(minHeight: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

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

                Picker("Playback Source", selection: $plexAPI.preferredSourceID) {
                    Text("Automatic").tag(nil as String?)
                    if let preferredSourceID = plexAPI.preferredSourceID,
                       !plexAPI.availableSources.contains(where: { $0.id == preferredSourceID }) {
                        Text("Selected source (offline)").tag(preferredSourceID as String?)
                    }
                    ForEach(plexAPI.availableSources) { source in
                        Text(source.label).tag(source.id as String?)
                    }
                }
                .pickerStyle(.menu)

                // Server status and Quit
                HStack(alignment: .top) {
                    // Left side: Server info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(connectionColor)
                                .frame(width: 8, height: 8)

                            Text(displayUrl)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Server \(displayUrl)")
                        .accessibilityValue(connectionStatus)

                        Button(action: changeServer) {
                            Text("Change Server")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.leading, 14)
                    }

                    Spacer()

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
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
        .modifier(SettingsPanelSurface(reduceTransparency: reduceTransparency))
        .preferredColorScheme(.dark)
        .onExitCommand(perform: dismiss)
        .onAppear {
            launchAtLogin.checkStatus()
        }
    }
}

private enum SettingsAppearance {
    static let controlFill = Color.white.opacity(0.1)
}

private struct SettingsPanelSurface: ViewModifier {
    let reduceTransparency: Bool

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
        } else {
            content.background(
                Color(red: 13/255, green: 13/255, blue: 13/255).opacity(0.60),
                in: shape
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
                        .background {
                            if isSelected {
                                BrandAppearance.amberGradient
                            }
                        }
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
                        .background {
                            if isSelected {
                                BrandAppearance.amberGradient
                            }
                        }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .overlay {
                        if isOn {
                            Capsule().fill(BrandAppearance.amberGradient)
                        }
                    }

                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .padding(2)
            }
            .frame(width: 40, height: 24)
            .frame(minHeight: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle("Launch at login", isOn: $isOn)
        }
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            SettingsView(
                settings: WidgetSettings.shared,
                plexAPI: PlexAPI(serverUrl: "", token: ""),
                changeServer: {},
                resetPosition: {},
                dismiss: {}
            )
        }
        .frame(width: 500, height: 700)
    }
}
