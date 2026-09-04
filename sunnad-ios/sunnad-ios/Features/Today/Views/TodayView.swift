import SwiftUI

struct TodayView: View {
    @AppStorage("adat.coachmark.firstCompletion.dismissed") private var didDismissFirstCompletionCoachMark = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsCompleted = false
    @State private var showsLateCheckIn = false
    @State private var selectedLateCheckInHabit: UIHabit?
    @State private var pendingCelebrationHabitID: UUID?
    @State private var celebrationToken = 0
    @State private var pendingCelebrationResetTask: Task<Void, Never>?
    @State private var celebrationHideTask: Task<Void, Never>?

    let habits: [UIHabit]
    let lateCheckInCandidates: [UIHabit]
    let quote: UIQuote
    let isLoading: Bool
    let onToggle: (UUID) -> Void
    let onSelectHabit: (UIHabit) -> Void
    let onManage: () -> Void
    let onAddHabit: () -> Void
    let onLateCheckIn: (UUID) -> Void
    let onOpenQuote: () -> Void

    private var completedCount: Int {
        habits.filter(\.completedToday).count
    }

    private var incompleteHabits: [UIHabit] {
        habits.filter { !$0.completedToday }
    }

    private var completedHabits: [UIHabit] {
        habits.filter(\.completedToday)
    }

