import Foundation
import Combine

nonisolated struct AppMetadata {
    static let version = "0.1.0"
}

nonisolated enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"

    static let storageKey = "app_language"

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .english: return "English"
        case .japanese: return "日本語"
        }
    }

    static var stored: AppLanguage {
        if let rawValue = UserDefaults.standard.string(forKey: storageKey),
           let language = AppLanguage(rawValue: rawValue) {
            return language
        }
        return .simplifiedChinese
    }
}

@MainActor
final class AppLocalization: ObservableObject {
    static let shared = AppLocalization()

    @Published private(set) var language: AppLanguage

    private init() {
        language = AppLanguage.stored
    }

    var locale: Locale {
        language.locale
    }

    func setLanguage(_ language: AppLanguage) {
        guard self.language != language else { return }
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
    }

    func text(_ key: String, _ arguments: CVarArg...) -> String {
        Self.text(key, language: language, arguments: arguments)
    }

    nonisolated static func text(_ key: String, language: AppLanguage = AppLanguage.stored, _ arguments: CVarArg...) -> String {
        text(key, language: language, arguments: arguments)
    }

    nonisolated private static func text(_ key: String, language: AppLanguage, arguments: [CVarArg]) -> String {
        let template = AppLocalizationCatalog.strings[key]?[language]
            ?? AppLocalizationCatalog.strings[key]?[.simplifiedChinese]
            ?? key

        guard !arguments.isEmpty else { return template }

        return withVaList(arguments) { pointer in
            NSString(format: template, locale: language.locale, arguments: pointer) as String
        }
    }
}

