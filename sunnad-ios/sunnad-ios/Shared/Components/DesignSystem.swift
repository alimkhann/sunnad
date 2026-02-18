import SwiftUI

enum SunnadTheme {
    static let background = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let border = Color(.separator).opacity(0.18)
    static let primary = Color.green
}

struct Card<Content: View>: View {
    let contentPadding: CGFloat
    @ViewBuilder let content: Content

    init(contentPadding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.contentPadding = contentPadding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SunnadTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SunnadTheme.border, lineWidth: 0.5)
        )
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .tracking(0.5)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

enum SelectionIndicatorPlacement: Equatable {
    case leading
    case trailing
}

struct SelectableRow: View {
    let title: String
    var subtitle: String? = nil
    var iconSystemName: String? = nil
    let isSelected: Bool
    var indicatorPlacement: SelectionIndicatorPlacement = .leading
    var showsDivider = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    if indicatorPlacement == .leading {
                        indicator
                    }

                    if let iconSystemName {
                        Image(systemName: iconSystemName)
                            .font(.body)
                            .foregroundStyle(SunnadTheme.primary)
                            .frame(width: 18, height: 18)
                            .padding(8)
                            .background(Circle().fill(Color(.tertiarySystemFill)))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)

                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 8)

                    if indicatorPlacement == .trailing {
                        indicator
                    }
                }
                .contentShape(Rectangle())
                .padding(.vertical, 12)

                if showsDivider {
                    Divider()
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var indicator: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle.fill")
            .font(.body)
            .foregroundStyle(isSelected ? SunnadTheme.primary : Color(.quaternaryLabel))
            .accessibilityHidden(true)
    }
}

struct PrimaryPillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(
                Capsule(style: .continuous)
                    .fill(isEnabled ? SunnadTheme.primary : Color(.systemGray3))
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct SecondaryPillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(isEnabled ? .primary : .secondary)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(SunnadTheme.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(PrimaryPillButtonStyle())
            .disabled(!isEnabled)
    }
}

struct SecondaryButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(SecondaryPillButtonStyle())
            .disabled(!isEnabled)
    }
}

struct CompactBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.headline.weight(.semibold))
                .foregroundStyle(SunnadTheme.primary)
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(Color(.tertiarySystemFill))
                )
        }
        .accessibilityLabel(L10n.t("common.back"))
    }
}

struct ScreenScaffold<Content: View, Footer: View>: View {
    let title: String?
    let titleDisplayMode: NavigationBarItem.TitleDisplayMode
    let contentTopPadding: CGFloat?
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    init(
        title: String? = nil,
        titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large,
        contentTopPadding: CGFloat? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.titleDisplayMode = titleDisplayMode
        self.contentTopPadding = contentTopPadding
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let title {
                        Text(title)
                            .font(titleFont)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    content
                }
                .padding(.horizontal, 12)
                .padding(.top, resolvedTopPadding)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if Footer.self != EmptyView.self {
                footer
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .background(SunnadTheme.background)
            }
        }
        .background(SunnadTheme.background.ignoresSafeArea())
    }

    private var resolvedTopPadding: CGFloat {
        if let contentTopPadding {
            return contentTopPadding
        }

        return title == nil ? 20 : 8
    }

    private var titleFont: Font {
        switch titleDisplayMode {
        case .large:
            .title.weight(.bold)
        case .inline, .automatic:
            .headline.weight(.semibold)
        @unknown default:
            .headline.weight(.semibold)
        }
    }
}

extension ScreenScaffold where Footer == EmptyView {
    init(
        title: String? = nil,
        titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large,
        contentTopPadding: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, titleDisplayMode: titleDisplayMode, contentTopPadding: contentTopPadding, content: content) {
            EmptyView()
        }
    }
}

private struct SunnadSolidBarsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(SunnadTheme.background, for: .navigationBar, .tabBar)
            .toolbarBackground(.visible, for: .navigationBar, .tabBar)
    }
}

extension View {
    func sunnadSolidBars() -> some View {
        modifier(SunnadSolidBarsModifier())
    }

    func sunnadGroupedBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(SunnadTheme.background)
    }
}
