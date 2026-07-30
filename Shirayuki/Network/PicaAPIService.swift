import Foundation

/// Provides typed PicACG operations above the signed HTTP client.
actor PicaAPIService {
    static let shared = PicaAPIService()
    private let paginatedRequestBatchSize = 2
    
    private init() {}
    
    // MARK: - Auth
    /// Authenticates an account and installs the returned token.
    func login(username: String, password: String) async throws -> String {
        let payload = LoginPayload(email: username, password: password)
        let response: BaseResponse<LoginResponse> = try await APIClient.shared.request(
            .post,
            path: "auth/sign-in",
            body: payload
        )
        await APIClient.shared.setToken(response.data.token)
        return response.data.token
    }
    
    /// Creates a new PicACG account.
    func register(email: String, password: String, name: String, birthday: String, gender: String) async throws {
        let body = RegisterPayload(
            email: email,
            password: password,
            name: name,
            birthday: birthday,
            gender: gender
        )
        let _: BaseResponse<EmptyResponse> = try await APIClient.shared.request(.post, path: "auth/register", body: body)
    }
    
    /// Performs the account's daily check-in action.
    func punchIn() async throws {
        let _: BaseResponse<EmptyResponse> = try await APIClient.shared.request(.post, path: "users/punch-in")
    }
    
    // MARK: - Categories
    /// Returns app-compatible categories, excluding web-only entries.
    func fetchCategories() async throws -> [PicaCategory] {
        let response: BaseResponse<CategoriesResponse> = try await APIClient.shared.request(.get, path: "categories")
        return response.data.categories.filter { !($0.isWeb == true) }
    }
    
    // MARK: - Comics
    /// Fetches one page of comics matching the supplied query fields.
    func fetchComics(payload: ComicsPayload) async throws -> ComicsList {
        let response: BaseResponse<ComicsResponse> = try await APIClient.shared.request(
            .get,
            path: "comics",
            query: payload.query
        )
        return response.data.comics
    }
    
    /// Fetches complete metadata for one comic.
    func fetchComicDetail(id: String) async throws -> ComicDetail {
        let response: BaseResponse<ComicDetailsResponse> = try await APIClient.shared.request(.get, path: "comics/\(id)")
        return response.data.comic
    }
    
    /// Fetches and combines every chapter page for a comic.
    func fetchChapters(id: String) async throws -> [PicaChapter] {
        let url = "comics/\(id)/eps"
        let firstResponse: BaseResponse<ChaptersResponse> = try await APIClient.shared.request(
            .get,
            path: url,
            query: ["page": "1"]
        )
        var chapters = firstResponse.data.eps.docs
        let totalPages = firstResponse.data.eps.pages
        
        if totalPages > 1 {
            let responses: [BaseResponse<ChaptersResponse>] = try await fetchAdditionalPages(totalPages: totalPages) { page in
                try await APIClient.shared.request(.get, path: url, query: ["page": String(page)])
            }
            for result in responses {
                chapters.append(contentsOf: result.data.eps.docs)
            }
        }
        return chapters
    }
    
    /// Fetches and combines every image page for a chapter order.
    func fetchChapterImages(id: String, order: Int) async throws -> ([ChapterImage], String) {
        let url = "comics/\(id)/order/\(order)/pages"
        let firstResponse: BaseResponse<FetchChapterImagesResponse> = try await APIClient.shared.request(
            .get,
            path: url,
            query: ["page": "1"]
        )
        var images = firstResponse.data.pages.docs
        let totalPages = firstResponse.data.pages.pages
        let title = firstResponse.data.ep.title
        
        if totalPages > 1 {
            let responses: [BaseResponse<FetchChapterImagesResponse>] = try await fetchAdditionalPages(totalPages: totalPages) { page in
                try await APIClient.shared.request(.get, path: url, query: ["page": String(page)])
            }
            for result in responses {
                images.append(contentsOf: result.data.pages.docs)
            }
        }
        return (images, title)
    }
    
    /// Fetches comics recommended for a detail page.
    func fetchRecommendations(id: String) async throws -> [ComicSummary] {
        let response: BaseResponse<RecommendComics> = try await APIClient.shared.request(
            .get,
            path: "comics/\(id)/recommendation"
        )
        return response.data.comics
    }
    
    /// Toggles the authenticated user's like state for a comic.
    func likeComic(id: String) async throws -> ActionResponse {
        let response: BaseResponse<ActionResponse> = try await APIClient.shared.request(.post, path: "comics/\(id)/like")
        return response.data
    }
    
    /// Toggles the authenticated user's favorite state for a comic.
    func favoriteComic(id: String) async throws -> ActionResponse {
        let response: BaseResponse<ActionResponse> = try await APIClient.shared.request(.post, path: "comics/\(id)/favourite")
        return response.data
    }
    
    // MARK: - Search
    /// Searches comics and sends pagination through the URL query.
    func searchComics(keyword: String, page: Int = 1, sort: ComicSortType = .dd) async throws -> ComicsList {
        let payload = SearchPayload(keyword: keyword, sort: sort)
        let response: BaseResponse<SearchResponse> = try await APIClient.shared.request(
            .post,
            path: "comics/advanced-search?page=\(page)",
            body: payload
        )
        return response.data.comics
    }
    
    /// Fetches trending keywords used by search suggestions.
    func fetchHotSearchWords() async throws -> [String] {
        let response: BaseResponse<HotSearchWordsResponse> = try await APIClient.shared.request(.get, path: "keywords")
        return response.data.keywords
    }
    
    // MARK: - User
    /// Fetches the authenticated user's profile.
    func fetchUserProfile() async throws -> UserProfileResponse {
        let response: BaseResponse<UserProfileResponse> = try await APIClient.shared.request(.get, path: "users/profile")
        return response.data
    }
    
    /// Fetches one page of the authenticated user's favorite comics.
    func fetchFavoriteComics(page: Int = 1, sort: ComicSortType = .dd) async throws -> ComicsList {
        let response: BaseResponse<ComicsResponse> = try await APIClient.shared.request(
            .get,
            path: "users/favourite",
            query: ["page": String(page), "s": sort.rawValue]
        )
        return response.data.comics
    }
    
    /// Replaces the authenticated user's password.
    func updatePassword(oldPassword: String, newPassword: String) async throws {
        let _: BaseResponse<EmptyResponse> = try await APIClient.shared.request(
            .put,
            path: "users/password",
            body: PasswordUpdatePayload(oldPassword: oldPassword, newPassword: newPassword)
        )
    }
    
    /// Replaces the authenticated user's avatar.
    func updateAvatar(base64: String) async throws {
        let _: BaseResponse<EmptyResponse> = try await APIClient.shared.request(
            .put,
            path: "users/avatar",
            body: AvatarUpdatePayload(avatar: "data:image/jpeg;base64,\(base64)")
        )
    }
    
    /// Replaces editable profile text.
    func updateProfile(slogan: String) async throws {
        let _: BaseResponse<EmptyResponse> = try await APIClient.shared.request(
            .put,
            path: "users/profile",
            body: ProfileUpdatePayload(slogan: slogan)
        )
    }
    
    // MARK: - Rank
    /// Fetches comics ranked within a selected time window.
    func fetchComicRank(type: ComicRankType) async throws -> ComicsList {
        let response: BaseResponse<ComicRankResponse> = try await APIClient.shared.request(
            .get,
            path: "comics/leaderboard",
            query: ["tt": type.rawValue, "ct": "VC"]
        )
        let comics = response.data.comics
        return ComicsList(
            docs: comics,
            limit: comics.count,
            page: 1,
            pages: 1,
            total: comics.count
        )
    }
    
    // MARK: - Random
    /// Fetches a random discovery collection.
    func fetchRandomComics() async throws -> ComicsList {
        let response: BaseResponse<RandomComicsResponse> = try await APIClient.shared.request(.get, path: "comics/random")
        return response.data.comics
    }
    
    // MARK: - Notifications
    /// Fetches one page of account notifications.
    func fetchNotifications(page: Int = 1) async throws -> NotificationsList {
        let response: BaseResponse<NotificationsResponse> = try await APIClient.shared.request(
            .get,
            path: "users/notifications",
            query: ["page": String(page)]
        )
        return response.data.notifications
    }

    private func fetchAdditionalPages<Response: Sendable>(
        totalPages: Int,
        request: @escaping @Sendable (Int) async throws -> Response
    ) async throws -> [Response] {
        guard totalPages > 1 else { return [] }

        var responsesByPage: [Int: Response] = [:]
        var nextPage = 2

        while nextPage <= totalPages {
            let upperBound = min(totalPages, nextPage + paginatedRequestBatchSize - 1)
            let batchPages = Array(nextPage...upperBound)

            try await withThrowingTaskGroup(of: (Int, Response).self) { group in
                for page in batchPages {
                    group.addTask {
                        (page, try await request(page))
                    }
                }

                for try await (page, response) in group {
                    responsesByPage[page] = response
                }
            }

            nextPage = upperBound + 1
        }

        return (2...totalPages).compactMap { responsesByPage[$0] }
    }
}

// MARK: - Helpers
/// Empty data marker used by successful mutation responses.
nonisolated struct EmptyResponse: Decodable, Sendable {}