nonisolated private enum AppLocalizationCatalog {
    static let strings: [String: [AppLanguage: String]] = [
        "tab.home": [
            .simplifiedChinese: "首页",
            .traditionalChinese: "首頁",
            .english: "Home",
            .japanese: "ホーム"
        ],
        "tab.categories": [
            .simplifiedChinese: "分类",
            .traditionalChinese: "分類",
            .english: "Categories",
            .japanese: "カテゴリ"
        ],
        "tab.search": [
            .simplifiedChinese: "搜索",
            .traditionalChinese: "搜尋",
            .english: "Search",
            .japanese: "検索"
        ],
        "tab.profile": [
            .simplifiedChinese: "我的",
            .traditionalChinese: "我的",
            .english: "Profile",
            .japanese: "マイ"
        ],
        "theme.system": [
            .simplifiedChinese: "跟随系统",
            .traditionalChinese: "跟隨系統",
            .english: "System",
            .japanese: "システム"
        ],
        "theme.light": [
            .simplifiedChinese: "浅色",
            .traditionalChinese: "淺色",
            .english: "Light",
            .japanese: "ライト"
        ],
        "theme.dark": [
            .simplifiedChinese: "深色",
            .traditionalChinese: "深色",
            .english: "Dark",
            .japanese: "ダーク"
        ],
        "auth.subtitle": [
            .simplifiedChinese: "登录后继续阅读与收藏",
            .traditionalChinese: "登入後繼續閱讀與收藏",
            .english: "Sign in to continue reading and saving favorites",
            .japanese: "ログインして読書とお気に入りを続けましょう"
        ],
        "auth.username": [
            .simplifiedChinese: "用户名",
            .traditionalChinese: "使用者名稱",
            .english: "Username",
            .japanese: "ユーザー名"
        ],
        "auth.password": [
            .simplifiedChinese: "密码",
            .traditionalChinese: "密碼",
            .english: "Password",
            .japanese: "パスワード"
        ],
        "auth.rememberPassword": [
            .simplifiedChinese: "记住密码",
            .traditionalChinese: "記住密碼",
            .english: "Remember password",
            .japanese: "パスワードを保存"
        ],
        "auth.login": [
            .simplifiedChinese: "登录",
            .traditionalChinese: "登入",
            .english: "Sign In",
            .japanese: "ログイン"
        ],
        "auth.network": [
            .simplifiedChinese: "网络源",
            .traditionalChinese: "網路來源",
            .english: "Network Source",
            .japanese: "ネットワークソース"
        ],
        "auth.restoring.title": [
            .simplifiedChinese: "正在恢复会话",
            .traditionalChinese: "正在恢復工作階段",
            .english: "Restoring Session",
            .japanese: "セッションを復元中"
        ],
        "auth.restoring.subtitle": [
            .simplifiedChinese: "请稍候，我们正在检查登录状态。",
            .traditionalChinese: "請稍候，我們正在檢查登入狀態。",
            .english: "Please wait while we verify your sign-in state.",
            .japanese: "ログイン状態を確認しています。しばらくお待ちください。"
        ],
        "home.title": [
            .simplifiedChinese: "首页",
            .traditionalChinese: "首頁",
            .english: "Home",
            .japanese: "ホーム"
        ],
        "home.categories": [
            .simplifiedChinese: "分类",
            .traditionalChinese: "分類",
            .english: "Categories",
            .japanese: "カテゴリ"
        ],
        "home.all": [
            .simplifiedChinese: "全部",
            .traditionalChinese: "全部",
            .english: "All",
            .japanese: "すべて"
        ],
        "home.latest": [
            .simplifiedChinese: "最新漫画",
            .traditionalChinese: "最新漫畫",
            .english: "Latest Comics",
            .japanese: "最新マンガ"
        ],
        "home.empty.title": [
            .simplifiedChinese: "暂无漫画",
            .traditionalChinese: "暫無漫畫",
            .english: "No Comics Yet",
            .japanese: "マンガがありません"
        ],
        "home.empty.subtitle": [
            .simplifiedChinese: "稍后再来看看，或者切换一个分类",
            .traditionalChinese: "稍後再來看看，或者切換一個分類",
            .english: "Check back later or switch to another category.",
            .japanese: "しばらくしてから再度確認するか、別のカテゴリに切り替えてください。"
        ],
        "categories.title": [
            .simplifiedChinese: "分类",
            .traditionalChinese: "分類",
            .english: "Categories",
            .japanese: "カテゴリ"
        ],
        "categories.empty.title": [
            .simplifiedChinese: "暂无分类",
            .traditionalChinese: "暫無分類",
            .english: "No Categories",
            .japanese: "カテゴリがありません"
        ],
        "categories.empty.subtitle": [
            .simplifiedChinese: "稍后再试，或者下拉刷新",
            .traditionalChinese: "稍後再試，或者下拉重新整理",
            .english: "Try again later or pull to refresh.",
            .japanese: "しばらくしてから再試行するか、引っ張って更新してください。"
        ],
        "search.title": [
            .simplifiedChinese: "搜索",
            .traditionalChinese: "搜尋",
            .english: "Search",
            .japanese: "検索"
        ],
        "search.placeholder": [
            .simplifiedChinese: "搜索漫画...",
            .traditionalChinese: "搜尋漫畫...",
            .english: "Search comics...",
            .japanese: "マンガを検索..."
        ],
        "search.history": [
            .simplifiedChinese: "搜索历史",
            .traditionalChinese: "搜尋記錄",
            .english: "Search History",
            .japanese: "検索履歴"
        ],
        "search.hot": [
            .simplifiedChinese: "热门搜索",
            .traditionalChinese: "熱門搜尋",
            .english: "Trending Searches",
            .japanese: "人気検索"
        ],
        "search.noSuggestions": [
            .simplifiedChinese: "暂时没有推荐关键词",
            .traditionalChinese: "暫時沒有推薦關鍵字",
            .english: "No recommended keywords yet.",
            .japanese: "おすすめキーワードはまだありません。"
        ],
        "search.results": [
            .simplifiedChinese: "搜索结果",
            .traditionalChinese: "搜尋結果",
            .english: "Results",
            .japanese: "検索結果"
        ],
        "search.empty.title": [
            .simplifiedChinese: "未找到结果",
            .traditionalChinese: "找不到結果",
            .english: "No Results Found",
            .japanese: "結果が見つかりません"
        ],
        "search.empty.subtitle": [
            .simplifiedChinese: "试试更短的关键词，或者切换排序方式",
            .traditionalChinese: "試試更短的關鍵字，或者切換排序方式",
            .english: "Try a shorter keyword or switch the sort mode.",
            .japanese: "より短いキーワードを試すか、並び順を変更してください。"
        ],
        "search.retry": [
            .simplifiedChinese: "重试搜索",
            .traditionalChinese: "重新搜尋",
            .english: "Retry Search",
            .japanese: "検索をやり直す"
        ],
        "search.filter.title": [
            .simplifiedChinese: "筛选",
            .traditionalChinese: "篩選",
            .english: "Filters",
            .japanese: "フィルター"
        ],
        "search.filter.sort": [
            .simplifiedChinese: "排序",
            .traditionalChinese: "排序",
            .english: "Sorting",
            .japanese: "並び順"
        ],
        "search.filter.mode": [
            .simplifiedChinese: "排序方式",
            .traditionalChinese: "排序方式",
            .english: "Sort Mode",
            .japanese: "並び替え方法"
        ],
        "search.filter.direction": [
            .simplifiedChinese: "排序方向",
            .traditionalChinese: "排序方向",
            .english: "Sort Direction",
            .japanese: "並び順方向"
        ],
        "search.filter.ascending": [
            .simplifiedChinese: "升序",
            .traditionalChinese: "升冪",
            .english: "Ascending",
            .japanese: "昇順"
        ],
        "search.filter.descending": [
            .simplifiedChinese: "降序",
            .traditionalChinese: "降冪",
            .english: "Descending",
            .japanese: "降順"
        ],
        "sort.dd": [
            .simplifiedChinese: "新到旧",
            .traditionalChinese: "新到舊",
            .english: "Newest First",
            .japanese: "新しい順"
        ],
        "sort.da": [
            .simplifiedChinese: "旧到新",
            .traditionalChinese: "舊到新",
            .english: "Oldest First",
            .japanese: "古い順"
        ],
        "sort.ld": [
            .simplifiedChinese: "最多喜欢",
            .traditionalChinese: "最多喜歡",
            .english: "Most Likes",
            .japanese: "いいね順"
        ],
        "sort.vd": [
            .simplifiedChinese: "最多观看",
            .traditionalChinese: "最多觀看",
            .english: "Most Views",
            .japanese: "閲覧数順"
        ],
        "browser.favorites.title": [
            .simplifiedChinese: "我的收藏",
            .traditionalChinese: "我的收藏",
            .english: "Favorites",
            .japanese: "お気に入り"
        ],
        "browser.empty.comics": [
            .simplifiedChinese: "暂无漫画",
            .traditionalChinese: "暫無漫畫",
            .english: "No Comics",
            .japanese: "マンガがありません"
        ],
        "browser.empty.favorites": [
            .simplifiedChinese: "暂无收藏",
            .traditionalChinese: "暫無收藏",
            .english: "No Favorites Yet",
            .japanese: "お気に入りがありません"
        ],
        "browser.empty.category.subtitle": [
            .simplifiedChinese: "%@ 分类里还没有可显示的内容",
            .traditionalChinese: "%@ 分類裡還沒有可顯示的內容",
            .english: "There is nothing visible in %@ yet.",
            .japanese: "%@ にはまだ表示できる作品がありません。"
        ],
        "browser.empty.favorites.subtitle": [
            .simplifiedChinese: "收藏漫画后会在这里完整显示",
            .traditionalChinese: "收藏漫畫後會在這裡完整顯示",
            .english: "Favorited comics will appear here in full.",
            .japanese: "お気に入りに追加した作品がここに表示されます。"
        ],
        "profile.title": [
            .simplifiedChinese: "我的",
            .traditionalChinese: "我的",
            .english: "Profile",
            .japanese: "マイ"
        ],
        "profile.unnamed": [
            .simplifiedChinese: "未命名用户",
            .traditionalChinese: "未命名使用者",
            .english: "Unnamed User",
            .japanese: "未設定ユーザー"
        ],
        "profile.levelExp": [
            .simplifiedChinese: "Lv.%d · EXP %d",
            .traditionalChinese: "Lv.%d · EXP %d",
            .english: "Lv.%d · EXP %d",
            .japanese: "Lv.%d ・ EXP %d"
        ],
        "profile.stats.exp": [
            .simplifiedChinese: "经验",
            .traditionalChinese: "經驗",
            .english: "EXP",
            .japanese: "経験値"
        ],
        "profile.stats.upload": [
            .simplifiedChinese: "上传",
            .traditionalChinese: "上傳",
            .english: "Uploads",
            .japanese: "投稿"
        ],
        "profile.stats.favorites": [
            .simplifiedChinese: "收藏",
            .traditionalChinese: "收藏",
            .english: "Favorites",
            .japanese: "お気に入り"
        ],
        "profile.section.content": [
            .simplifiedChinese: "内容",
            .traditionalChinese: "內容",
            .english: "Content",
            .japanese: "コンテンツ"
        ],
        "profile.favorites.entry": [
            .simplifiedChinese: "我的收藏",
            .traditionalChinese: "我的收藏",
            .english: "My Favorites",
            .japanese: "お気に入り"
        ],
        "profile.favorites.empty": [
            .simplifiedChinese: "点击进入完整两列瀑布流",
            .traditionalChinese: "點擊進入完整雙列瀑布流",
            .english: "Open the full two-column grid.",
            .japanese: "2列グリッドを開く"
        ],
        "profile.favorites.unavailable": [
            .simplifiedChinese: "暂时无法同步总量，仍可进入完整双列浏览",
            .traditionalChinese: "暫時無法同步總量，仍可進入完整雙列瀏覽",
            .english: "The total is temporarily unavailable, but you can still open the full two-column browser.",
            .japanese: "合計は一時的に取得できませんが、2列ブラウザは開けます。"
        ],
        "profile.favorites.syncedCount": [
            .simplifiedChinese: "服务器记录 %d 本，点击进入完整双列浏览",
            .traditionalChinese: "伺服器記錄 %d 本，點擊進入完整雙列瀏覽",
            .english: "%d comics recorded on the server. Tap to open the full two-column browser.",
            .japanese: "サーバー記録は%d冊です。タップして2列ブラウザを開きます。"
        ],
        "profile.favorites.count": [
            .simplifiedChinese: "共 %d 本，点击进入浏览",
            .traditionalChinese: "共 %d 本，點擊進入瀏覽",
            .english: "%d comics, tap to browse.",
            .japanese: "%d冊、タップして閲覧"
        ],
        "profile.favorites.browse": [
            .simplifiedChinese: "浏览",
            .traditionalChinese: "瀏覽",
            .english: "Browse",
            .japanese: "閲覧"
        ],
        "profile.section.features": [
            .simplifiedChinese: "功能",
            .traditionalChinese: "功能",
            .english: "Actions",
            .japanese: "機能"
        ],
        "profile.punch.done": [
            .simplifiedChinese: "今日已打卡",
            .traditionalChinese: "今日已打卡",
            .english: "Checked In Today",
            .japanese: "本日はチェックイン済み"
        ],
        "profile.punch.done.subtitle": [
            .simplifiedChinese: "明天再来继续",
            .traditionalChinese: "明天再來繼續",
            .english: "Come back tomorrow.",
            .japanese: "また明日どうぞ。"
        ],
        "profile.punch.action": [
            .simplifiedChinese: "每日打卡",
            .traditionalChinese: "每日打卡",
            .english: "Daily Check-In",
            .japanese: "デイリーチェックイン"
        ],
        "profile.punch.action.subtitle": [
            .simplifiedChinese: "领取今日奖励",
            .traditionalChinese: "領取今日獎勵",
            .english: "Claim today's reward.",
            .japanese: "今日の報酬を受け取る"
        ],
        "profile.settings": [
            .simplifiedChinese: "设置",
            .traditionalChinese: "設定",
            .english: "Settings",
            .japanese: "設定"
        ],
        "profile.settings.subtitle": [
            .simplifiedChinese: "主题、缓存与应用信息",
            .traditionalChinese: "主題、快取與應用程式資訊",
            .english: "Theme, cache, and app info.",
            .japanese: "テーマ、キャッシュ、アプリ情報"
        ],
        "profile.logout": [
            .simplifiedChinese: "退出登录",
            .traditionalChinese: "登出",
            .english: "Sign Out",
            .japanese: "ログアウト"
        ],
        "profile.logout.subtitle": [
            .simplifiedChinese: "清除当前登录状态",
            .traditionalChinese: "清除目前登入狀態",
            .english: "Clear the current sign-in state.",
            .japanese: "現在のログイン状態を解除"
        ],
        "settings.title": [
            .simplifiedChinese: "设置",
            .traditionalChinese: "設定",
            .english: "Settings",
            .japanese: "設定"
        ],
        "settings.appearance": [
            .simplifiedChinese: "外观",
            .traditionalChinese: "外觀",
            .english: "Appearance",
            .japanese: "外観"
        ],
        "settings.theme": [
            .simplifiedChinese: "暗黑模式",
            .traditionalChinese: "深色模式",
            .english: "Theme",
            .japanese: "テーマ"
        ],
        "settings.language": [
            .simplifiedChinese: "语言",
            .traditionalChinese: "語言",
            .english: "Language",
            .japanese: "言語"
        ],
        "settings.network": [
            .simplifiedChinese: "网络线路",
            .traditionalChinese: "網路線路",
            .english: "Network Route",
            .japanese: "ネットワーク経路"
        ],
        "settings.cache": [
            .simplifiedChinese: "缓存",
            .traditionalChinese: "快取",
            .english: "Cache",
            .japanese: "キャッシュ"
        ],
        "settings.cache.clear": [
            .simplifiedChinese: "清理图片缓存",
            .traditionalChinese: "清除圖片快取",
            .english: "Clear Image Cache",
            .japanese: "画像キャッシュを削除"
        ],
        "settings.cache.clearing": [
            .simplifiedChinese: "正在清理缓存...",
            .traditionalChinese: "正在清理快取...",
            .english: "Clearing cache...",
            .japanese: "キャッシュを削除中..."
        ],
        "settings.cache.cleared": [
            .simplifiedChinese: "缓存已清空",
            .traditionalChinese: "快取已清空",
            .english: "Cache cleared.",
            .japanese: "キャッシュを削除しました。"
        ],
        "settings.source": [
            .simplifiedChinese: "代码与许可",
            .traditionalChinese: "程式碼與授權",
            .english: "Code and License",
            .japanese: "コードとライセンス"
        ],
        "settings.deviceCode": [
            .simplifiedChinese: "本机代码",
            .traditionalChinese: "本機代碼",
            .english: "Bundle ID",
            .japanese: "バンドルID"
        ],
        "settings.repository": [
            .simplifiedChinese: "源代码仓库",
            .traditionalChinese: "原始碼倉庫",
            .english: "Source Repository",
            .japanese: "ソースリポジトリ"
        ],
        "settings.license": [
            .simplifiedChinese: "开源许可",
            .traditionalChinese: "開源授權",
            .english: "Open Source License",
            .japanese: "オープンソースライセンス"
        ],
        "settings.references": [
            .simplifiedChinese: "第三方说明",
            .traditionalChinese: "第三方說明",
            .english: "Third-Party Notices",
            .japanese: "サードパーティ通知"
        ],
        "settings.about": [
            .simplifiedChinese: "关于",
            .traditionalChinese: "關於",
            .english: "About",
            .japanese: "情報"
        ],
        "settings.version": [
            .simplifiedChinese: "版本",
            .traditionalChinese: "版本",
            .english: "Version",
            .japanese: "バージョン"
        ],
        "settings.sdk": [
            .simplifiedChinese: "SDK",
            .traditionalChinese: "SDK",
            .english: "SDK",
            .japanese: "SDK"
        ],
        "endpoint.picacomic.name": [
            .simplifiedChinese: "Picacomic 官方",
            .traditionalChinese: "Picacomic 官方",
            .english: "Picacomic Official",
            .japanese: "Picacomic 公式"
        ],
        "endpoint.picacomic.desc": [
            .simplifiedChinese: "官方直连，适合可直接访问官方接口的网络环境。",
            .traditionalChinese: "官方直連，適合可直接存取官方介面的網路環境。",
            .english: "Direct official route for networks that can reach the official API.",
            .japanese: "公式APIへ直接接続できるネットワーク向けの公式ルートです。"
        ],
        "endpoint.go2778.name": [
            .simplifiedChinese: "Go2778 代理",
            .traditionalChinese: "Go2778 代理",
            .english: "Go2778 Relay",
            .japanese: "Go2778 リレー"
        ],
        "endpoint.go2778.desc": [
            .simplifiedChinese: "CDN 中转，通常兼容性更好，和参考实现的默认设置一致。",
            .traditionalChinese: "CDN 中轉，通常相容性更好，與參考實作的預設設定一致。",
            .english: "CDN relay with better compatibility, matching the reference default.",
            .japanese: "互換性が高いCDNリレーで、参照実装の既定設定と同じです。"
        ],
        "common.done": [
            .simplifiedChinese: "完成",
            .traditionalChinese: "完成",
            .english: "Done",
            .japanese: "完了"
        ],
        "common.cancel": [
            .simplifiedChinese: "取消",
            .traditionalChinese: "取消",
            .english: "Cancel",
            .japanese: "キャンセル"
        ],
        "common.apply": [
            .simplifiedChinese: "应用",
            .traditionalChinese: "套用",
            .english: "Apply",
            .japanese: "適用"
        ],
        "common.clear": [
            .simplifiedChinese: "清除",
            .traditionalChinese: "清除",
            .english: "Clear",
            .japanese: "クリア"
        ],
        "common.reload": [
            .simplifiedChinese: "重新加载",
            .traditionalChinese: "重新載入",
            .english: "Reload",
            .japanese: "再読み込み"
        ],
        "api.invalidURL": [
            .simplifiedChinese: "无效的 URL",
            .traditionalChinese: "無效的 URL",
            .english: "Invalid URL",
            .japanese: "無効なURLです"
        ],
        "api.networkError": [
            .simplifiedChinese: "网络错误: %@",
            .traditionalChinese: "網路錯誤: %@",
            .english: "Network error: %@",
            .japanese: "ネットワークエラー: %@"
        ],
        "api.invalidResponse": [
            .simplifiedChinese: "无效的响应",
            .traditionalChinese: "無效的回應",
            .english: "Invalid response",
            .japanese: "無効なレスポンスです"
        ],
        "api.serverError": [
            .simplifiedChinese: "服务器错误 %d: %@",
            .traditionalChinese: "伺服器錯誤 %d: %@",
            .english: "Server error %d: %@",
            .japanese: "サーバーエラー %d: %@"
        ],
        "api.badRequest": [
            .simplifiedChinese: "请求错误",
            .traditionalChinese: "請求錯誤",
            .english: "Bad request",
            .japanese: "リクエストエラー"
        ],
        "api.unauthorized": [
            .simplifiedChinese: "登录已失效，请重新登录",
            .traditionalChinese: "登入已失效，請重新登入",
            .english: "Your session expired. Please sign in again.",
            .japanese: "セッションの有効期限が切れました。再度ログインしてください。"
        ],
        "api.emptyData": [
            .simplifiedChinese: "空数据",
            .traditionalChinese: "空資料",
            .english: "Empty data",
            .japanese: "データが空です"
        ],
        "api.encodingError": [
            .simplifiedChinese: "请求编码错误: %@",
            .traditionalChinese: "請求編碼錯誤: %@",
            .english: "Request encoding error: %@",
            .japanese: "リクエストのエンコードエラー: %@"
        ],
        "api.decodingError": [
            .simplifiedChinese: "解析错误: %@",
            .traditionalChinese: "解析錯誤: %@",
            .english: "Decoding error: %@",
            .japanese: "デコードエラー: %@"
        ],
        "reader.mode.vertical": [
            .simplifiedChinese: "纵向滚动",
            .traditionalChinese: "縱向捲動",
            .english: "Vertical Scroll",
            .japanese: "縦スクロール"
        ],
        "reader.mode.horizontal": [
            .simplifiedChinese: "横向翻页",
            .traditionalChinese: "橫向翻頁",
            .english: "Horizontal Paging",
            .japanese: "横ページ送り"
        ],
        "reader.settings.title": [
            .simplifiedChinese: "阅读设置",
            .traditionalChinese: "閱讀設定",
            .english: "Reader Settings",
            .japanese: "リーダー設定"
        ],
        "reader.settings.direction": [
            .simplifiedChinese: "阅读方向",
            .traditionalChinese: "閱讀方向",
            .english: "Reading Direction",
            .japanese: "読書方向"
        ],
        "reader.settings.direction.label": [
            .simplifiedChinese: "方向",
            .traditionalChinese: "方向",
            .english: "Direction",
            .japanese: "方向"
        ],
        "reader.settings.display": [
            .simplifiedChinese: "显示",
            .traditionalChinese: "顯示",
            .english: "Display",
            .japanese: "表示"
        ],
        "reader.settings.showPageNumbers": [
            .simplifiedChinese: "显示页码",
            .traditionalChinese: "顯示頁碼",
            .english: "Show Page Number",
            .japanese: "ページ番号を表示"
        ],
        "reader.settings.lockMenu": [
            .simplifiedChinese: "锁定菜单",
            .traditionalChinese: "鎖定選單",
            .english: "Lock Controls",
            .japanese: "メニューを固定"
        ],
        "reader.settings.autoTurn": [
            .simplifiedChinese: "自动翻页",
            .traditionalChinese: "自動翻頁",
            .english: "Auto Turn",
            .japanese: "自動ページ送り"
        ],
        "reader.settings.autoTurn.start": [
            .simplifiedChinese: "开始自动翻页",
            .traditionalChinese: "開始自動翻頁",
            .english: "Start Auto Turn",
            .japanese: "自動ページ送りを開始"
        ],
        "reader.settings.autoTurn.stop": [
            .simplifiedChinese: "停止自动翻页",
            .traditionalChinese: "停止自動翻頁",
            .english: "Stop Auto Turn",
            .japanese: "自動ページ送りを停止"
        ],
        "reader.settings.autoTurn.interval": [
            .simplifiedChinese: "间隔",
            .traditionalChinese: "間隔",
            .english: "Interval",
            .japanese: "間隔"
        ],
        "reader.chapterList": [
            .simplifiedChinese: "章节列表",
            .traditionalChinese: "章節列表",
            .english: "Chapters",
            .japanese: "チャプター"
        ],
        "reader.loading.title": [
            .simplifiedChinese: "正在准备阅读内容",
            .traditionalChinese: "正在準備閱讀內容",
            .english: "Preparing Reader",
            .japanese: "読書内容を準備中"
        ],
        "reader.loading.subtitle": [
            .simplifiedChinese: "网络较慢时你仍然可以直接退出阅读器。",
            .traditionalChinese: "網路較慢時你仍然可以直接離開閱讀器。",
            .english: "You can still close the reader if the network is slow.",
            .japanese: "ネットワークが遅い場合でもリーダーを閉じられます。"
        ],
        "reader.close": [
            .simplifiedChinese: "退出阅读",
            .traditionalChinese: "離開閱讀",
            .english: "Close Reader",
            .japanese: "リーダーを閉じる"
        ],
        "comic.status.finished": [
            .simplifiedChinese: "完结",
            .traditionalChinese: "完結",
            .english: "Finished",
            .japanese: "完結"
        ],
        "detail.title": [
            .simplifiedChinese: "漫画详情",
            .traditionalChinese: "漫畫詳情",
            .english: "Comic Details",
            .japanese: "作品詳細"
        ],
        "detail.loading": [
            .simplifiedChinese: "正在加载漫画详情…",
            .traditionalChinese: "正在載入漫畫詳情…",
            .english: "Loading comic details...",
            .japanese: "作品詳細を読み込み中..."
        ],
        "detail.section.categories": [
            .simplifiedChinese: "分类",
            .traditionalChinese: "分類",
            .english: "Categories",
            .japanese: "カテゴリ"
        ],
        "detail.section.tags": [
            .simplifiedChinese: "标签",
            .traditionalChinese: "標籤",
            .english: "Tags",
            .japanese: "タグ"
        ],
        "detail.badge.pages": [
            .simplifiedChinese: "%dP",
            .traditionalChinese: "%dP",
            .english: "%d pages",
            .japanese: "%dページ"
        ],
        "detail.status.ongoing": [
            .simplifiedChinese: "连载中",
            .traditionalChinese: "連載中",
            .english: "Ongoing",
            .japanese: "連載中"
        ],
        "detail.stats.chapters": [
            .simplifiedChinese: "章节",
            .traditionalChinese: "章節",
            .english: "Chapters",
            .japanese: "チャプター"
        ],
        "detail.stats.comments": [
            .simplifiedChinese: "评论",
            .traditionalChinese: "評論",
            .english: "Comments",
            .japanese: "コメント"
        ],
        "detail.stats.updated": [
            .simplifiedChinese: "更新",
            .traditionalChinese: "更新",
            .english: "Updated",
            .japanese: "更新"
        ],
        "detail.section.info": [
            .simplifiedChinese: "信息",
            .traditionalChinese: "資訊",
            .english: "Info",
            .japanese: "情報"
        ],
        "detail.meta.updated": [
            .simplifiedChinese: "更新 %@",
            .traditionalChinese: "更新 %@",
            .english: "Updated %@",
            .japanese: "更新 %@"
        ],
        "detail.meta.created": [
            .simplifiedChinese: "创建 %@",
            .traditionalChinese: "建立 %@",
            .english: "Created %@",
            .japanese: "作成 %@"
        ],
        "detail.meta.download.enabled": [
            .simplifiedChinese: "可下载",
            .traditionalChinese: "可下載",
            .english: "Downloadable",
            .japanese: "ダウンロード可"
        ],
        "detail.meta.download.disabled": [
            .simplifiedChinese: "不可下载",
            .traditionalChinese: "不可下載",
            .english: "No Download",
            .japanese: "ダウンロード不可"
        ],
        "detail.meta.comment.enabled": [
            .simplifiedChinese: "可评论",
            .traditionalChinese: "可評論",
            .english: "Comments On",
            .japanese: "コメント可"
        ],
        "detail.meta.comment.disabled": [
            .simplifiedChinese: "评论关闭",
            .traditionalChinese: "評論關閉",
            .english: "Comments Off",
            .japanese: "コメント不可"
        ],
        "detail.section.actions": [
            .simplifiedChinese: "操作",
            .traditionalChinese: "操作",
            .english: "Actions",
            .japanese: "操作"
        ],
        "detail.action.like": [
            .simplifiedChinese: "点赞",
            .traditionalChinese: "點讚",
            .english: "Like",
            .japanese: "いいね"
        ],
        "detail.action.liked": [
            .simplifiedChinese: "已点赞",
            .traditionalChinese: "已點讚",
            .english: "Liked",
            .japanese: "いいね済み"
        ],
        "detail.action.favorite": [
            .simplifiedChinese: "收藏",
            .traditionalChinese: "收藏",
            .english: "Favorite",
            .japanese: "お気に入り"
        ],
        "detail.action.favorited": [
            .simplifiedChinese: "已收藏",
            .traditionalChinese: "已收藏",
            .english: "Favorited",
            .japanese: "お気に入り済み"
        ],
        "detail.action.startReading": [
            .simplifiedChinese: "开始阅读",
            .traditionalChinese: "開始閱讀",
            .english: "Start Reading",
            .japanese: "読み始める"
        ],
        "detail.section.progress": [
            .simplifiedChinese: "阅读进度",
            .traditionalChinese: "閱讀進度",
            .english: "Reading Progress",
            .japanese: "読書進捗"
        ],
        "detail.progress.lastRead": [
            .simplifiedChinese: "上次阅读",
            .traditionalChinese: "上次閱讀",
            .english: "Last Read",
            .japanese: "前回の読書"
        ],
        "detail.progress.page": [
            .simplifiedChinese: "第 %d 页",
            .traditionalChinese: "第 %d 頁",
            .english: "Page %d",
            .japanese: "%dページ"
        ],
        "detail.action.continueReading": [
            .simplifiedChinese: "继续阅读",
            .traditionalChinese: "繼續閱讀",
            .english: "Continue Reading",
            .japanese: "続きを読む"
        ],
        "detail.section.chapters": [
            .simplifiedChinese: "目录",
            .traditionalChinese: "目錄",
            .english: "Chapters",
            .japanese: "目次"
        ],
        "detail.chapters.empty": [
            .simplifiedChinese: "暂无章节",
            .traditionalChinese: "暫無章節",
            .english: "No chapters yet",
            .japanese: "チャプターがありません"
        ],
        "detail.chapters.loadFailed": [
            .simplifiedChinese: "章节暂时加载失败",
            .traditionalChinese: "章節暫時載入失敗",
            .english: "Chapters failed to load",
            .japanese: "チャプターの読み込みに失敗しました"
        ],
        "detail.chapters.item": [
            .simplifiedChinese: "第 %d 话",
            .traditionalChinese: "第 %d 話",
            .english: "Episode %d",
            .japanese: "第%d話"
        ],
        "detail.chapters.expand": [
            .simplifiedChinese: "展开全部章节",
            .traditionalChinese: "展開全部章節",
            .english: "Show All Chapters",
            .japanese: "全チャプターを表示"
        ],
        "detail.chapters.collapse": [
            .simplifiedChinese: "收起章节",
            .traditionalChinese: "收合章節",
            .english: "Collapse Chapters",
            .japanese: "チャプターを折りたたむ"
        ],
        "detail.section.description": [
            .simplifiedChinese: "简介",
            .traditionalChinese: "簡介",
            .english: "Description",
            .japanese: "概要"
        ],
        "detail.description.empty": [
            .simplifiedChinese: "暂无简介",
            .traditionalChinese: "暫無簡介",
            .english: "No description yet",
            .japanese: "説明はまだありません"
        ],
        "detail.section.recommendations": [
            .simplifiedChinese: "相关推荐",
            .traditionalChinese: "相關推薦",
            .english: "Recommendations",
            .japanese: "おすすめ"
        ],
        "detail.recommendations.empty": [
            .simplifiedChinese: "暂时没有相关推荐",
            .traditionalChinese: "暫時沒有相關推薦",
            .english: "No recommendations for now",
            .japanese: "現在はおすすめがありません"
        ],
        "detail.sort.ascending": [
            .simplifiedChinese: "旧到新",
            .traditionalChinese: "舊到新",
            .english: "Oldest First",
            .japanese: "古い順"
        ],
        "detail.sort.descending": [
            .simplifiedChinese: "新到旧",
            .traditionalChinese: "新到舊",
            .english: "Newest First",
            .japanese: "新しい順"
        ],
        "data.unknownAuthor": [
            .simplifiedChinese: "未知作者",
            .traditionalChinese: "未知作者",
            .english: "Unknown Author",
            .japanese: "不明な作者"
        ],
        "data.untitledComic": [
            .simplifiedChinese: "未命名漫画",
            .traditionalChinese: "未命名漫畫",
            .english: "Untitled Comic",
            .japanese: "無題のマンガ"
        ],
        "data.untitledChapter": [
            .simplifiedChinese: "未命名章节",
            .traditionalChinese: "未命名章節",
            .english: "Untitled Chapter",
            .japanese: "無題のチャプター"
        ],
        "data.novice": [
            .simplifiedChinese: "萌新",
            .traditionalChinese: "萌新",
            .english: "Newbie",
            .japanese: "初心者"
        ]
    ]
}
