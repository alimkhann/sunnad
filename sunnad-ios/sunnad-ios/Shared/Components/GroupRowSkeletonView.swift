import SwiftUI

struct GroupRowSkeletonView: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.tertiarySystemFill))
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 110, height: 14)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 70, height: 12)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.clear)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct GroupListSkeletonView: View {
    var body: some View {
        Card(contentPadding: 0) {
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    GroupRowSkeletonView()
                }
            }
        }
        .shimmer()
    }
}
