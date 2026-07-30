import SwiftUI

/// Standard comic card used by discovery grids.
struct ComicCard: View {
    let comic: ComicSummary
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

/// Ranking card with configurable category or tag metadata.
struct RankComicCard: View {
    let comic: ComicSummary
    let metadataDisplay: RankMetadataDisplay
    let maxTagCount: Int
    @ObservedObject private var localization = AppLocalization.shared

    private enum Layout {
        static let coverHeight: CGFloat = 210
        static let titleHeight: CGFloat = 40
        static let cardHeight: CGFloat = 340
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

            metadataRow

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

    private var metadataRow: some View {
        HStack(spacing: 4) {
            let values = metadataDisplay == .tags ? comic.tags : comic.categories
            ForEach(Array(values.prefix(maxTagCount).enumerated()), id: \.offset) { _, value in
                Text(value)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.10))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.accentColor.opacity(0.20), lineWidth: 0.5)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Search-result card with query-relevant comic metadata.
struct SearchComicCard: View {
    let comic: ComicSummary
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
