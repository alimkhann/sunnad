import SwiftUI

struct DhikrCounterView: View {
    private enum FocusedField: Hashable {
        case count
        case target
    }

    @Binding var count: Int
    @Binding var target: Int
    @Binding var phraseKey: String?
    @Binding var customPhrase: String?
    let onIncremented: (Bool) -> Void

    @State private var countDraft = ""
    @State private var targetDraft = ""
    @FocusState private var focusedField: FocusedField?

    private let builtInPhraseKeys = [
        "dhikr.choice.subhanallah",
        "dhikr.choice.alhamdulillah",
        "dhikr.choice.allahu_akbar"
    ]
    private let targetPresets = [33, 99, 100, 1_000]
    private let customSelection = "custom"

    var body: some View {
        VStack(spacing: 22) {
            phraseEditor
            counter
            counterActions
            targetEditor
        }
        .padding(.vertical, 16)
        .onAppear {
            normalizePhrase()
            countDraft = String(max(count, 0))
            targetDraft = String(normalizedTarget)
        }
        .onChange(of: target) { _, newValue in
            targetDraft = String(min(max(newValue, 1), 999_999))
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.t("common.done")) {
                    commitFocusedDraft()
                    focusedField = nil
                }
            }
        }
    }

    private var phraseEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.t("dhikr.phrase"))
                    .font(.headline.weight(.semibold))
                Spacer()
                Picker(L10n.t("dhikr.phrase"), selection: phraseSelection) {
                    ForEach(builtInPhraseKeys, id: \.self) { key in
                        Text(L10n.t(key)).tag(key)
                    }
                    Text(L10n.t("dhikr.custom_phrase")).tag(customSelection)
                }
                .labelsHidden()
                .accessibilityIdentifier("dhikr.phrase.picker")
            }

            if phraseSelection.wrappedValue == customSelection {
                TextField(
                    L10n.t("dhikr.custom_phrase.placeholder"),
                    text: Binding(
                        get: { customPhrase ?? "" },
                        set: { customPhrase = String($0.prefix(80)) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.sentences)
                .accessibilityLabel(L10n.t("dhikr.custom_phrase"))
                .accessibilityIdentifier("dhikr.custom_phrase.field")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
        )
    }

    private var counter: some View {
        ZStack {
            Button(action: increment) {
                ZStack {
                    Circle()
                        .stroke(lineWidth: 12)
                        .foregroundStyle(Color(.tertiarySystemFill))

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            SunnadTheme.primary,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("dhikr.tap"))
            .accessibilityValue("\(count) / \(normalizedTarget)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: increment()
                case .decrement:
                    count = max(count - 1, 0)
                    countDraft = String(count)
                @unknown default: break
                }
            }

            VStack(spacing: 6) {
                if focusedField == .count {
                    TextField("0", text: $countDraft)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .count)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .frame(maxWidth: 180)
                        .onSubmit(commitCountDraft)
                } else {
                    Button {
                        countDraft = String(max(count, 0))
                        focusedField = .count
                    } label: {
                        Text("\(count)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("dhikr.edit_count"))
                    .accessibilityIdentifier("dhikr.count.edit.button")
                }

                Text("\(L10n.t("dhikr.of")) \(normalizedTarget)")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 272, maxHeight: 272)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    private var counterActions: some View {
        HStack(spacing: 10) {
            Button {
                count = 0
                countDraft = "0"
            } label: {
                Label(L10n.t("dhikr.reset"), systemImage: "arrow.counterclockwise")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)

            Button(action: increment) {
                Text(L10n.t("dhikr.tap"))
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(SunnadTheme.primary)
        }
    }

    private var targetEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(L10n.t("dhikr.target"))
                    .font(.headline.weight(.semibold))
                Spacer()
                TextField("33", text: $targetDraft)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .target)
                    .multilineTextAlignment(.trailing)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .frame(minWidth: 88, maxWidth: 140)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(commitTargetDraft)
                    .accessibilityLabel(L10n.t("dhikr.target"))
                    .accessibilityIdentifier("dhikr.target.field")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(targetPresets, id: \.self) { preset in
                        Button(preset.formatted()) {
                            target = preset
                            targetDraft = String(preset)
                        }
                        .buttonStyle(.bordered)
                        .tint(target == preset ? SunnadTheme.primary : .secondary)
                        .accessibilityIdentifier("dhikr.target.preset.\(preset)")
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
        )
    }

    private var phraseSelection: Binding<String> {
        Binding(
            get: { customPhrase != nil ? customSelection : phraseKey ?? builtInPhraseKeys[0] },
            set: { selection in
                if selection == customSelection {
                    phraseKey = nil
                    customPhrase = customPhrase?.isEmpty == false ? customPhrase : ""
                } else {
                    phraseKey = selection
                    customPhrase = nil
                }
            }
        )
    }

    private var normalizedTarget: Int {
        min(max(target, 1), 999_999)
    }

    private var progress: CGFloat {
        min(CGFloat(max(count, 0)) / CGFloat(normalizedTarget), 1)
    }

    private func increment() {
        let previous = count
        count = min(max(count, 0) + 1, 9_999_999)
        countDraft = String(count)
        onIncremented(previous < normalizedTarget && count >= normalizedTarget)
    }

    private func normalizePhrase() {
        let trimmedCustom = customPhrase?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedCustom, !trimmedCustom.isEmpty {
            customPhrase = String(trimmedCustom.prefix(80))
            phraseKey = nil
        } else {
            customPhrase = nil
            if !builtInPhraseKeys.contains(phraseKey ?? "") {
                phraseKey = builtInPhraseKeys[0]
            }
        }
        target = normalizedTarget
        count = max(count, 0)
    }

    private func commitFocusedDraft() {
        switch focusedField {
        case .count: commitCountDraft()
        case .target: commitTargetDraft()
        case nil: break
        }
    }

    private func commitCountDraft() {
        count = min(max(Int(countDraft) ?? count, 0), 9_999_999)
        countDraft = String(count)
    }

    private func commitTargetDraft() {
        target = min(max(Int(targetDraft) ?? target, 1), 999_999)
        targetDraft = String(target)
    }
}
