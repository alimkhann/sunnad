import SwiftUI

struct LabeledTextFieldRow: View {
    let label: String
    let placeholder: String
    @Binding var value: String
    var contentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var isSecure = false

    @State private var showsSecureText = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if isSecure {
                HStack {
                    Group {
                        if showsSecureText {
                            TextField(placeholder, text: $value)
                        } else {
                            SecureField(placeholder, text: $value)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .keyboardType(keyboardType)

                    Button {
                        showsSecureText.toggle()
                    } label: {
                        Image(systemName: showsSecureText ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                TextField(placeholder, text: $value)
                    .textInputAutocapitalization(.never)
                    .keyboardType(keyboardType)
            }
        }
    }
}

struct ReminderToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
        }
    }
}

struct WeekdayPickerRow: View {
    @Binding var selectedDays: Set<Int>

    private let dayKeys = ["weekday.mon", "weekday.tue", "weekday.wed", "weekday.thu", "weekday.fri", "weekday.sat", "weekday.sun"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(dayKeys.enumerated()), id: \.offset) { index, key in
                let selected = selectedDays.contains(index)
                Button {
                    if selected {
                        selectedDays.remove(index)
                    } else {
                        selectedDays.insert(index)
                    }
                } label: {
                    Text(L10n.t(key))
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selected ? Color.green : Color(.tertiarySystemFill))
                        )
                        .foregroundStyle(selected ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
