import Foundation

// These DTOs move through actors and child tasks, so they must remain
// nonisolated and sendable even though the app target defaults to MainActor.

// MARK: - Base Response
nonisolated struct BaseResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let code: Int
    let message: String
    let data: T
}

// MARK: - Login
nonisolated struct LoginPayload: Encodable, Sendable {
    let email: String
    let password: String
}

nonisolated struct LoginResponse: Decodable, Sendable {
    let token: String
}

// MARK: - Image Detail
nonisolated struct ImageDetail: Decodable, Sendable {
    let fileServer: String
    let path: String
    let originalName: String

    static let placeholder = ImageDetail(fileServer: "", path: "", originalName: "")
    
    var url: String {
        guard !fileServer.isEmpty, !path.isEmpty else { return "" }
        let normalizedServer = fileServer.hasSuffix("/") ? String(fileServer.dropLast()) : fileServer
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return normalizedServer.contains("static")
            ? "\(normalizedServer)/\(normalizedPath)"
            : "\(normalizedServer)/static/\(normalizedPath)"
    }

    init(fileServer: String, path: String, originalName: String) {
        self.fileServer = fileServer
        self.path = path
        self.originalName = originalName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileServer = try container.decodeIfPresent(String.self, forKey: .fileServer) ?? ""
        path = try container.decodeIfPresent(String.self, forKey: .path) ?? ""
        originalName = try container.decodeIfPresent(String.self, forKey: .originalName) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case fileServer, path, originalName
    }
}

// MARK: - Category
nonisolated struct PicaCategory: Decodable, Identifiable, Sendable {
    let rawId: String?
    let thumb: ImageDetail
    let title: String
    let description: String
    let isWeb: Bool?
    let active: Bool?
    let link: String?
    
    var id: String { rawId ?? title }
    
    enum CodingKeys: String, CodingKey {
        case rawId = "id"
        case thumb, title, description, isWeb, active, link
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rawId = try container.decodeIfPresent(String.self, forKey: .rawId)
        thumb = try container.decodeIfPresent(ImageDetail.self, forKey: .thumb) ?? .placeholder
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        isWeb = try container.decodeIfPresent(Bool.self, forKey: .isWeb)
        active = try container.decodeIfPresent(Bool.self, forKey: .active)
        link = try container.decodeIfPresent(String.self, forKey: .link)
    }
}

nonisolated struct CategoriesResponse: Decodable, Sendable {
    let categories: [PicaCategory]
}

// MARK: - Comic Sort Type
nonisolated enum ComicSortType: String, CaseIterable, Encodable, Identifiable, Sendable {
    case dd = "dd" // 新到旧
    case da = "da" // 旧到新
    case ld = "ld" // 最多喜欢
    case vd = "vd" // 最多观看
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .dd: return AppLocalization.text("sort.dd")
        case .da: return AppLocalization.text("sort.da")
        case .ld: return AppLocalization.text("sort.ld")
        case .vd: return AppLocalization.text("sort.vd")
        }
    }
}

// MARK: - Comics Payload
nonisolated struct ComicsPayload: Sendable {
    let page: Int?
    let c: String?
    let s: ComicSortType?
    let t: String?
    let a: String?
    let ct: String?
    let ca: String?
    
    var query: [String: String] {
        var result: [String: String] = [:]
        if let page = page { result["page"] = String(page) }
        if let c = c { result["c"] = c }
        if let s = s { result["s"] = s.rawValue }
        if let a = a { result["a"] = a }
        if let ca = ca { result["ca"] = ca }
        if let ct = ct { result["ct"] = ct }
        if let t = t { result["t"] = t }
        return result
    }
}

