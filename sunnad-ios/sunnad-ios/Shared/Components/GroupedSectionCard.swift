import SwiftUI

struct GroupedSectionCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                SectionHeader(title: title)
                    .padding(.horizontal, 4)
            }

            Card(contentPadding: 12) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
