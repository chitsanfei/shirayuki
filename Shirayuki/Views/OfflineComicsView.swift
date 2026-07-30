import SwiftUI

/// Lists downloaded comics and manages offline reading and deletion.
struct OfflineComicsView: View {
    @ObservedObject private var localization = AppLocalization.shared
    @State private var records: [OfflineComicRecord] = []
    @State private var recordToRead: OfflineComicRecord?
    @State private var recordToDownload: OfflineComicRecord?
    @State private var progress: [String: OfflineDownloadProgress] = [:]

    var body: some View {
        Group {
            if records.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text(localization.text("offline.empty"))
                        .font(.system(size: 18, weight: .semibold))
                    Text(localization.text("offline.empty.subtitle"))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else {
                List {
                    ForEach(records) { record in
                        offlineRow(record)
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #else
                .listStyle(.inset)
                #endif
            }
        }
        .navigationTitle(localization.text("offline.title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task { await reload() }
        #if os(iOS)
        .fullScreenCover(item: $recordToRead) { record in
            OfflineReaderView(record: record)
        }
        #else
        .sheet(item: $recordToRead) { record in
            OfflineReaderView(record: record)
        }
        #endif
        .sheet(item: $recordToDownload) { record in
            OfflineDownloadSheet(record: record) { quality in
                startDownload(record: record, quality: quality)
            }
        }
    }

    private func offlineRow(_ record: OfflineComicRecord) -> some View {
        Button {
            recordToRead = record
        } label: {
            HStack(spacing: 14) {
                ComicCoverImage(url: record.thumbURL)
                    .frame(width: 68, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(Color.accentColor, in: Circle())
                            .padding(5)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text(record.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(localization.text("offline.detail", record.chapters.count, record.imageCount))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(localization.text("offline.quality", record.quality.displayName))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.11), in: Capsule())
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .overlay(alignment: .bottomLeading) {
                if let currentProgress = progress[record.id], currentProgress.totalImages > 0 {
                    ProgressView(
                        value: Double(currentProgress.completedImages),
                        total: Double(currentProgress.totalImages)
                    )
                    .tint(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 5)
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomLeading) {
            if let currentProgress = progress[record.id] {
                Text(currentProgress.totalImages > 0
                     ? localization.text("offline.downloading", currentProgress.completedImages, currentProgress.totalImages)
                     : localization.text("detail.download.preparing"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 96)
                    .padding(.bottom, 12)
            }
        }
        .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                delete(record)
            } label: {
                Label(localization.text("offline.delete"), systemImage: "trash")
            }

            Button {
                recordToDownload = record
            } label: {
                Label(
                    record.quality == .original
                    ? localization.text("offline.redownload")
                    : localization.text("offline.upgrade"),
                    systemImage: "arrow.up.circle"
                )
            }
            .tint(.orange)
        }
    }

    private func reload() async {
        records = await OfflineComicStore.shared.allComics()
    }

    private func startDownload(record: OfflineComicRecord, quality: AppImageQuality) {
        let chapters = record.chapters.map {
            PicaChapter(uid: $0.id, title: $0.title, order: $0.order, id: $0.id)
        }
        progress[record.id] = OfflineDownloadProgress(completedImages: 0, totalImages: 0)
        Task {
            try? await OfflineComicStore.shared.download(
                comicID: record.id,
                title: record.title,
                thumbURL: record.thumbURL,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                chapters: chapters,
                quality: quality,
                allChapters: record.chapterCatalog,
                progress: { value in
                    Task { @MainActor in
                        progress[record.id] = value
                    }
                }
            )
            progress[record.id] = nil
            await reload()
        }
    }

    private func delete(_ record: OfflineComicRecord) {
        Task {
            try? await OfflineComicStore.shared.delete(comicID: record.id)
            await reload()
        }
    }
}

private struct OfflineReaderView: View {
    @StateObject private var viewModel: ReaderViewModel

    init(record: OfflineComicRecord) {
        let chapters = record.chapterCatalog
        _viewModel = StateObject(
            wrappedValue: ReaderViewModel(
                comic: ComicDetail(offlineRecord: record),
                initialChapters: chapters,
                initialChapterId: record.chapters.first?.id,
                offlineOnly: true
            )
        )
    }

    var body: some View {
        ReaderView(viewModel: viewModel)
    }
}

private struct OfflineDownloadSheet: View {
    let record: OfflineComicRecord
    let onConfirm: (AppImageQuality) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localization = AppLocalization.shared
    @State private var quality: AppImageQuality

    init(record: OfflineComicRecord, onConfirm: @escaping (AppImageQuality) -> Void) {
        self.record = record
        self.onConfirm = onConfirm
        _quality = State(initialValue: record.quality)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(localization.text("detail.download.quality"))
                        .font(.title3.weight(.bold))

                    ForEach(AppImageQuality.allCases) { item in
                        Button {
                            quality = item
                        } label: {
                            HStack(spacing: 12) {
                                Text(item.displayName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: quality == item ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(quality == item ? Color.accentColor : Color.secondary)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(quality == item ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(quality == item ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Menu {
                        Button(localization.text("offline.confirm")) {
                            onConfirm(quality)
                            dismiss()
                        }
                        Button(localization.text("common.cancel"), role: .cancel) {}
                    } label: {
                        HStack {
                            Text(localization.text("offline.confirm"))
                                .font(.system(size: 16, weight: .bold))
                            Spacer()
                            Image(systemName: "chevron.up")
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 18)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(20)
            }
            .navigationTitle(localization.text("offline.upgrade"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.text("common.cancel")) { dismiss() }
                }
            }
        }
    }
}