// MARK: - Doc (Comic List Item)
nonisolated struct ComicDoc: Decodable, Identifiable, Sendable {
    let uid: String
    let title: String
    let author: String
    let totalViews: Int
    let totalLikes: Int?
    let pagesCount: Int
    let epsCount: Int
    let finished: Bool
    let categories: [String]
    let thumb: ImageDetail
    let likesCount: Int
    let tags: [String]
    
    var id: String { uid }
    
    enum CodingKeys: String, CodingKey {
        case uid = "_id"
        case title, author, totalViews, totalLikes, pagesCount, epsCount
        case finished, categories, thumb, likesCount, tags
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decode(String.self, forKey: .uid)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        totalViews = try container.decodeLossyIntIfPresent(forKey: .totalViews) ?? 0
        totalLikes = try container.decodeLossyIntIfPresent(forKey: .totalLikes)
        pagesCount = try container.decode(Int.self, forKey: .pagesCount)
        epsCount = try container.decode(Int.self, forKey: .epsCount)
        finished = try container.decode(Bool.self, forKey: .finished)
        categories = try container.decodeIfPresent([String].self, forKey: .categories) ?? []
        thumb = try container.decodeIfPresent(ImageDetail.self, forKey: .thumb) ?? .placeholder
        likesCount = try container.decodeLossyIntIfPresent(forKey: .likesCount) ?? 0
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

// MARK: - Comics List
nonisolated struct ComicsList: Decodable, Sendable {
    let docs: [ComicDoc]
    let limit: Int
    let page: Int
    let pages: Int
    let total: Int
}

nonisolated struct ComicsResponse: Decodable, Sendable {
    let comics: ComicsList
}

// MARK: - Creator
nonisolated struct Creator: Decodable, Sendable {
    let id: String
    let gender: String
    let name: String
    let exp: Int
    let level: Int
    let role: String
    let avatar: ImageDetail?
    let characters: [String]
    let title: String
    let slogan: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case gender, name, exp, level, role, avatar, characters, title, slogan
    }

    static let placeholder = Creator(
        id: "unknown",
        gender: "",
        name: AppLocalization.text("data.unknownAuthor"),
        exp: 0,
        level: 0,
        role: "",
        avatar: nil,
        characters: [],
        title: "",
        slogan: nil
    )

    init(
        id: String,
        gender: String,
        name: String,
        exp: Int,
        level: Int,
        role: String,
        avatar: ImageDetail?,
        characters: [String],
        title: String,
        slogan: String?
    ) {
        self.id = id
        self.gender = gender
        self.name = name
        self.exp = exp
        self.level = level
        self.role = role
        self.avatar = avatar
        self.characters = characters
        self.title = title
        self.slogan = slogan
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "unknown"
        gender = try container.decodeIfPresent(String.self, forKey: .gender) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? AppLocalization.text("data.unknownAuthor")
        exp = try container.decodeLossyIntIfPresent(forKey: .exp) ?? 0
        level = try container.decodeLossyIntIfPresent(forKey: .level) ?? 0
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? ""
        avatar = try container.decodeIfPresent(ImageDetail.self, forKey: .avatar)
        characters = try container.decodeIfPresent([String].self, forKey: .characters) ?? []
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        slogan = try container.decodeIfPresent(String.self, forKey: .slogan)
    }
}

// MARK: - Comic Detail
nonisolated struct ComicDetail: Decodable, Identifiable, Sendable {
    let id: String
    let creator: Creator
    let title: String
    let description: String
    let thumb: ImageDetail
    let author: String?
    let categories: [String]
    let chineseTeam: String
    let tags: [String]
    let pagesCount: Int
    let epsCount: Int
    let finished: Bool
    let updatedAt: String
    let createdAt: String
    let allowDownload: Bool
    let allowComment: Bool
    let totalLikes: Int
    let totalViews: Int
    let totalComments: Int?
    let viewsCount: Int
    let likesCount: Int
    let commentsCount: Int
    let isFavourite: Bool
    let isLiked: Bool
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case creator = "_creator"
        case title, description, thumb, author, categories
        case chineseTeam, tags, pagesCount, epsCount, finished
        case updatedAt = "updated_at"
        case createdAt = "created_at"
        case allowDownload, allowComment
        case totalLikes, totalViews, totalComments
        case viewsCount, likesCount, commentsCount
        case isFavourite, isLiked
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        creator = try container.decodeIfPresent(Creator.self, forKey: .creator) ?? .placeholder
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? AppLocalization.text("data.untitledComic")
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        thumb = try container.decodeIfPresent(ImageDetail.self, forKey: .thumb) ?? .placeholder
        author = try container.decodeIfPresent(String.self, forKey: .author)
        categories = try container.decodeIfPresent([String].self, forKey: .categories) ?? []
        chineseTeam = try container.decodeIfPresent(String.self, forKey: .chineseTeam) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        pagesCount = try container.decodeLossyIntIfPresent(forKey: .pagesCount) ?? 0
        epsCount = try container.decodeLossyIntIfPresent(forKey: .epsCount) ?? 0
        finished = try container.decodeIfPresent(Bool.self, forKey: .finished) ?? false
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        allowDownload = try container.decodeIfPresent(Bool.self, forKey: .allowDownload) ?? false
        allowComment = try container.decodeIfPresent(Bool.self, forKey: .allowComment) ?? false
        totalLikes = try container.decodeLossyIntIfPresent(forKey: .totalLikes) ?? 0
        totalViews = try container.decodeLossyIntIfPresent(forKey: .totalViews) ?? 0
        totalComments = try container.decodeLossyIntIfPresent(forKey: .totalComments)
        viewsCount = try container.decodeLossyIntIfPresent(forKey: .viewsCount) ?? 0
        likesCount = try container.decodeLossyIntIfPresent(forKey: .likesCount) ?? 0
        commentsCount = try container.decodeLossyIntIfPresent(forKey: .commentsCount) ?? 0
        isFavourite = try container.decodeIfPresent(Bool.self, forKey: .isFavourite) ?? false
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked) ?? false
    }
}