    var body: some View {
        ScreenScaffold(contentTopPadding: 8) {
            QuoteCardView(quote: quote, onTap: onOpenQuote)

            if !lateCheckInCandidates.isEmpty {
                Button {
                    showsLateCheckIn = true
                } label: {
                    Label(L10n.t("late_check_in.prompt"), systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityHint(L10n.t("late_check_in.prompt.hint"))
            }

            if isLoading && habits.isEmpty {
                HabitListSkeletonView()
            } else if habits.isEmpty {
                Card {
                    EmptyStateView(
                        symbol: "calendar.badge.exclamationmark",
                        title: L10n.t("today.empty.title"),
                        message: L10n.t("today.empty.subtitle"),
                        primaryTitle: L10n.t("today.add_habit"),
                        primaryAction: onAddHabit,
                        secondaryTitle: L10n.t("today.manage"),
                        secondaryAction: onManage
                    )
                }
            } else {
                Text(String(format: L10n.t("today.progress"), completedCount, habits.count))
                    .font(.body)
                    .foregroundStyle(.secondary)

                if !didDismissFirstCompletionCoachMark, !incompleteHabits.isEmpty {
                    Card {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "hand.tap.fill")
                                .foregroundStyle(SunnadTheme.primary)
                                .frame(width: 28, height: 44)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.t("today.coach.first_completion.title"))
                                    .font(.headline)
                                Text(L10n.t("today.coach.first_completion.message"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 4)

                            Button {
                                didDismissFirstCompletionCoachMark = true
                            } label: {
                                Image(systemName: "xmark")
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel(L10n.t("common.close"))
                        }
                    }
                    .accessibilityIdentifier("today.first_completion.coach_mark")
                }

                if incompleteHabits.isEmpty {
                    Card {
                        EmptyStateView(
                            symbol: "calendar",
                            title: L10n.t("today.all_done.title"),
                            message: L10n.t("today.all_done.subtitle"),
                            primaryTitle: L10n.t("today.all_done.open_schedule"),
                            primaryAction: onManage
                        )
                    }
                } else {
                    Card(contentPadding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(incompleteHabits.enumerated()), id: \.element.id) { index, habit in
                                HabitRowView(
                                    habit: habit,
                                    onTap: { onSelectHabit(habit) },
                                    onToggle: { completeHabitToggle(habit.id) }
                                )
                                .padding(.horizontal, 16)

                                if index < incompleteHabits.count - 1 {
                                    Divider().padding(.leading, 62)
                                }
                            }
                        }
                    }
                }

                if !completedHabits.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showsCompleted.toggle()
                        }
                    } label: {
                        HStack {
                            Text(L10n.t("today.completed.section"))
                                .font(.caption.weight(.semibold))
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: showsCompleted ? "chevron.down" : "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if showsCompleted {
                        Card(contentPadding: 0) {
                            VStack(spacing: 0) {
                                ForEach(Array(completedHabits.enumerated()), id: \.element.id) { index, habit in
                                    HabitRowView(
                                        habit: habit,
                                        isDimmed: true,
                                        onTap: { onSelectHabit(habit) },
                                        onToggle: { completeHabitToggle(habit.id) }
                                    )
                                    .padding(.horizontal, 16)

                                    if index < completedHabits.count - 1 {
                                        Divider().padding(.leading, 62)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.t("tab.today"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: onManage) {
                    Image(systemName: "calendar")
                }
                .accessibilityLabel(L10n.t("today.manage"))
                .accessibilityIdentifier("today.manage.button")

                Button(action: onAddHabit) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(L10n.t("today.add_habit"))
                .accessibilityIdentifier("today.add.button")
            }
        }
        .sunnadSolidBars()
        .overlay(alignment: .top) {
            if celebrationToken > 0 {
                CompletionConfettiView(token: celebrationToken)
                    .padding(.top, 68)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: completedCount) { oldCount, newCount in
            guard pendingCelebrationHabitID != nil else { return }
            pendingCelebrationHabitID = nil
            pendingCelebrationResetTask?.cancel()

            guard !reduceMotion,
                  !habits.isEmpty,
                  newCount > oldCount,
                  newCount == habits.count else {
                return
            }

            celebrationToken += 1
            let activeToken = celebrationToken
            celebrationHideTask?.cancel()
            celebrationHideTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, celebrationToken == activeToken else { return }
                celebrationToken = 0
            }
        }
        .onDisappear {
            pendingCelebrationResetTask?.cancel()
            celebrationHideTask?.cancel()
        }
        .sheet(isPresented: $showsLateCheckIn) {
            NavigationStack {
                List(lateCheckInCandidates) { habit in
                    Button {
                        selectedLateCheckInHabit = habit
                    } label: {
                        Label(habit.displayTitle, systemImage: habit.iconSystemName)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
                .navigationTitle(L10n.t("late_check_in.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.t("common.done")) { showsLateCheckIn = false }
                    }
                }
                .confirmationDialog(
                    L10n.t("late_check_in.confirm.title"),
                    isPresented: Binding(
                        get: { selectedLateCheckInHabit != nil },
                        set: { if !$0 { selectedLateCheckInHabit = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    if let selectedLateCheckInHabit {
                        Button(L10n.t("late_check_in.confirm.action")) {
                            onLateCheckIn(selectedLateCheckInHabit.id)
                            self.selectedLateCheckInHabit = nil
                        }
                    }
                    Button(L10n.t("common.cancel"), role: .cancel) {
                        selectedLateCheckInHabit = nil
                    }
                } message: {
                    Text(L10n.t("late_check_in.confirm.message"))
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func completeHabitToggle(_ habitID: UUID) {
        didDismissFirstCompletionCoachMark = true
        if habits.first(where: { $0.id == habitID })?.completedToday == false {
            pendingCelebrationHabitID = habitID
            pendingCelebrationResetTask?.cancel()
            pendingCelebrationResetTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                pendingCelebrationHabitID = nil
            }
        } else {
            pendingCelebrationHabitID = nil
        }
        onToggle(habitID)
    }

}

private struct CompletionConfettiView: View {
    let token: Int

    @State private var isFalling = false

    private let colors: [Color] = [
        SunnadTheme.primary,
        .yellow,
        .mint,
        .orange
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<14, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(colors[index % colors.count])
                        .frame(width: index.isMultiple(of: 3) ? 5 : 7, height: 10)
                        .rotationEffect(.degrees(isFalling ? Double((index * 83) % 300) : 0))
                        .position(
                            x: proxy.size.width * (0.22 + Double((index * 37) % 57) / 100),
                            y: isFalling ? 126 + CGFloat((index * 19) % 54) : 36
                        )
                        .opacity(isFalling ? 0 : 0.95)
                        .animation(
                            .easeOut(duration: 0.75)
                                .delay(Double(index % 5) * 0.025),
                            value: isFalling
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 190)
        .id(token)
        .onAppear {
            isFalling = true
        }
    }
}
