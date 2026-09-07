import AppIntents
import SwiftUI
import WidgetKit

struct GroupsConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("widgets.groups.name")
    static var description = IntentDescription(LocalizedStringResource("widgets.groups.description"))

    @Parameter(title: LocalizedStringResource("widgets.intents.param.group"))
    var group: WidgetGroupEntity?
}

struct GroupsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "adat.groups",
            intent: GroupsConfigurationIntent.self,
            provider: ConfigurableSnapshotProvider(mapConfiguration: { intent in (nil, nil, intent.group) })
        ) { entry in
            GroupsEntryView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringResource("widgets.groups.name"))
        .description(LocalizedStringResource("widgets.groups.description"))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct GroupsEntryView: View {
    let entry: WidgetSnapshotEntry

    @Environment(\.widgetFamily) private var family

    private var groups: [GroupSnapshot] {
        entry.snapshot?.groups ?? []
    }

    /// The group picked in the widget edit sheet; falls back to the first group.
    private var selectedGroup: GroupSnapshot? {
        if let configured = entry.configurationGroup,
           let id = UUID(uuidString: configured.id),
           let match = groups.first(where: { $0.id == id }) {
            return match
        }
        return groups.first
    }

    private var memberLimit: Int {
        family == .systemLarge ? 6 : 4
    }

    var body: some View {
        content
            .widgetURL(URL(string: "adat://groups"))
            .containerBackground(for: .widget) {
                WidgetTheme.background
            }
    }

    @ViewBuilder
    private var content: some View {
        if WidgetSupport.isStale(entry.snapshot, date: entry.date) {
            StaleStateView(deepLink: URL(string: "adat://groups")!)
        } else if groups.isEmpty {
            Text(L10n.t("widgets.today.empty"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if entry.snapshot?.sessionExpired == true {
            signInState
        } else if let group = selectedGroup {
            GroupMemberListSection(
                group: group,
                memberLimit: memberLimit,
                failedNudgeMemberIDs: entry.snapshot?.failedNudgeMemberIDs
            )
            .padding(4)
        }
    }

    private var signInState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(L10n.t("widgets.groups.signin"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "adat://groups"))
    }
}

private struct GroupMemberListSection: View {
    let group: GroupSnapshot
    let memberLimit: Int
    let failedNudgeMemberIDs: [UUID]?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(group.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ForEach(group.members.prefix(memberLimit), id: \.id) { member in
                GroupMemberRowView(
                    group: group,
                    member: member,
                    hasFailedNudge: failedNudgeMemberIDs?.contains(member.id) == true
                )
            }
            Spacer(minLength: 0)
        }
    }
}

private struct GroupMemberRowView: View {
    let group: GroupSnapshot
    let member: MemberSnapshot
    let hasFailedNudge: Bool

    private var targetHabit: HabitMini? {
        member.habits.first { !$0.completed } ?? member.habits.first
    }

    private var isSent: Bool {
        group.sentNudgeMemberIDs.contains(member.id)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(member.name)
                .font(.footnote)
                .lineLimit(1)

            Spacer(minLength: 4)

            HStack(spacing: 3) {
                ForEach(member.habits.prefix(4), id: \.habitID) { habit in
                    Circle()
                        .fill(habit.completed ? WidgetTheme.primary : Color(.systemFill))
                        .frame(width: 6, height: 6)
                }
            }

            Text("\(member.completedCount)/\(member.habits.count)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            if let target = targetHabit, !member.habits.allSatisfy(\.completed) {
                if isSent {
                    Text(L10n.t("widgets.groups.sent"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Button(intent: SendNudgeIntent(
                        groupID: group.id.uuidString,
                        memberID: member.id.uuidString,
                        habitID: target.habitID.uuidString
                    )) {
                        Image(systemName: "bell")
                            .font(.footnote)
                            .foregroundStyle(hasFailedNudge ? Color.red : WidgetTheme.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("widgets.groups.remind"))
                }
            }
        }
        .padding(.vertical, 1)
    }
}
