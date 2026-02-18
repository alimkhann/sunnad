import SwiftUI

struct DhikrCounterView: View {
    @Binding var count: Int
    @Binding var target: Int

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(lineWidth: 12)
                    .foregroundStyle(Color(.tertiarySystemFill))
                    .frame(width: 260, height: 260)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 260, height: 260)

                VStack(spacing: 6) {
                    Text("\(count)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                    Text("\(L10n.t("dhikr.of")) \(target)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }.padding(.top, 8)

            PrimaryButton(title: L10n.t("dhikr.tap")) {
                count += 1
            }

            HStack(spacing: 12) {
                SecondaryButton(title: L10n.t("dhikr.reset")) {
                    count = 0
                }

                Stepper(L10n.t("dhikr.target"), value: $target, in: 1...999)
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 20)
    }

    private var progress: CGFloat {
        guard target > 0 else { return 0 }
        return min(CGFloat(count) / CGFloat(target), 1)
    }
}
