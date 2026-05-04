import Foundation

actor PicaAPIService {
    static let shared = PicaAPIService()
    private let paginatedRequestBatchSize = 2
    
    private init() {}
    
    // MARK: - Auth
    func login(username: String, password: String) async throws -> String {
        let payload = LoginPayload(email: username, password: password)
        let response: BaseResponse<LoginResponse> = try await APIClient.shared.request(
            .post,
            path: "auth/sign-in",
            body: try payload.toDictionary()
        )
        await APIClient.shared.setToken(response.data.token)
        return response.data.token
    }
    
    func register(email: String, password: String, name: String, birthday: String, gender: String) async throws {
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "name": name,
            "birthday": birthday,
            "gender": gender
        ]
        let _: BaseResponse<EmptyResponse> = try await APIClient.shared.request(.post, path: "auth/register", body: body)
    }
    
    func punchIn() async throws {
        let _: BaseResponse<EmptyResponse> = try await APIClient.shared.request(.post, path: "users/punch-in")
    }
    
    // MARK: - Categories
    func fetchCategories() async throws -> [PicaCategory] {
        let response: BaseResponse<CategoriesResponse> = try await APIClient.shared.request(.get, path: "categories")
        return response.data.categories.filter { !($0.isWeb == true) }
    }
    
    // MARK: - Comics
    func fetchComics(payload: ComicsPayload) async throws -> ComicsList {
        let response: BaseResponse<ComicsResponse> = try await APIClient.shared.request(
            .get,
            path: "comics",
            query: payload.query
        )
        return response.data.comics
    }
    
    func fetchComicDetail(id: String) async throws -> ComicDetail {
        let response: BaseResponse<ComicDetailsResponse> = try await APIClient.shared.request(.get, path: "comics/\(id)")
        return response.data.comic
    }
    
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
    
    func fetchRecommendations(id: String) async throws -> [RecommendComic] {
        let response: BaseResponse<RecommendComics> = try await APIClient.shared.request(
            .get,
            path: "comics/\(id)/recommendation"
        )
        return response.data.comics
    }
    
    func likeComic(id: String) async throws -> ActionResponse {
        let response: BaseResponse<ActionResponse> = try await APIClient.shared.request(.post, path: "comics/\(id)/like")
        return response.data
    }
    
    func favoriteComic(id: String) async throws -> ActionResponse {
        let response: BaseResponse<ActionResponse> = try await APIClient.shared.request(.post, path: "comics/\(id)/favourite")
        return response.data
    }
    
    // MARK: - Search
    func searchComics(keyword: String, page: Int = 1, sort: ComicSortType = .dd) async throws -> SearchComicsList {
        let payload = SearchPayload(keyword: keyword, page: page, sort: sort)
        let response: BaseResponse<SearchResponse> = try await APIClient.shared.request(
            .post,
            path: "comics/advanced-search?page=\(page)",
            body: try payload.toDictionary()
        )
        return response.data.comics
    }
    
    func fetchHotSearchWords() async throws -> [String] {
        let response: BaseResponse<HotSearchWordsResponse> = try await APIClient.shared.request(.get, path: "keywords")
        return response.data.keywords
    }
    
    // MARK: - User
    func fetchUserProfile() async throws -> UserProfileResponse {
        let response: BaseResponse<UserProfileResponse> = try await APIClient.shared.request(.get, path: "users/profile")
        return response.data
    }
    
    func fetchFavoriteComics(page: Int = 1, sort: ComicSortType = .dd) async throws -> ComicsList {
        let response: BaseResponse<ComicsResponse> = try await APIClient.shared.request(
            .get,
            path: "users/favourite",
            query: ["page": String(page), "s": sort.rawValue]
        )
        return response.data.comics
    }
    
    func updatePassword(oldPassword: String, newPassword: String) async throws {
        let _: BaseResponse<EmptyResponse> = try await APIClient.shared.request(
            .put,
            path: "users/password",
            body: ["old_password": oldPassword, "new_password": newPassword]
        )
    }
    
    func updateAvatar(base64: String) async throws {
        let _: BaseResponse<EmptyResponse> = try await APIClient.shared.request(
            .put,
            path: "users/avatar",
            body: ["avatar": "data:image/jpeg;base64,\(base64)"]
        )
    }
    
    func updateProfile(slogan: String) async throws {
        let _: BaseResponse<EmptyResponse> = try await APIClient.shared.request(
            .put,
            path: "users/profile",
            body: ["slogan": slogan]
        )
    }
    
    // MARK: - Rank
    func fetchComicRank(tt: String, ct: String) async throws -> ComicsList {
        let response: BaseResponse<ComicRankResponse> = try await APIClient.shared.request(
            .get,
            path: "comics/leaderboard",
            query: ["tt": tt, "ct": ct]
        )
        return response.data.comics
    }
    
    func fetchKnightRank() async throws -> ComicsList {
        let response: BaseResponse<ComicRankResponse> = try await APIClient.shared.request(.get, path: "comics/knight-leaderboard")
        return response.data.comics
    }
    
    // MARK: - Random
    func fetchRandomComics() async throws -> ComicsList {
        let response: BaseResponse<RandomComicsResponse> = try await APIClient.shared.request(.get, path: "comics/random")
        return response.data.comics
    }
    
    // MARK: - Notifications
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
nonisolated struct EmptyResponse: Decodable, Sendable {}

extension Encodable {
    nonisolated func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        let json = try JSONSerialization.jsonObject(with: data)
        return json as? [String: Any] ?? [:]
    }
}
