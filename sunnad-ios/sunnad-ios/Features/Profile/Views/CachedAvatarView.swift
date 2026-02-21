import SwiftUI
import UIKit

struct CachedAvatarView: View {
    let url: URL?
    let size: CGFloat
    let placeholderPadding: CGFloat

    @State private var imageData: Data?

    var body: some View {
        SwiftUI.Group {
            if let image = resolvedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(SunnadTheme.primary)
                    .padding(placeholderPadding)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: url) {
            await loadImage()
        }
    }

    private var resolvedImage: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }

    private func loadImage() async {
        guard let url else {
            imageData = nil
            return
        }
        imageData = await AvatarImageCache.shared.data(for: url)
    }
}
