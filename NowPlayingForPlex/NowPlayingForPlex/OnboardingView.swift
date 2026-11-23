import SwiftUI

struct OnboardingView: View {
    @State private var serverUrl: String
    @State private var token = ""
    @State private var allowsLocalHTTP: Bool
    @State private var validationTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    let onComplete: (PlexConfig) -> Void
    let onClose: (() -> Void)?
    let retrySavedConnection: (() -> Bool)?

    init(
        onComplete: @escaping (PlexConfig) -> Void,
        onClose: (() -> Void)? = nil,
        initialServerURL: String = "",
        initialAllowsLocalHTTP: Bool = false,
        savedConnectionMessage: String? = nil,
        retrySavedConnection: (() -> Bool)? = nil
    ) {
        self.onComplete = onComplete
        self.onClose = onClose
        self.retrySavedConnection = retrySavedConnection
        _serverUrl = State(initialValue: initialServerURL)
        _allowsLocalHTTP = State(initialValue: initialAllowsLocalHTTP)
        _errorMessage = State(initialValue: savedConnectionMessage)
    }

    enum Field: Hashable {
        case serverUrl
        case token
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                            .resizable()
                            .frame(width: 48, height: 48)
                            .accessibilityLabel("NowPlaying for Plex application icon")

                        Text("NowPlaying for Plex")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text("Let's get you set up!")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.9))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("NowPlaying for Plex. Let's get you set up!")
                .overlay { WindowDragArea().accessibilityHidden(true) }

                // Instructions
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            Text("1")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 24, height: 24)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 229/255, green: 160/255, blue: 13/255),
                                            Color(red: 204/255, green: 123/255, blue: 2/255)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Get your Plex Token")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.95))

                                VStack(alignment: .leading, spacing: 4) {
                                    BulletPoint(text: "Open the Plex Desktop or Web App")
                                    BulletPoint(text: "Play any item")
                                    BulletPoint(text: "Click the vertical dots (⋮) then 'Get Info'")
                                    BulletPoint(text: "Click 'View XML'")
                                    BulletPoint(text: "Copy the X-Plex-Token value (it's at the end of the URL)")
                                }
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Step 1: Get your Plex Token. Open the Plex Desktop or Web App, Play any item, Click the vertical dots then Get Info, Click View XML, Copy the X-Plex-Token value at the end of the URL")

                    Button(action: {
                        NSWorkspace.shared.open(URL(string: "https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/")!)
                    }) {
                        Text("How to find your Plex Token")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(red: 229/255, green: 160/255, blue: 13/255))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 36)
                    .accessibilityLabel("Open support article: How to find your Plex Token")

                    InstructionStep(
                        number: 2,
                        title: "Enter your Plex Server URL",
                        description: "Use HTTPS. On a trusted local network, you can allow unencrypted HTTP below."
                    )
                }

                // Input Fields
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Plex Token")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))

                        TransparentSecureField(
                            placeholder: "Your X-Plex-Token",
                            text: $token,
                            isFocused: focusedField == .token
                        )
                        .padding(12)
                        .frame(height: 44)
                        .background(
                            ZStack {
                                VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                                Color.black.opacity(0.4)
                            }
                            .cornerRadius(8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    focusedField == .token ? Color(red: 229/255, green: 160/255, blue: 13/255).opacity(0.5) : Color.white.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                        .focused($focusedField, equals: .token)
                        .accessibilityLabel("Plex Token")
                        .accessibilityHint("Enter your X-Plex-Token from the Plex app")
                        .onSubmit {
                            focusedField = .serverUrl
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server URL")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))

                        TransparentTextField(
                            placeholder: "https://plex.example.com:32400",
                            text: $serverUrl,
                            isFocused: focusedField == .serverUrl
                        )
                        .padding(12)
                        .frame(height: 44)
                        .background(
                            ZStack {
                                VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                                Color.black.opacity(0.4)
                            }
                            .cornerRadius(8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    focusedField == .serverUrl ? Color(red: 229/255, green: 160/255, blue: 13/255).opacity(0.5) : Color.white.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                        .focused($focusedField, equals: .serverUrl)
                        .accessibilityLabel("Server URL")
                        .accessibilityHint("Enter your Plex server address")
                        .onSubmit(validateAndSave)

                        Toggle("Allow HTTP on my local network", isOn: $allowsLocalHTTP)
                            .toggleStyle(.checkbox)
                            .tint(Color(red: 229/255, green: 160/255, blue: 13/255))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.9))
                            .help("HTTP sends your Plex token without encryption. Use it only on a network you trust.")
                            .accessibilityHint("HTTP sends your Plex token without encryption.")
                    }
                }
                .disabled(isValidating)

                // Error message
                if let errorMessage = errorMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(Color(red: 255/255, green: 100/255, blue: 100/255))
                            .accessibilityHidden(true)

                        Text(errorMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.95))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red.opacity(0.4), lineWidth: 1)
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(errorMessage)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
                }

                if let retrySavedConnection {
                    Button("Retry Saved Connection") {
                        if !retrySavedConnection() {
                            errorMessage = "Still unable to read your saved Plex connection. Check Keychain access and try again."
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(red: 1, green: 0.72, blue: 0.31))
                    .disabled(isValidating)
                }

                // Continue Button
                Button(action: validateAndSave) {
                    HStack(spacing: 8) {
                        if isValidating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            Text("Validating...")
                        } else {
                            Text("Continue")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                    .background(
                        Group {
                            if isFormValid {
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 229/255, green: 160/255, blue: 13/255),
                                        Color(red: 204/255, green: 123/255, blue: 2/255)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            } else {
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.25)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        }
                    )
                    .cornerRadius(10)
                    .shadow(color: isFormValid ? Color.black.opacity(0.15) : .clear, radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!isFormValid || isValidating)
                .onHover { isHovering in
                    if isHovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .padding(.top, 8)
                .keyboardShortcut(.return, modifiers: [])
                .accessibilityLabel(isValidating ? "Validating connection" : "Continue")
                .accessibilityHint(isFormValid ? "Press to validate your Plex server credentials" : "Enter server URL and token to continue")
            }
            .padding(20)
        }
        .frame(width: 520, height: 600)
        .background(
            Color(red: 13/255, green: 13/255, blue: 13/255).opacity(0.85)
        )
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )

            // Close button (overlay on top-right)
            Button(action: {
                validationTask?.cancel()
                onClose?()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { isHovering in
                if isHovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .padding([.top, .trailing], 16)
            .accessibilityLabel("Close")
        }
        .onDisappear {
            validationTask?.cancel()
        }
    }

    private var isValidating: Bool {
        validationTask != nil
    }

    private var isFormValid: Bool {
        !serverUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func validateAndSave() {
        guard isFormValid, !isValidating else { return }
        focusedField = nil
        errorMessage = nil
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanToken.unicodeScalars.allSatisfy({ (33...126).contains($0.value) }) else {
            errorMessage = "Paste the Plex token without spaces."
            return
        }
        let address: PlexServerAddress
        let allowHTTP = allowsLocalHTTP
        do {
            address = try PlexServerAddress(serverUrl, allowsLocalHTTP: allowHTTP)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        validationTask = Task { @MainActor in
            defer { validationTask = nil }
            do {
                let client = PlexClient(address: address, token: cleanToken, clientIdentifier: "plex-desktop-widget-validation")
                _ = try await client.sessions()
                try Task.checkCancellation()
                let config = PlexConfig(
                    plexServerUrl: address.url.absoluteString,
                    plexToken: cleanToken,
                    allowsLocalHTTP: address.url.scheme == "http"
                )
                guard ConfigManager.shared.saveConfig(serverUrl: config.plexServerUrl, token: config.plexToken, allowsLocalHTTP: config.allowsLocalHTTP) else {
                    errorMessage = "Your Plex connection could not be saved. Check Keychain access and try again."
                    return
                }
                onComplete(config)
            } catch let error as URLError where [.secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot].contains(error.code) {
                if !Task.isCancelled {
                    errorMessage = "Check the server address and its HTTPS certificate, then try again."
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 24, height: 24)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 229/255, green: 160/255, blue: 13/255),
                            Color(red: 204/255, green: 123/255, blue: 2/255)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// Custom transparent text field with NSViewRepresentable
struct TransparentTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool

    func makeNSView(context: Context) -> NSTextField {
        let textField = CustomNSTextField()
        textField.stringValue = ""
        textField.placeholderString = placeholder
        textField.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: NSColor.white.withAlphaComponent(0.5)]
        )
        textField.isBordered = false
        textField.isBezeled = false
        textField.backgroundColor = .clear
        textField.textColor = .white
        textField.font = .systemFont(ofSize: 13)
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        textField.drawsBackground = false
        textField.isEditable = true
        textField.isSelectable = true

        // Ensure the field editor (cell) is editable
        if let cell = textField.cell as? NSTextFieldCell {
            cell.isEditable = true
            cell.isSelectable = true
        }

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.isEnabled = context.environment.isEnabled
        // Only update if not currently editing (prevents interference with field editor)
        if nsView.currentEditor() == nil {
            nsView.stringValue = text
        }
        nsView.textColor = .white
    }

    // Custom NSTextField that accepts first responder
    class CustomNSTextField: NSTextField {
        override func becomeFirstResponder() -> Bool {
            let didBecome = super.becomeFirstResponder()
            if didBecome {
                currentEditor()?.selectedRange = NSRange(location: stringValue.count, length: 0)
            }
            return didBecome
        }

        override var acceptsFirstResponder: Bool {
            return true
        }

        override func textDidChange(_ notification: Notification) {
            super.textDidChange(notification)
            // Force redraw with white text
            textColor = .white
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TransparentTextField

        init(_ parent: TransparentTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
    }
}

// Custom transparent secure field
struct TransparentSecureField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool

    func makeNSView(context: Context) -> NSSecureTextField {
        let textField = CustomNSSecureTextField()
        textField.stringValue = ""
        textField.placeholderString = placeholder
        textField.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: NSColor.white.withAlphaComponent(0.5)]
        )
        textField.isBordered = false
        textField.isBezeled = false
        textField.backgroundColor = .clear
        textField.textColor = .white
        textField.font = .systemFont(ofSize: 13)
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        textField.drawsBackground = false
        textField.isEditable = true
        textField.isSelectable = true

        // Ensure the field editor (cell) is editable
        if let cell = textField.cell as? NSSecureTextFieldCell {
            cell.isEditable = true
            cell.isSelectable = true
        }

        return textField
    }

    func updateNSView(_ nsView: NSSecureTextField, context: Context) {
        nsView.isEnabled = context.environment.isEnabled
        // Only update if not currently editing (prevents interference with field editor)
        if nsView.currentEditor() == nil {
            nsView.stringValue = text
        }
        nsView.textColor = .white
    }

    // Custom NSSecureTextField that accepts first responder
    class CustomNSSecureTextField: NSSecureTextField {
        override func becomeFirstResponder() -> Bool {
            let didBecome = super.becomeFirstResponder()
            if didBecome {
                currentEditor()?.selectedRange = NSRange(location: stringValue.count, length: 0)
            }
            return didBecome
        }

        override var acceptsFirstResponder: Bool {
            return true
        }

        override func textDidChange(_ notification: Notification) {
            super.textDidChange(notification)
            // Force redraw with white text
            textColor = .white
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TransparentSecureField

        init(_ parent: TransparentSecureField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSSecureTextField else { return }
            parent.text = textField.stringValue
        }
    }
}

// Wrapper to add the background styling
struct TransparentTextFieldStyled<Field: View>: View {
    let field: Field
    var isFocused: Bool

    var body: some View {
        field
            .frame(height: 44)
            .padding(.horizontal, 12)
            .background(
                ZStack {
                    // Backdrop blur layer
                    VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)

                    // Darker tinted overlay
                    Color.black.opacity(0.4)
                }
                .cornerRadius(8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isFocused ? Color(red: 229/255, green: 160/255, blue: 13/255).opacity(0.5) : Color.white.opacity(0.2),
                        lineWidth: 1
                    )
            )
            .shadow(color: isFocused ? Color(red: 229/255, green: 160/255, blue: 13/255).opacity(0.1) : .clear, radius: 3)
    }
}

#Preview {
    OnboardingView(onComplete: { _ in })
}
