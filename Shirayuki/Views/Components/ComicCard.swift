import SwiftUI

struct ComicCard: View {
    let comic: ComicDoc
    @ObservedObject private var localization = AppLocalization.shared

    private enum Layout {
        static let coverHeight: CGFloat = 228
        static let titleHeight: CGFloat = 40
        static let cardHeight: CGFloat = 320
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ComicCoverImage(url: comic.thumb.url)
                .frame(maxWidth: .infinity)
                .frame(height: Layout.coverHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if comic.finished {
                        Text(localization.text("comic.status.finished"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.85))
                            .clipShape(Capsule())
                            .padding(6)
                    }
                }
            
            Text(comic.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(height: Layout.titleHeight, alignment: .topLeading)
            
            Text(comic.author)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            HStack(spacing: 8) {
                Label("\(comic.likesCount)", systemImage: "heart.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.pink)
                Label("\(comic.totalViews)", systemImage: "eye.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.blue)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Layout.cardHeight, alignment: .topLeading)
    }
}

struct SearchComicCard: View {
    let comic: SearchComic
    @ObservedObject private var localization = AppLocalization.shared

    private enum Layout {
        static let coverHeight: CGFloat = 228
        static let titleHeight: CGFloat = 40
        static let cardHeight: CGFloat = 304
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ComicCoverImage(url: comic.thumb.url)
                .frame(maxWidth: .infinity)
                .frame(height: Layout.coverHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if comic.finished {
                        Text(localization.text("comic.status.finished"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.85))
                            .clipShape(Capsule())
                            .padding(6)
                    }
                }
            
            Text(comic.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(height: Layout.titleHeight, alignment: .topLeading)
            
            Text(comic.author)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            HStack(spacing: 8) {
                Label("\(comic.likesCount)", systemImage: "heart.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.pink)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Layout.cardHeight, alignment: .topLeading)
    }
}
