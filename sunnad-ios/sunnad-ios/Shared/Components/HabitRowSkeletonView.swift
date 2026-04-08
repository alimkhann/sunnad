import SwiftUI

struct HabitRowSkeletonView: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.tertiarySystemFill))
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 120, height: 14)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 72, height: 10)
            }

            Spacer(minLength: 8)

            Circle()
                .fill(Color(.tertiarySystemFill))
                .frame(width: 24, height: 24)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
    }
}

struct HabitListSkeletonView: View {
    var body: some View {
        Card(contentPadding: 0) {
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    HabitRowSkeletonView()
                }
            }
            .padding(.vertical, 8)
        }
        .shimmer()
    }
}
