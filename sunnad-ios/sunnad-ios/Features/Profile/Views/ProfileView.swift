import PhotosUI
import SwiftUI

struct ProfileView: View {
    @Environment(\.colorScheme) private var colorScheme

    let user: UIUserState
    let habits: [UIHabit]
    let savedQuotes: [UISavedQuote]
    let selectedLanguage: AppLanguage
    @Binding var selectedAppearance: AppAppearance
    @Binding var notificationPreferences: UINotificationPreferences

    let onManageHabits: () -> Void
    let onOpenSavedQuotes: () -> Void
    let onOpenLanguagePicker: () -> Void
    let onOpenInsights: () -> Void
    let onSignIn: () -> Void
    let onSignOut: () -> Void
    let onEditProfile: () -> Void
    let onChangePassword: () -> Void
    let onDeleteData: () -> Void
    let onDeleteAccount: () -> Void
    let onRefresh: () async -> Void
    let debugDiagnosticsText: String?
    let privacyURL: URL
    let helpURL: URL

    @State private var showsNotificationSettings = false
    @State private var showsFeedback = false
    @State private var showsAppearancePicker = false
    @State private var confirmsSignOut = false
    @State private var confirmsDeleteData = false
    @State private var confirmsDeleteAccount = false

    var body: some View {
        ScreenScaffold(contentTopPadding: 8) {
            Text(L10n.t("tab.profile"))
                .font(.title.weight(.bold))

            SectionHeader(title: L10n.t("profile.account"))

            Card(contentPadding: 0) {
                if user.isGuest {
                    profileLinkRow(
                        title: L10n.t("profile.guest"),
                        value: nil,
                        subtitle: L10n.t("profile.tap_sign_in"),
                        action: onSignIn
                    )
                } else {
                    Button(action: onEditProfile) {
                        HStack(spacing: 12) {
                            avatarView
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name ?? "")
                                    .font(.body.weight(.semibold))
                                Text(user.email ?? "")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(L10n.t("profile.edit.tap"))
                                    .font(.caption)
                                    .foregroundStyle(SunnadTheme.primary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(16)
                    }
                    .buttonStyle(.plain)
                }
            }

            SectionHeader(title: L10n.t("profile.saved"))
            Card(contentPadding: 0) {
                profileLinkRow(
                    title: L10n.t("profile.saved_quotes"),
                    value: "\(savedQuotes.count)",
                    action: onOpenSavedQuotes
                )
            }

            SectionHeader(title: L10n.t("profile.habits"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    profileLinkRow(
                        title: L10n.t("profile.manage_habits"),
                        value: "\(habits.count)",
                        action: onManageHabits
                    )
                    Divider().padding(.leading, 16)
                    profileLinkRow(
                        title: L10n.t("profile.insights"),
                        action: onOpenInsights
                    )
                }
            }

            SectionHeader(title: L10n.t("profile.settings"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    profileLinkRow(
                        title: L10n.t("profile.appearance"),
                        value: L10n.t(selectedAppearance.nameKey),
                        action: { showsAppearancePicker = true }
                    )
                    Divider().padding(.leading, 16)
                    profileLinkRow(
                        title: L10n.t("profile.language"),
                        value: L10n.t(selectedLanguage.nameKey),
                        action: onOpenLanguagePicker
                    )
                    Divider().padding(.leading, 16)
                    profileLinkRow(
                        title: L10n.t("profile.notifications"),
                        action: { showsNotificationSettings = true }
                    )
                    if !user.isGuest {
                        Divider().padding(.leading, 16)
                        profileLinkRow(
                            title: L10n.t("profile.change_password"),
                            action: onChangePassword
                        )
                    }
                    Divider().padding(.leading, 16)
                    externalLinkRow(
                        title: L10n.t("profile.privacy"),
                        url: privacyURL
                    )
                }
            }

            SectionHeader(title: L10n.t("profile.support"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    externalLinkRow(
                        title: L10n.t("profile.help_faq"),
                        url: helpURL
                    )
                    Divider().padding(.leading, 16)
                    profileLinkRow(
                        title: L10n.t("profile.send_feedback"),
                        action: { showsFeedback = true }
                    )
                }
            }

            SectionHeader(title: L10n.t("profile.danger_zone"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    if !user.isGuest {
                        dangerRow(
                            title: L10n.t("profile.sign_out"),
                            icon: "rectangle.portrait.and.arrow.right",
                            action: { confirmsSignOut = true }
                        )
                        Divider().padding(.leading, 16)
                        dangerRow(
                            title: L10n.t("profile.delete_account"),
                            icon: "person.crop.circle.badge.xmark",
                            action: { confirmsDeleteAccount = true }
                        )
                    } else {
                        dangerRow(
                            title: L10n.t("profile.delete_data"),
                            icon: "trash",
                            action: { confirmsDeleteData = true }
                        )
                    }
                }
            }

            Text(L10n.t("profile.version"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            if let debugDiagnosticsText, !debugDiagnosticsText.isEmpty {
                Text(debugDiagnosticsText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sunnadSolidBars()
        .background(alignment: .top) {
            if colorScheme == .dark {
                Color.black
                    .frame(height: 96)
                    .ignoresSafeArea(edges: .top)
            }
        }
        .refreshable {
            await onRefresh()
        }
        .sheet(isPresented: $showsNotificationSettings) {
            NotificationSettingsSheet(preferences: $notificationPreferences)
        }
        .sheet(isPresented: $showsFeedback) {
            FeedbackSheetView()
        }
        .confirmationDialog(
            L10n.t("profile.appearance"),
            isPresented: $showsAppearancePicker,
            titleVisibility: .visible
        ) {
            ForEach(AppAppearance.allCases) { option in
                Button(L10n.t(option.nameKey)) {
                    selectedAppearance = option
                }
            }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        }
        .alert(L10n.t("profile.sign_out"), isPresented: $confirmsSignOut) {
            Button(L10n.t("common.cancel"), role: .cancel) {}
            Button(L10n.t("profile.sign_out"), role: .destructive) {
                onSignOut()
            }
        } message: {
            Text(L10n.t("profile.sign_out.confirm"))
        }
        .alert(L10n.t("profile.delete_data"), isPresented: $confirmsDeleteData) {
            Button(L10n.t("common.cancel"), role: .cancel) {}
            Button(L10n.t("profile.delete_data"), role: .destructive) {
                onDeleteData()
            }
        } message: {
            Text(L10n.t("profile.delete_data.confirm"))
        }
        .alert(L10n.t("profile.delete_account"), isPresented: $confirmsDeleteAccount) {
            Button(L10n.t("common.cancel"), role: .cancel) {}
            Button(L10n.t("profile.delete_account"), role: .destructive) {
                onDeleteAccount()
            }
        } message: {
            Text(L10n.t("profile.delete_account.confirm"))
        }
    }

    private func profileLinkRow(
        title: String,
        value: String? = nil,
        subtitle: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            rowContent(title: title, value: value, subtitle: subtitle, trailingSymbol: "chevron.right")
        }
        .buttonStyle(.plain)
    }

    private func externalLinkRow(title: String, url: URL) -> some View {
        Link(destination: url) {
            rowContent(title: title, trailingSymbol: "arrow.up.right")
        }
        .buttonStyle(.plain)
    }

    private func rowContent(
        title: String,
        value: String? = nil,
        subtitle: String? = nil,
        trailingSymbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if let value {
                    Text(value)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: trailingSymbol)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(SunnadTheme.primary)
            }
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    private func dangerRow(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.red)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.red)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var avatarView: some View {
        if let avatarURL = user.avatarURL {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(SunnadTheme.primary)
                        .padding(4)
                }
            }
            .frame(width: 42, height: 42)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(SunnadTheme.primary)
        }
    }
}

struct EditProfileView: View {
    let user: UIUserState
    let authErrorMessage: String?
    let authSuccessMessage: String?
    let onBack: () -> Void
    let onSaveUsername: (String) -> Void
    let onUploadAvatar: (Data, String) -> Void
    let onRemoveAvatar: () -> Void
    let onClearMessage: () -> Void

    @State private var username: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false

    init(
        user: UIUserState,
        authErrorMessage: String?,
        authSuccessMessage: String?,
        onBack: @escaping () -> Void,
        onSaveUsername: @escaping (String) -> Void,
        onUploadAvatar: @escaping (Data, String) -> Void,
        onRemoveAvatar: @escaping () -> Void,
        onClearMessage: @escaping () -> Void
    ) {
        self.user = user
        self.authErrorMessage = authErrorMessage
        self.authSuccessMessage = authSuccessMessage
        self.onBack = onBack
        self.onSaveUsername = onSaveUsername
        self.onUploadAvatar = onUploadAvatar
        self.onRemoveAvatar = onRemoveAvatar
        self.onClearMessage = onClearMessage
        _username = State(initialValue: user.name ?? "")
    }

    private var normalizedUsername: String {
        username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private var usernameIsValid: Bool {
        let value = normalizedUsername
        guard !value.isEmpty else {
            return false
        }
        return value.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil
    }

    private var canSave: Bool {
        usernameIsValid && normalizedUsername != (user.name ?? "").lowercased()
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    CompactBackButton(action: onBack)
                    Text(L10n.t("profile.edit.title"))
                        .font(.title.weight(.bold))
                    Spacer(minLength: 0)
                }

                Text(L10n.t("profile.edit.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let authErrorMessage, !authErrorMessage.isEmpty {
                    statusToast(message: authErrorMessage, icon: "exclamationmark.triangle.fill", accent: .red)
                } else if let authSuccessMessage, !authSuccessMessage.isEmpty {
                    statusToast(message: authSuccessMessage, icon: "checkmark.circle.fill", accent: .green)
                }

                Card {
                    VStack(spacing: 14) {
                        avatarView

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Text(L10n.t("profile.edit.avatar.change"))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(SunnadTheme.primary)
                        }
                        .disabled(isUploadingPhoto)

                        if user.avatarURL != nil {
                            Button(L10n.t("profile.edit.avatar.remove"), role: .destructive) {
                                onClearMessage()
                                onRemoveAvatar()
                            }
                            .font(.footnote.weight(.semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                Card(contentPadding: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledTextFieldRow(
                            label: L10n.t("auth.username"),
                            placeholder: L10n.t("auth.username.placeholder"),
                            value: $username
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)

                        Text(L10n.t("profile.edit.username.hint"))
                            .font(.caption)
                            .foregroundStyle(username.isEmpty || usernameIsValid ? Color.secondary : Color.red)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 10)
                    }
                }

                PrimaryButton(title: L10n.t("common.save"), isEnabled: canSave) {
                    onClearMessage()
                    onSaveUsername(normalizedUsername)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, max(10, proxy.safeAreaInsets.bottom + 4))
            .background(SunnadTheme.background.ignoresSafeArea())
            .onChange(of: username) { _, _ in
                onClearMessage()
            }
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                Task {
                    isUploadingPhoto = true
                    defer {
                        isUploadingPhoto = false
                        selectedPhotoItem = nil
                    }

                    guard let data = try? await item.loadTransferable(type: Data.self) else {
                        onClearMessage()
                        onUploadAvatar(Data(), "application/octet-stream")
                        return
                    }

                    let mimeType = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
                    onClearMessage()
                    onUploadAvatar(data, mimeType)
                }
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let avatarURL = user.avatarURL {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(SunnadTheme.primary)
                        .padding(8)
                }
            }
            .frame(width: 92, height: 92)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(SunnadTheme.primary)
                .frame(width: 92, height: 92)
        }
    }

    private func statusToast(message: String, icon: String, accent: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(accent)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
    }
}