nonisolated struct ComicDetailsResponse: Decodable, Sendable {
    let comic: ComicDetail
}

// MARK: - Chapter
nonisolated struct PicaChapter: Decodable, Identifiable, Sendable {
    let uid: String
    let title: String
    let order: Int
    let updatedAt: String
    let id: String
    
    enum CodingKeys: String, CodingKey {
        case uid = "_id"
        case title, order, id
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decodeIfPresent(String.self, forKey: .uid) ?? UUID().uuidString
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? AppLocalization.text("data.untitledChapter")
        order = try container.decodeLossyIntIfPresent(forKey: .order) ?? 0
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? uid
    }
}

nonisolated struct ChaptersList: Decodable, Sendable {
    let docs: [PicaChapter]
    let total: Int
    let limit: Int
    let page: Int
    let pages: Int
}

nonisolated struct ChaptersResponse: Decodable, Sendable {
    let eps: ChaptersList
}

// MARK: - Recommend
nonisolated struct RecommendComic: Decodable, Identifiable, Sendable {
    let id: String
    let title: String
    let author: String
    let thumb: ImageDetail
    let pagesCount: Int
    let epsCount: Int
    let finished: Bool
    let categories: [String]
    let likesCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, author, thumb, pagesCount, epsCount, finished, categories, likesCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        thumb = try container.decodeIfPresent(ImageDetail.self, forKey: .thumb) ?? .placeholder
        pagesCount = try container.decodeLossyIntIfPresent(forKey: .pagesCount) ?? 0
        epsCount = try container.decodeLossyIntIfPresent(forKey: .epsCount) ?? 0
        finished = try container.decode(Bool.self, forKey: .finished)
        categories = try container.decodeIfPresent([String].self, forKey: .categories) ?? []
        likesCount = try container.decodeLossyIntIfPresent(forKey: .likesCount) ?? 0
    }
}

nonisolated struct RecommendComics: Decodable, Sendable {
    let comics: [RecommendComic]
}

// MARK: - Chapter Images
nonisolated struct ChapterImage: Decodable, Identifiable, Sendable {
    let uid: String
    let id: String?
    let media: ImageDetail
    
    var url: String { media.url }
    
    enum CodingKeys: String, CodingKey {
        case uid = "_id"
        case id, media
    }
}

nonisolated struct ChaptersImages: Decodable, Sendable {
    let docs: [ChapterImage]
    let total: Int
    let limit: Int
    let page: Int
    let pages: Int
}

nonisolated struct ChapterEpisode: Decodable, Sendable {
    let id: String
    let title: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
    }
}

nonisolated struct FetchChapterImagesResponse: Decodable, Sendable {
    let pages: ChaptersImages
    let ep: ChapterEpisode
}

// MARK: - Action Response
nonisolated struct ActionResponse: Decodable, Sendable {
    let action: String
}

// MARK: - Search
nonisolated struct SearchPayload: Encodable, Sendable {
    let keyword: String
    let page: Int
    let sort: ComicSortType
    
    enum CodingKeys: String, CodingKey {
        case keyword, sort
    }
}

nonisolated struct SearchComic: Decodable, Identifiable, Sendable {
    let uid: String
    let title: String
    let author: String
    let thumb: ImageDetail
    let totalViews: Int?
    let categories: [String]
    let totalLikes: Int?
    let likesCount: Int
    let tags: [String]
    let finished: Bool
    
    var id: String { uid }
    
    enum CodingKeys: String, CodingKey {
        case uid = "_id"
        case title, author, thumb, totalViews, categories, totalLikes, likesCount, tags, finished
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decode(String.self, forKey: .uid)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? "??"
        thumb = try container.decodeIfPresent(ImageDetail.self, forKey: .thumb) ?? .placeholder
        totalViews = try container.decodeLossyIntIfPresent(forKey: .totalViews)
        categories = try container.decodeIfPresent([String].self, forKey: .categories) ?? []
        totalLikes = try container.decodeLossyIntIfPresent(forKey: .totalLikes)
        likesCount = try container.decodeLossyIntIfPresent(forKey: .likesCount) ?? 0
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        finished = try container.decode(Bool.self, forKey: .finished)
    }
}

