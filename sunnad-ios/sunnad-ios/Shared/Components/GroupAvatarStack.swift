import SwiftUI

struct GroupAvatarStack: View {
    let members: [UIGroupMember]
    var avatarSize: CGFloat = 28
    var overlap: CGFloat = 10
    var maximumVisibleMembers = 3

    private var visibleMembers: [UIGroupMember] {
        Array(members.prefix(maximumVisibleMembers))
    }

    private var width: CGFloat {
        guard !visibleMembers.isEmpty else { return avatarSize }
        return avatarSize + CGFloat(visibleMembers.count - 1) * (avatarSize - overlap)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if visibleMembers.isEmpty {
                Image(systemName: "person.2.fill")
                    .font(.system(size: avatarSize * 0.45, weight: .semibold))
                    .foregroundStyle(SunnadTheme.primary)
                    .frame(width: avatarSize, height: avatarSize)
                    .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
            } else {
                ForEach(Array(visibleMembers.enumerated()), id: \.element.id) { index, member in
                    memberAvatar(member)
                        .offset(x: CGFloat(index) * (avatarSize - overlap))
                        .zIndex(Double(visibleMembers.count - index))
                }
            }
        }
        .frame(width: width, height: avatarSize, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: L10n.t("groups.members_count"), members.count))
    }

    @ViewBuilder
    private func memberAvatar(_ member: UIGroupMember) -> some View {
        if let avatarURL = member.avatarURL {
            CachedAvatarView(url: avatarURL, size: avatarSize, placeholderPadding: 3)
                .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
                .overlay(avatarBorder)
        } else {
            Text(initials(for: member.name))
                .font(.system(size: avatarSize * 0.36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: avatarSize, height: avatarSize)
                .background(Circle().fill(placeholderColor(for: member.id)))
                .overlay(avatarBorder)
        }
    }

    private var avatarBorder: some View {
        Circle()
            .stroke(Color(.systemBackground), lineWidth: 2)
    }

    private func initials(for name: String) -> String {
        let parts = name
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
        let value = parts.compactMap(\.first).map(String.init).joined()
        return value.isEmpty ? "?" : value.uppercased()
    }

    private func placeholderColor(for id: UUID) -> Color {
        let palette: [Color] = [
            SunnadTheme.primary,
            .indigo,
            .teal,
            .orange,
            .purple
        ]
        let checksum = id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[checksum % palette.count]
    }
}
