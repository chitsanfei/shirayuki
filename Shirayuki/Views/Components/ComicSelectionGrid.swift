import SwiftUI

struct ComicSelectionGrid<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {
    private let items: [Data.Element]
    private let id: KeyPath<Data.Element, ID>
    private let content: (Data.Element) -> Content

    init(
        _ items: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.items = Array(items)
        self.id = id
        self.content = content
    }

    var body: some View {
        LazyVGrid(columns: Self.columns, spacing: 18) {
            ForEach(indexedItems) { item in
                content(item.value)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .lazyGridReveal(index: item.index)
            }
        }
    }

    private var indexedItems: [IndexedGridItem<Data.Element, ID>] {
        items.enumerated().map { offset, element in
            IndexedGridItem(
                index: offset,
                value: element,
                itemID: element[keyPath: id]
            )
        }
    }

    private static var columns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 14, alignment: .top),
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 14, alignment: .top)
        ]
    }
}

private struct IndexedGridItem<Value, ID: Hashable>: Identifiable {
    let index: Int
    let value: Value
    let itemID: ID

    var id: ID { itemID }
}

struct ComicSelectionGridSkeleton: View {
    private let placeholders = Array(0..<4)

    var body: some View {
        ComicSelectionGrid(placeholders, id: \.self) { _ in
            ComicCardSkeleton()
        }
    }
}

private struct ComicCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 228)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 16)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
                .frame(width: 88, height: 12)

            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 48, height: 12)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 56, height: 12)
            }

            Spacer(minLength: 0)
        }
        .redacted(reason: .placeholder)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 320, alignment: .topLeading)
    }
}

private struct LazyGridRevealModifier: ViewModifier {
    let index: Int
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.965, anchor: .top)
            .offset(y: isVisible ? 0 : 18)
            .onAppear {
                guard !isVisible else { return }
                withAnimation(
                    .spring(response: 0.38, dampingFraction: 0.84)
                    .delay(min(Double(index % 8) * 0.035, 0.22))
                ) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func lazyGridReveal(index: Int) -> some View {
        modifier(LazyGridRevealModifier(index: index))
    }
}
