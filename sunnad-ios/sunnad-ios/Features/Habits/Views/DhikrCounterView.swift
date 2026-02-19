import SwiftUI

struct DhikrCounterView: View {
    @Binding var count: Int
    @Binding var target: Int

    @State private var selectedDhikrKey = "dhikr.choice.subhanallah"

    private let commonDhikrs = [
        "dhikr.choice.subhanallah",
        "dhikr.choice.alhamdulillah",
        "dhikr.choice.allahu_akbar"
    ]

    var body: some View {
        VStack(spacing: 22) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(commonDhikrs, id: \.self) { key in
                        Button {
                            selectedDhikrKey = key
                        } label: {
                            Text(L10n.t(key))
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(selectedDhikrKey == key ? SunnadTheme.primary : Color(.tertiarySystemFill))
                                )
                                .foregroundStyle(selectedDhikrKey == key ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }

            Button {
                increment()
            } label: {
                ZStack {
                    Circle()
                        .stroke(lineWidth: 12)
                        .foregroundStyle(Color(.tertiarySystemFill))
                        .frame(width: 272, height: 272)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(SunnadTheme.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 272, height: 272)

                    VStack(spacing: 6) {
                        Text("\(count)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                        Text("\(L10n.t("dhikr.of")) \(target)")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("dhikr.tap"))

            Button {
                increment()
            } label: {
                Text(L10n.t("dhikr.tap"))
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .foregroundStyle(.white)
                    .background(
                        Capsule(style: .continuous)
                            .fill(SunnadTheme.primary)
                    )
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button {
                    count = 0
                } label: {
                    Text(L10n.t("dhikr.reset"))
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(.tertiarySystemBackground))
                        )
                }
                .buttonStyle(.plain)
                .frame(width: 110)

                HStack(spacing: 8) {
                    Text(L10n.t("dhikr.target"))
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 8)

                    HStack(spacing: 0) {
                Button {
                    target = max(1, target - 1)
                    count = min(count, target)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 34, height: 34)
                        }
                        Divider()
                        Button {
                            target = min(999, target + 1)
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 34, height: 34)
                        }
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(.tertiarySystemFill))
                    )

                    Text("\(target)")
                        .font(.headline.weight(.semibold))
                        .frame(minWidth: 36)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.tertiarySystemBackground))
                )
            }
        }
        .padding(.vertical, 16)
    }

    private var progress: CGFloat {
        guard target > 0 else { return 0 }
        return min(CGFloat(count) / CGFloat(target), 1)
    }

    private func increment() {
        count = min(count + 1, max(target, 1))
    }
}