nonisolated struct SearchComicsList: Decodable, Sendable {
    let docs: [SearchComic]
    let total: Int
    let limit: Int
    let page: Int
    let pages: Int
}

nonisolated struct SearchResponse: Decodable, Sendable {
    let comics: SearchComicsList
}

// MARK: - User Profile
nonisolated struct UserProfileResponse: Decodable, Sendable {
    let user: UserProfile
    
    var name: String { user.name }
    var email: String { user.email }
    var avatar: ImageDetail? { user.avatar }
    var exp: Int { user.exp }
    var level: Int { user.level }
    var gender: String { user.gender }
    var slogan: String { user.slogan }
    var title: String { user.title }
    var birthday: String { user.birthday }
    var character: String { user.character }
    var isPunched: Bool { user.isPunched }
    var comicsUploaded: Int { user.comicsUploaded }
}

nonisolated struct UserProfile: Decodable, Sendable {
    let id: String
    let birthday: String
    let email: String
    let gender: String
    let name: String
    let slogan: String
    let title: String
    let verified: Bool
    let exp: Int
    let level: Int
    let characters: [String]
    let createdAt: String
    let avatar: ImageDetail?
    let isPunched: Bool
    let character: String
    let comicsUploaded: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case birthday, email, gender, name, slogan, title, verified, exp, level, characters, avatar, character, comicsUploaded
        case createdAt = "created_at"
        case isPunched
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        birthday = try container.decodeIfPresent(String.self, forKey: .birthday) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        gender = try container.decodeIfPresent(String.self, forKey: .gender) ?? "m"
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        slogan = try container.decodeIfPresent(String.self, forKey: .slogan) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? AppLocalization.text("data.novice")
        verified = try container.decodeIfPresent(Bool.self, forKey: .verified) ?? false
        exp = try container.decodeLossyIntIfPresent(forKey: .exp) ?? 0
        level = try container.decodeLossyIntIfPresent(forKey: .level) ?? 0
        characters = try container.decodeIfPresent([String].self, forKey: .characters) ?? []
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        avatar = try container.decodeIfPresent(ImageDetail.self, forKey: .avatar)
        isPunched = try container.decodeIfPresent(Bool.self, forKey: .isPunched) ?? false
        character = try container.decodeIfPresent(String.self, forKey: .character) ?? ""
        comicsUploaded = try container.decodeLossyIntIfPresent(forKey: .comicsUploaded) ?? 0
    }
}

// MARK: - Rank
nonisolated struct ComicRankPayload: Sendable {
    let tt: String
    let ct: String
    
    var query: [String: String] {
        ["tt": tt, "ct": ct]
    }
}

nonisolated struct ComicRankResponse: Decodable, Sendable {
    let comics: ComicsList
}

// MARK: - Random
nonisolated struct RandomComicsResponse: Decodable, Sendable {
    let comics: ComicsList
}

// MARK: - User Favorite
nonisolated struct UserFavoritePayload: Sendable {
    let page: Int
    let sort: ComicSortType
    
    var query: [String: String] {
        ["page": String(page), "s": sort.rawValue]
    }
}

// MARK: - Notifications
nonisolated struct PicaNotification: Decodable, Identifiable, Sendable {
    let id: String
    let title: String
    let content: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, content
        case createdAt = "created_at"
    }
}

nonisolated struct NotificationsList: Decodable, Sendable {
    let docs: [PicaNotification]
    let total: Int
    let limit: Int
    let page: Int
    let pages: Int
}

nonisolated struct NotificationsResponse: Decodable, Sendable {
    let notifications: NotificationsList
}

// MARK: - Hot Search
nonisolated struct HotSearchWordsResponse: Decodable, Sendable {
    let keywords: [String]
}

// MARK: - Extra Recommend
nonisolated struct ExtraRecommendComic: Decodable, Sendable {
    let id: String
    let title: String
    let pic: String
}

private extension KeyedDecodingContainer {
    nonisolated func decodeLossyIntIfPresent(forKey key: Key) throws -> Int? {
        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }
        return nil
    }
}
