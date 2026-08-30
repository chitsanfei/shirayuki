import Foundation
import Combine

/// Languages supported by the in-process localization catalog.
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

/// Resolves localized strings and publishes the selected app language.
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
        "rank.daily": [
            .simplifiedChinese: "日榜",
            .traditionalChinese: "日榜",
            .english: "Daily",
            .japanese: "日間"
        ],
        "rank.weekly": [
            .simplifiedChinese: "周榜",
            .traditionalChinese: "周榜",
            .english: "Weekly",
            .japanese: "週間"
        ],
        "rank.monthly": [
            .simplifiedChinese: "月榜",
            .traditionalChinese: "月榜",
            .english: "Monthly",
            .japanese: "月間"
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
            .simplifiedChinese: "主题、储存与应用信息",
            .traditionalChinese: "主題、儲存與應用程式資訊",
            .english: "Theme, storage, and app info.",
            .japanese: "テーマ、ストレージ、アプリ情報"
        ],
        "profile.offline": [
            .simplifiedChinese: "离线漫画",
            .traditionalChinese: "離線漫畫",
            .english: "Offline Comics",
            .japanese: "オフライン漫画"
        ],
        "profile.offline.subtitle": [
            .simplifiedChinese: "管理已下载的漫画",
            .traditionalChinese: "管理已下載的漫畫",
            .english: "Manage downloaded comics",
            .japanese: "ダウンロード済み漫画を管理"
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
        "settings.appearance.subtitle": [
            .simplifiedChinese: "主题与语言",
            .traditionalChinese: "主題與語言",
            .english: "Theme and language",
            .japanese: "テーマと言語"
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
        "settings.reading": [
            .simplifiedChinese: "阅读设置",
            .traditionalChinese: "閱讀設定",
            .english: "Reading",
            .japanese: "読書設定"
        ],
        "settings.reading.subtitle": [
            .simplifiedChinese: "方向、显示与自动翻页",
            .traditionalChinese: "方向、顯示與自動翻頁",
            .english: "Direction, display, and auto-turn",
            .japanese: "方向、表示、自動ページ送り"
        ],
        "settings.network": [
            .simplifiedChinese: "网络线路",
            .traditionalChinese: "網路線路",
            .english: "Network Route",
            .japanese: "ネットワーク経路"
        ],
        "settings.network.subtitle": [
            .simplifiedChinese: "选择 API 线路或管理自定义线路",
            .traditionalChinese: "選擇 API 線路或管理自訂線路",
            .english: "Choose an API route or manage custom routes",
            .japanese: "API経路の選択とカスタム経路の管理"
        ],
        "settings.network.selection": [
            .simplifiedChinese: "线路选择",
            .traditionalChinese: "線路選擇",
            .english: "Route Selection",
            .japanese: "経路の選択"
        ],
        "settings.network.selection.subtitle": [
            .simplifiedChinese: "选择当前使用的网络线路",
            .traditionalChinese: "選擇目前使用的網路線路",
            .english: "Choose the active network route",
            .japanese: "使用するネットワーク経路を選択"
        ],
        "settings.network.modify": [
            .simplifiedChinese: "自定义线路",
            .traditionalChinese: "自訂線路",
            .english: "Custom Routes",
            .japanese: "カスタム経路"
        ],
        "settings.network.modify.subtitle": [
            .simplifiedChinese: "添加或编辑兼容 PicACG 的 API 地址",
            .traditionalChinese: "新增或編輯相容 PicACG 的 API 位址",
            .english: "Add or edit a PicACG-compatible API URL",
            .japanese: "PicACG互換API URLを追加または編集"
        ],
        "settings.proxy.name": [
            .simplifiedChinese: "线路名称",
            .traditionalChinese: "線路名稱",
            .english: "Route Name",
            .japanese: "経路名"
        ],
        "settings.proxy.url": [
            .simplifiedChinese: "API 基础地址",
            .traditionalChinese: "API 基礎位址",
            .english: "API Base URL",
            .japanese: "APIベースURL"
        ],
        "settings.proxy.add": [
            .simplifiedChinese: "添加自定义线路",
            .traditionalChinese: "新增自訂線路",
            .english: "Add Custom Route",
            .japanese: "カスタム経路を追加"
        ],
        "settings.proxy.save": [
            .simplifiedChinese: "保存线路",
            .traditionalChinese: "儲存線路",
            .english: "Save Route",
            .japanese: "経路を保存"
        ],
        "settings.proxy.invalid": [
            .simplifiedChinese: "请输入线路名称和有效的 HTTP/HTTPS API 地址。",
            .traditionalChinese: "請輸入線路名稱與有效的 HTTP/HTTPS API 位址。",
            .english: "Enter a route name and a valid HTTP/HTTPS API URL.",
            .japanese: "経路名と有効なHTTP/HTTPS API URLを入力してください。"
        ],
        "settings.rank.title": [
            .simplifiedChinese: "卡片",
            .traditionalChinese: "卡片",
            .english: "Cards",
            .japanese: "カード"
        ],
        "settings.rank.subtitle": [
            .simplifiedChinese: "榜单卡片显示的分类与标签",
            .traditionalChinese: "榜單卡片顯示的分類與標籤",
            .english: "Categories and tags shown on ranking cards",
            .japanese: "ランキングカードに表示するカテゴリとタグ"
        ],
        "settings.rank.display": [
            .simplifiedChinese: "信息类型",
            .traditionalChinese: "資訊類型",
            .english: "Metadata",
            .japanese: "メタデータ"
        ],
        "settings.rank.display.categories": [
            .simplifiedChinese: "分类",
            .traditionalChinese: "分類",
            .english: "Categories",
            .japanese: "カテゴリ"
        ],
        "settings.rank.display.tags": [
            .simplifiedChinese: "标签",
            .traditionalChinese: "標籤",
            .english: "Tags",
            .japanese: "タグ"
        ],
        "settings.rank.maxCount": [
            .simplifiedChinese: "最多显示数量",
            .traditionalChinese: "最多顯示數量",
            .english: "Maximum Items",
            .japanese: "最大表示数"
        ],
        "settings.cache": [
            .simplifiedChinese: "储存",
            .traditionalChinese: "儲存",
            .english: "Storage",
            .japanese: "ストレージ"
        ],
        "settings.cache.subtitle": [
            .simplifiedChinese: "清理已缓存的漫画图片",
            .traditionalChinese: "清除已快取的漫畫圖片",
            .english: "Clear cached comic images",
            .japanese: "キャッシュ済みの漫画画像を削除"
        ],
        "settings.storage.cache": [
            .simplifiedChinese: "图片缓存",
            .traditionalChinese: "圖片快取",
            .english: "Image Cache",
            .japanese: "画像キャッシュ"
        ],
        "settings.storage.offline": [
            .simplifiedChinese: "离线漫画",
            .traditionalChinese: "離線漫畫",
            .english: "Offline Comics",
            .japanese: "オフライン漫画"
        ],
        "settings.storage.offline.manage": [
            .simplifiedChinese: "管理离线漫画",
            .traditionalChinese: "管理離線漫畫",
            .english: "Manage Offline Comics",
            .japanese: "オフライン漫画を管理"
        ],
        "settings.storage.offline.clear": [
            .simplifiedChinese: "清理离线漫画",
            .traditionalChinese: "清理離線漫畫",
            .english: "Delete Offline Comics",
            .japanese: "オフライン漫画を削除"
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
        "settings.source.subtitle": [
            .simplifiedChinese: "仓库、许可与第三方说明",
            .traditionalChinese: "倉庫、授權與第三方說明",
            .english: "Repository, license, and third-party notices",
            .japanese: "リポジトリ、ライセンス、第三者通知"
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
        "settings.about.subtitle": [
            .simplifiedChinese: "版本与运行环境",
            .traditionalChinese: "版本與執行環境",
            .english: "Version and runtime environment",
            .japanese: "バージョンと実行環境"
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
        "agent.button.open": [
            .simplifiedChinese: "打开 Agent",
            .traditionalChinese: "開啟 Agent",
            .english: "Open Agent",
            .japanese: "Agentを開く"
        ],
        "agent.input.placeholder": [
            .simplifiedChinese: "输入消息…",
            .traditionalChinese: "輸入訊息…",
            .english: "Enter a message…",
            .japanese: "メッセージを入力…"
        ],
        "agent.send": [
            .simplifiedChinese: "发送",
            .traditionalChinese: "傳送",
            .english: "Send",
            .japanese: "送信"
        ],
        "agent.stop": [
            .simplifiedChinese: "停止生成",
            .traditionalChinese: "停止生成",
            .english: "Stop Generating",
            .japanese: "生成を停止"
        ],
        "agent.close": [
            .simplifiedChinese: "关闭 Agent",
            .traditionalChinese: "關閉 Agent",
            .english: "Close Agent",
            .japanese: "Agentを閉じる"
        ],
        "agent.loading": [
            .simplifiedChinese: "正在生成…",
            .traditionalChinese: "正在生成…",
            .english: "Generating…",
            .japanese: "生成中…"
        ],
        "agent.state.loginRequired": [
            .simplifiedChinese: "请先登录后使用此功能。",
            .traditionalChinese: "請先登入後使用此功能。",
            .english: "Sign in to use this capability.",
            .japanese: "この機能を使用するにはログインしてください。"
        ],
        "agent.state.configurationRequired": [
            .simplifiedChinese: "请先在设置中配置 Agent。",
            .traditionalChinese: "請先在設定中設定 Agent。",
            .english: "Configure Agent in Settings first.",
            .japanese: "先に設定でAgentを構成してください。"
        ],
        "agent.state.capabilityUnavailable": [
            .simplifiedChinese: "当前功能不可用。",
            .traditionalChinese: "目前功能無法使用。",
            .english: "This capability is unavailable.",
            .japanese: "この機能は現在利用できません。"
        ],
        "agent.state.error": [
            .simplifiedChinese: "Agent 请求失败。",
            .traditionalChinese: "Agent 請求失敗。",
            .english: "The Agent request failed.",
            .japanese: "Agentのリクエストに失敗しました。"
        ],
        "agent.tool.search": [
            .simplifiedChinese: "搜索漫画",
            .traditionalChinese: "搜尋漫畫",
            .english: "Search Comics",
            .japanese: "漫画を検索"
        ],
        "agent.tool.open": [
            .simplifiedChinese: "打开漫画",
            .traditionalChinese: "開啟漫畫",
            .english: "Open Comic",
            .japanese: "漫画を開く"
        ],
        "agent.tool.readerPage": [
            .simplifiedChinese: "跳转阅读页",
            .traditionalChinese: "跳轉閱讀頁",
            .english: "Go to Reader Page",
            .japanese: "閲覧ページへ移動"
        ],
        "agent.tool.readerChapter": [
            .simplifiedChinese: "跳转章节",
            .traditionalChinese: "跳轉章節",
            .english: "Go to Chapter",
            .japanese: "章へ移動"
        ],
        "agent.tool.currentPage": [
            .simplifiedChinese: "读取当前页",
            .traditionalChinese: "讀取目前頁面",
            .english: "Read Current Page",
            .japanese: "現在のページを読み取る"
        ],
        "agent.tool.download": [
            .simplifiedChinese: "下载漫画",
            .traditionalChinese: "下載漫畫",
            .english: "Download Comic",
            .japanese: "漫画をダウンロード"
        ],
        "agent.tool.cancelDownload": [
            .simplifiedChinese: "取消下载",
            .traditionalChinese: "取消下載",
            .english: "Cancel Download",
            .japanese: "ダウンロードをキャンセル"
        ],
        "agent.context.current": [
            .simplifiedChinese: "当前页面",
            .traditionalChinese: "目前頁面",
            .english: "Current Context",
            .japanese: "現在のコンテキスト"
        ],
        "agent.context.user": [
            .simplifiedChinese: "用户资料",
            .traditionalChinese: "使用者資料",
            .english: "User Profile",
            .japanese: "ユーザープロフィール"
        ],
        "agent.context.favorites": [
            .simplifiedChinese: "收藏",
            .traditionalChinese: "收藏",
            .english: "Favorites",
            .japanese: "お気に入り"
        ],
        "agent.context.offlineLibrary": [
            .simplifiedChinese: "离线漫画库",
            .traditionalChinese: "離線漫畫庫",
            .english: "Offline Library",
            .japanese: "オフラインライブラリ"
        ],
        "agent.download.status": [
            .simplifiedChinese: "下载状态",
            .traditionalChinese: "下載狀態",
            .english: "Download Status",
            .japanese: "ダウンロード状況"
        ],
        "agent.download.queued": [
            .simplifiedChinese: "等待下载",
            .traditionalChinese: "等待下載",
            .english: "Queued",
            .japanese: "待機中"
        ],
        "agent.download.inProgress": [
            .simplifiedChinese: "正在下载",
            .traditionalChinese: "正在下載",
            .english: "Downloading",
            .japanese: "ダウンロード中"
        ],
        "agent.download.completed": [
            .simplifiedChinese: "下载完成",
            .traditionalChinese: "下載完成",
            .english: "Download Complete",
            .japanese: "ダウンロード完了"
        ],
        "agent.download.failed": [
            .simplifiedChinese: "下载失败",
            .traditionalChinese: "下載失敗",
            .english: "Download Failed",
            .japanese: "ダウンロード失敗"
        ],
        "agent.download.cancelled": [
            .simplifiedChinese: "下载已取消",
            .traditionalChinese: "下載已取消",
            .english: "Download Cancelled",
            .japanese: "ダウンロードをキャンセルしました"
        ],
        "agent.confirm.title": [
            .simplifiedChinese: "确认操作",
            .traditionalChinese: "確認操作",
            .english: "Confirm Action",
            .japanese: "操作を確認"
        ],
        "agent.confirm.action": [
            .simplifiedChinese: "确认",
            .traditionalChinese: "確認",
            .english: "Confirm",
            .japanese: "確認"
        ],
        "agent.confirm.like": [
            .simplifiedChinese: "确认点赞",
            .traditionalChinese: "確認點讚",
            .english: "Confirm Like",
            .japanese: "いいねを確認"
        ],
        "agent.confirm.favorite": [
            .simplifiedChinese: "确认收藏",
            .traditionalChinese: "確認收藏",
            .english: "Confirm Favorite",
            .japanese: "お気に入り登録を確認"
        ],
        "agent.confirm.cancelDownload": [
            .simplifiedChinese: "确认取消下载",
            .traditionalChinese: "確認取消下載",
            .english: "Confirm Download Cancellation",
            .japanese: "ダウンロードのキャンセルを確認"
        ],
        "agent.confirm.currentPage": [
            .simplifiedChinese: "确认发送当前页",
            .traditionalChinese: "確認傳送目前頁面",
            .english: "Confirm Current Page",
            .japanese: "現在のページ送信を確認"
        ],
        "agent.confirm.currentPage.provider": [
            .simplifiedChinese: "服务主机：%@",
            .traditionalChinese: "服務主機：%@",
            .english: "Provider host: %@",
            .japanese: "プロバイダーホスト：%@"
        ],
        "agent.confirm.currentPage.warning": [
            .simplifiedChinese: "当前阅读页图片将发送到此主机。",
            .traditionalChinese: "目前閱讀頁面圖片將傳送至此主機。",
            .english: "The current reading-page image will be sent to this host.",
            .japanese: "現在の閲覧ページ画像がこのホストへ送信されます。"
        ],
        "agent.confirm.download.comic": [
            .simplifiedChinese: "漫画：%@",
            .traditionalChinese: "漫畫：%@",
            .english: "Comic: %@",
            .japanese: "漫画：%@"
        ],
        "agent.confirm.download.chapters": [
            .simplifiedChinese: "章节（%d）：%@",
            .traditionalChinese: "章節（%d）：%@",
            .english: "Chapters (%d): %@",
            .japanese: "章（%d）：%@"
        ],
        "agent.confirm.download.quality": [
            .simplifiedChinese: "图片质量：%@",
            .traditionalChinese: "圖片品質：%@",
            .english: "Image quality: %@",
            .japanese: "画像品質：%@"
        ],
        "agent.confirm.download.pages": [
            .simplifiedChinese: "预计图片：%d 张",
            .traditionalChinese: "預計圖片：%d 張",
            .english: "Estimated images: %d",
            .japanese: "推定画像数：%d"
        ],
        "agent.confirm.cancel.details": [
            .simplifiedChinese: "%@ · %d/%d 张图片 · %@",
            .traditionalChinese: "%@ · %d/%d 張圖片 · %@",
            .english: "%@ · %d/%d images · %@",
            .japanese: "%@ · %d/%d枚 · %@"
        ],
        "agent.confirm.desired.details": [
            .simplifiedChinese: "%@ · %@：%@",
            .traditionalChinese: "%@ · %@：%@",
            .english: "%@ · %@: %@",
            .japanese: "%@ · %@：%@"
        ],
        "agent.confirm.enabled": [
            .simplifiedChinese: "开启",
            .traditionalChinese: "開啟",
            .english: "On",
            .japanese: "オン"
        ],
        "agent.confirm.disabled": [
            .simplifiedChinese: "关闭",
            .traditionalChinese: "關閉",
            .english: "Off",
            .japanese: "オフ"
        ],
        "agent.state.visionUnsupported": [
            .simplifiedChinese: "当前模型不支持读取图片；请在设置中选择支持视觉的模型。",
            .traditionalChinese: "目前模型不支援讀取圖片；請在設定中選擇支援視覺的模型。",
            .english: "The selected model cannot read images. Choose a vision-capable model in Settings.",
            .japanese: "選択したモデルは画像を読み取れません。設定で画像対応モデルを選択してください。"
        ],
        "startup.preparing": [
            .simplifiedChinese: "准备中",
            .traditionalChinese: "準備中",
            .english: "Preparing",
            .japanese: "準備中"
        ],
        "startup.validatingSession": [
            .simplifiedChinese: "正在验证会话",
            .traditionalChinese: "正在驗證工作階段",
            .english: "Validating Session",
            .japanese: "セッションを確認中"
        ],
        "startup.restoringCredentials": [
            .simplifiedChinese: "正在恢复登录凭据",
            .traditionalChinese: "正在恢復登入憑證",
            .english: "Restoring Credentials",
            .japanese: "ログイン情報を復元中"
        ],
        "startup.loadingProfile": [
            .simplifiedChinese: "正在加载用户资料",
            .traditionalChinese: "正在載入使用者資料",
            .english: "Loading Profile",
            .japanese: "プロフィールを読み込み中"
        ],
        "startup.failed": [
            .simplifiedChinese: "启动失败",
            .traditionalChinese: "啟動失敗",
            .english: "Startup Failed",
            .japanese: "起動に失敗しました"
        ],
        "startup.retry": [
            .simplifiedChinese: "重试",
            .traditionalChinese: "重試",
            .english: "Retry",
            .japanese: "再試行"
        ],
        "startup.login": [
            .simplifiedChinese: "前往登录",
            .traditionalChinese: "前往登入",
            .english: "Go to Login",
            .japanese: "ログインへ"
        ],
        "settings.agent": [
            .simplifiedChinese: "Agent",
            .traditionalChinese: "Agent",
            .english: "Agent",
            .japanese: "Agent"
        ],
        "settings.agent.subtitle": [
            .simplifiedChinese: "配置模型、API 密钥和服务地址",
            .traditionalChinese: "設定模型、API 金鑰和服務位址",
            .english: "Configure the model, API key, and endpoint",
            .japanese: "モデル、APIキー、接続先を設定"
        ],
        "settings.agent.provider": [
            .simplifiedChinese: "Provider",
            .traditionalChinese: "Provider",
            .english: "Provider",
            .japanese: "プロバイダー"
        ],
        "settings.agent.provider.openAICompatible": [
            .simplifiedChinese: "OpenAI 兼容",
            .traditionalChinese: "OpenAI 相容",
            .english: "OpenAI-Compatible",
            .japanese: "OpenAI互換"
        ],
        "settings.agent.providerFormat": [
            .simplifiedChinese: "Provider 格式",
            .traditionalChinese: "Provider 格式",
            .english: "Provider Format",
            .japanese: "プロバイダー形式"
        ],
        "settings.agent.provider.anthropicCompatible": [
            .simplifiedChinese: "Anthropic 兼容",
            .traditionalChinese: "Anthropic 相容",
            .english: "Anthropic-Compatible",
            .japanese: "Anthropic互換"
        ],
        "settings.agent.applied": [
            .simplifiedChinese: "Agent 配置已应用",
            .traditionalChinese: "Agent 設定已套用",
            .english: "Agent configuration applied",
            .japanese: "Agent設定を適用しました"
        ],
        "settings.agent.cleared": [
            .simplifiedChinese: "当前 API 密钥已清除",
            .traditionalChinese: "目前 API 金鑰已清除",
            .english: "Current API key cleared",
            .japanese: "現在のAPIキーを消去しました"
        ],
        "settings.agent.clearToken": [
            .simplifiedChinese: "清除 token",
            .traditionalChinese: "清除 token",
            .english: "Clear Token",
            .japanese: "トークンを消去"
        ],
        "settings.agent.clearToken.confirm": [
            .simplifiedChinese: "确认清除当前 Provider 保存的 API token？",
            .traditionalChinese: "確認清除目前 Provider 儲存的 API token？",
            .english: "Clear the API token saved for the current provider?",
            .japanese: "現在のProviderに保存されたAPIトークンを消去しますか？"
        ],
        "settings.agent.clearToken.error": [
            .simplifiedChinese: "无法清除 API token",
            .traditionalChinese: "無法清除 API token",
            .english: "Could not clear the API token",
            .japanese: "APIトークンを消去できません"
        ],
        "settings.agent.reset": [
            .simplifiedChinese: "重置为默认配置",
            .traditionalChinese: "重設為預設設定",
            .english: "Reset to Defaults",
            .japanese: "既定値にリセット"
        ],
        "settings.agent.reset.confirm": [
            .simplifiedChinese: "确认重置 Provider、模型、Endpoint 和 Agent 行为设置？保存的 API token 不会被清除。",
            .traditionalChinese: "確認重設 Provider、模型、Endpoint 與 Agent 行為設定？已儲存的 API token 不會被清除。",
            .english: "Reset provider, model, endpoint, and Agent behavior settings? Saved API tokens are not cleared.",
            .japanese: "Provider、モデル、Endpoint、Agent動作設定をリセットしますか？保存済みAPIトークンは消去されません。"
        ],
        "settings.agent.action.error": [
            .simplifiedChinese: "操作失败",
            .traditionalChinese: "操作失敗",
            .english: "Action failed",
            .japanese: "操作に失敗しました"
        ],
        "settings.agent.resetDone": [
            .simplifiedChinese: "已重置为默认配置",
            .traditionalChinese: "已重設為預設設定",
            .english: "Reset to defaults",
            .japanese: "既定値にリセットしました"
        ],
        "settings.agent.executionMode": [
            .simplifiedChinese: "Agent 模式",
            .traditionalChinese: "Agent 模式",
            .english: "Agent Mode",
            .japanese: "Agentモード"
        ],
        "settings.agent.executionMode.ask": [
            .simplifiedChinese: "Ask（操作前确认）",
            .traditionalChinese: "Ask（操作前確認）",
            .english: "Ask (confirm actions)",
            .japanese: "Ask（操作前に確認）"
        ],
        "settings.agent.executionMode.yolo": [
            .simplifiedChinese: "YOLO（自动执行）",
            .traditionalChinese: "YOLO（自動執行）",
            .english: "YOLO (auto-execute)",
            .japanese: "YOLO（自動実行）"
        ],
        "settings.agent.executionMode.yoloWarning": [
            .simplifiedChinese: "YOLO 会自动执行下载、点赞、收藏和屏蔽词修改；发送当前阅读页图片仍需确认。",
            .traditionalChinese: "YOLO 會自動執行下載、按讚、收藏與封鎖詞修改；傳送目前閱讀頁圖片仍需確認。",
            .english: "YOLO auto-executes downloads, likes, favorites, and blocked-word changes. Sending the current page image still requires confirmation.",
            .japanese: "YOLOはダウンロード、いいね、お気に入り、ブロックワード変更を自動実行します。現在ページの画像送信は引き続き確認が必要です。"
        ],
        "settings.agent.riskAuthorization": [
            .simplifiedChinese: "授权 Agent 对风险权限控制",
            .traditionalChinese: "授權 Agent 控制風險權限",
            .english: "Authorize Agent Risk Controls",
            .japanese: "Agentのリスク権限制御を許可"
        ],
        "settings.agent.riskAuthorization.footer": [
            .simplifiedChinese: "允许 Agent 请求修改屏蔽词/只选词、收藏状态，以及取消或删除已下载漫画。Ask 模式仍会逐次确认。",
            .traditionalChinese: "允許 Agent 請求修改封鎖詞/只選詞、收藏狀態，以及取消或刪除已下載漫畫。Ask 模式仍會逐次確認。",
            .english: "Allows Agent to request filter-word and favorite changes, and cancel or delete downloads. Ask mode still confirms each action.",
            .japanese: "フィルターワードやお気に入りの変更、ダウンロードの取消・削除をAgentに許可します。Askモードでは各操作を確認します。"
        ],
        "agent.state.risk_authorization_required": [
            .simplifiedChinese: "设置中未授权 Agent 风险权限控制",
            .traditionalChinese: "設定中未授權 Agent 風險權限制御",
            .english: "Agent risk controls are not authorized in Settings",
            .japanese: "設定でAgentのリスク権限制御が許可されていません"
        ],
        "settings.agent.toolCallLimit": [
            .simplifiedChinese: "每轮 Tool Call 上限",
            .traditionalChinese: "每輪 Tool Call 上限",
            .english: "Tool Calls per Turn",
            .japanese: "ターンごとのTool Call上限"
        ],
        "settings.agent.toolCallLimit.footer": [
            .simplifiedChinese: "默认 10，最大 20。达到上限前 2 次时，Agent 会被要求基于已有信息直接回复。",
            .traditionalChinese: "預設 10，最大 20。達到上限前 2 次時，Agent 會被要求依現有資訊直接回覆。",
            .english: "Default 10, maximum 20. With 2 calls remaining, Agent is instructed to answer directly from gathered information.",
            .japanese: "既定値は10、最大20です。残り2回になると、収集済み情報から直接回答するようAgentへ指示します。"
        ],
        "settings.agent.compaction": [
            .simplifiedChinese: "上下文",
            .traditionalChinese: "上下文",
            .english: "Context",
            .japanese: "コンテキスト"
        ],
        "settings.agent.compaction.auto": [
            .simplifiedChinese: "自动压缩上下文",
            .traditionalChinese: "自動壓縮上下文",
            .english: "Auto Compact Context",
            .japanese: "コンテキストを自動圧縮"
        ],
        "settings.agent.compaction.threshold": [
            .simplifiedChinese: "压缩阈值",
            .traditionalChinese: "壓縮閾值",
            .english: "Compaction Threshold",
            .japanese: "圧縮しきい値"
        ],
        "settings.agent.compaction.footer": [
            .simplifiedChinese: "达到阈值后，Agent 会总结较早的完整对话，只把摘要和最近 4 轮发送给模型。压缩本身不删除本地历史；历史仍受每会话 512 KiB 上限约束。",
            .traditionalChinese: "達到閾值後，Agent 會總結較早的完整對話，只把摘要與最近 4 輪傳送給模型。壓縮本身不刪除本機歷史；歷史仍受每會話 512 KiB 上限約束。",
            .english: "At the threshold, Agent summarizes older complete turns and sends only that summary plus the latest 4 turns. Compaction does not delete local history; the 512 KiB per-session limit still applies.",
            .japanese: "しきい値に達すると古い完了ターンを要約し、要約と直近4ターンだけをモデルへ送信します。圧縮自体はローカル履歴を削除しませんが、セッションごとの512 KiB上限は適用されます。"
        ],
        "settings.agent.apiKey": [
            .simplifiedChinese: "API 密钥",
            .traditionalChinese: "API 金鑰",
            .english: "API Key",
            .japanese: "APIキー"
        ],
        "settings.agent.model": [
            .simplifiedChinese: "模型",
            .traditionalChinese: "模型",
            .english: "Model",
            .japanese: "モデル"
        ],
        "settings.agent.baseURL": [
            .simplifiedChinese: "Base URL",
            .traditionalChinese: "Base URL",
            .english: "Base URL",
            .japanese: "ベースURL"
        ],
        "settings.agent.customHostPrivacy": [
            .simplifiedChinese: "当前页面、漫画库和阅读内容可能会发送到此服务地址。请确认你信任该服务。",
            .traditionalChinese: "目前頁面、漫畫庫和閱讀內容可能會傳送到此服務位址。請確認你信任該服務。",
            .english: "The current page, library, and reading content may be sent to this endpoint. Confirm that you trust it.",
            .japanese: "現在のページ、ライブラリ、閲覧内容がこの接続先へ送信される場合があります。信頼できることを確認してください。"
        ],
        "settings.agent.customHost": [
            .simplifiedChinese: "主机：%@",
            .traditionalChinese: "主機：%@",
            .english: "Host: %@",
            .japanese: "ホスト：%@"
        ],
        "settings.agent.confirmCustomHost": [
            .simplifiedChinese: "我信任此服务地址",
            .traditionalChinese: "我信任此服務位址",
            .english: "I Trust This Endpoint",
            .japanese: "この接続先を信頼する"
        ],
        "agent.accessibility.dragHint": [
            .simplifiedChinese: "拖动可移动按钮位置。",
            .traditionalChinese: "拖曳可移動按鈕位置。",
            .english: "Drag to move the button.",
            .japanese: "ドラッグしてボタンを移動できます。"
        ],
        "agent.accessibility.moveLeft": [
            .simplifiedChinese: "移至左侧",
            .traditionalChinese: "移至左側",
            .english: "Move left",
            .japanese: "左へ移動"
        ],
        "agent.accessibility.moveRight": [
            .simplifiedChinese: "移至右侧",
            .traditionalChinese: "移至右側",
            .english: "Move right",
            .japanese: "右へ移動"
        ],
        "agent.accessibility.moveUp": [
            .simplifiedChinese: "移至上方",
            .traditionalChinese: "移至上方",
            .english: "Move up",
            .japanese: "上へ移動"
        ],
        "agent.accessibility.moveDown": [
            .simplifiedChinese: "移至下方",
            .traditionalChinese: "移至下方",
            .english: "Move down",
            .japanese: "下へ移動"
        ],
        "agent.accessibility.resetPosition": [
            .simplifiedChinese: "重置按钮位置",
            .traditionalChinese: "重設按鈕位置",
            .english: "Reset button position",
            .japanese: "ボタン位置をリセット"
        ],
        "agent.accessibility.progress": [
            .simplifiedChinese: "进度：%d%%",
            .traditionalChinese: "進度：%d%%",
            .english: "Progress: %d%%",
            .japanese: "進捗：%d%%"
        ],
        "agent.accessibility.error": [
            .simplifiedChinese: "错误：%@",
            .traditionalChinese: "錯誤：%@",
            .english: "Error: %@",
            .japanese: "エラー：%@"
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
        "reader.settings.offline": [
            .simplifiedChinese: "离线阅读",
            .traditionalChinese: "離線閱讀",
            .english: "Offline Reading",
            .japanese: "オフライン読書"
        ],
        "reader.settings.ignoreOffline": [
            .simplifiedChinese: "忽略离线漫画",
            .traditionalChinese: "忽略離線漫畫",
            .english: "Ignore Offline Comics",
            .japanese: "オフライン漫画を無視"
        ],
        "reader.settings.downloadWhileReading": [
            .simplifiedChinese: "边读边下",
            .traditionalChinese: "邊讀邊下載",
            .english: "Download While Reading",
            .japanese: "読みながらダウンロード"
        ],
        "reader.offline.using": [
            .simplifiedChinese: "已加载离线版本",
            .traditionalChinese: "已載入離線版本",
            .english: "Loaded offline version",
            .japanese: "オフライン版を読み込みました"
        ],
        "reader.offline.usingOnline": [
            .simplifiedChinese: "离线版本质量不足，已加载在线版本",
            .traditionalChinese: "離線版本品質不足，已載入線上版本",
            .english: "Offline quality is insufficient; loaded online version",
            .japanese: "オフライン版の品質不足のためオンライン版を読み込みました"
        ],
        "reader.chapterList": [
            .simplifiedChinese: "章节列表",
            .traditionalChinese: "章節列表",
            .english: "Chapters",
            .japanese: "チャプター"
        ],
        "reader.chapter.onlineOnly": [
            .simplifiedChinese: "在线章节",
            .traditionalChinese: "線上章節",
            .english: "Online chapter",
            .japanese: "オンラインチャプター"
        ],
        "reader.chapter.downloaded": [
            .simplifiedChinese: "已下载",
            .traditionalChinese: "已下載",
            .english: "Downloaded",
            .japanese: "ダウンロード済み"
        ],
        "reader.chapter.downloading": [
            .simplifiedChinese: "正在下载",
            .traditionalChinese: "正在下載",
            .english: "Downloading",
            .japanese: "ダウンロード中"
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
        "detail.stats.created": [
            .simplifiedChinese: "创建",
            .traditionalChinese: "建立",
            .english: "Created",
            .japanese: "作成"
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
        "detail.action.download": [
            .simplifiedChinese: "下载漫画",
            .traditionalChinese: "下載漫畫",
            .english: "Download",
            .japanese: "漫画をダウンロード"
        ],
        "detail.action.downloaded": [
            .simplifiedChinese: "已下载",
            .traditionalChinese: "已下載",
            .english: "Downloaded",
            .japanese: "ダウンロード済み"
        ],
        "detail.download.quality": [
            .simplifiedChinese: "下载图片质量",
            .traditionalChinese: "下載圖片品質",
            .english: "Download Image Quality",
            .japanese: "ダウンロード画質"
        ],
        "detail.download.chapters": [
            .simplifiedChinese: "选择章节",
            .traditionalChinese: "選擇章節",
            .english: "Select Chapters",
            .japanese: "チャプターを選択"
        ],
        "detail.download.selectAll": [
            .simplifiedChinese: "全选",
            .traditionalChinese: "全選",
            .english: "Select All",
            .japanese: "すべて選択"
        ],
        "detail.download.deselectAll": [
            .simplifiedChinese: "取消全选",
            .traditionalChinese: "取消全選",
            .english: "Deselect All",
            .japanese: "すべて解除"
        ],
        "detail.download.selected": [
            .simplifiedChinese: "已选择 %d/%d 话",
            .traditionalChinese: "已選擇 %d/%d 話",
            .english: "%d/%d chapters selected",
            .japanese: "%d/%d話を選択中"
        ],
        "detail.download.confirm": [
            .simplifiedChinese: "确认下载",
            .traditionalChinese: "確認下載",
            .english: "Confirm Download",
            .japanese: "ダウンロードを確認"
        ],
        "detail.download.progress": [
            .simplifiedChinese: "已下载 %d/%d 张图片",
            .traditionalChinese: "已下載 %d/%d 張圖片",
            .english: "%d/%d images downloaded",
            .japanese: "%d/%d枚をダウンロード済み"
        ],
        "detail.download.preparing": [
            .simplifiedChinese: "正在准备下载",
            .traditionalChinese: "正在準備下載",
            .english: "Preparing download",
            .japanese: "ダウンロードを準備中"
        ],
        "detail.download.confirm.title": [
            .simplifiedChinese: "确认下载整部漫画？",
            .traditionalChinese: "確認下載整部漫畫？",
            .english: "Download the entire comic?",
            .japanese: "漫画全体をダウンロードしますか？"
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
        ],
        "settings.imageQuality": [
            .simplifiedChinese: "图片质量",
            .traditionalChinese: "圖片品質",
            .english: "Image Quality",
            .japanese: "画像品質"
        ],
        "reader.settings.imageQuality": [
            .simplifiedChinese: "图片质量",
            .traditionalChinese: "圖片品質",
            .english: "Image Quality",
            .japanese: "画像品質"
        ],
        "reader.settings.imageQuality.label": [
            .simplifiedChinese: "清晰度",
            .traditionalChinese: "清晰度",
            .english: "Quality",
            .japanese: "画質"
        ],
        "imageQuality.low": [
            .simplifiedChinese: "低",
            .traditionalChinese: "低",
            .english: "Low",
            .japanese: "低"
        ],
        "imageQuality.medium": [
            .simplifiedChinese: "中",
            .traditionalChinese: "中",
            .english: "Medium",
            .japanese: "中"
        ],
        "imageQuality.high": [
            .simplifiedChinese: "高",
            .traditionalChinese: "高",
            .english: "High",
            .japanese: "高"
        ],
        "imageQuality.original": [
            .simplifiedChinese: "原画",
            .traditionalChinese: "原畫",
            .english: "Original",
            .japanese: "原画"
        ],
        "offline.title": [
            .simplifiedChinese: "离线漫画",
            .traditionalChinese: "離線漫畫",
            .english: "Offline Comics",
            .japanese: "オフライン漫画"
        ],
        "offline.empty": [
            .simplifiedChinese: "暂无离线漫画",
            .traditionalChinese: "暫無離線漫畫",
            .english: "No offline comics",
            .japanese: "オフライン漫画はありません"
        ],
        "offline.empty.subtitle": [
            .simplifiedChinese: "在漫画详情页下载后会显示在这里",
            .traditionalChinese: "在漫畫詳情頁下載後會顯示在這裡",
            .english: "Downloaded comics will appear here.",
            .japanese: "漫画詳細からダウンロードするとここに表示されます"
        ],
        "offline.detail": [
            .simplifiedChinese: "%d 话 · %d 张图片",
            .traditionalChinese: "%d 話 · %d 張圖片",
            .english: "%d chapters · %d images",
            .japanese: "%d話 ・ %d枚"
        ],
        "offline.quality": [
            .simplifiedChinese: "质量：%@",
            .traditionalChinese: "品質：%@",
            .english: "Quality: %@",
            .japanese: "画質：%@"
        ],
        "offline.downloading": [
            .simplifiedChinese: "正在下载 %d/%d 张图片",
            .traditionalChinese: "正在下載 %d/%d 張圖片",
            .english: "Downloading %d/%d images",
            .japanese: "%d/%d枚をダウンロード中"
        ],
        "offline.read": [
            .simplifiedChinese: "阅读",
            .traditionalChinese: "閱讀",
            .english: "Read",
            .japanese: "読む"
        ],
        "offline.redownload": [
            .simplifiedChinese: "重新下载",
            .traditionalChinese: "重新下載",
            .english: "Redownload",
            .japanese: "再ダウンロード"
        ],
        "offline.delete": [
            .simplifiedChinese: "删除",
            .traditionalChinese: "刪除",
            .english: "Delete",
            .japanese: "削除"
        ],
        "offline.upgrade": [
            .simplifiedChinese: "升级质量",
            .traditionalChinese: "升級品質",
            .english: "Upgrade Quality",
            .japanese: "画質をアップグレード"
        ],
        "offline.confirm": [
            .simplifiedChinese: "确认下载",
            .traditionalChinese: "確認下載",
            .english: "Confirm Download",
            .japanese: "ダウンロードを確認"
        ],
        "offline.confirm.title": [
            .simplifiedChinese: "确认更新离线漫画？",
            .traditionalChinese: "確認更新離線漫畫？",
            .english: "Update this offline comic?",
            .japanese: "オフライン漫画を更新しますか？"
        ],
        "common.delete": [
            .simplifiedChinese: "删除", .traditionalChinese: "刪除", .english: "Delete", .japanese: "削除"
        ],
        "common.continue": [
            .simplifiedChinese: "继续", .traditionalChinese: "繼續", .english: "Continue", .japanese: "続ける"
        ],
        "common.close": [
            .simplifiedChinese: "关闭", .traditionalChinese: "關閉", .english: "Close", .japanese: "閉じる"
        ],
        "common.confirm": [
            .simplifiedChinese: "确认", .traditionalChinese: "確認", .english: "Confirm", .japanese: "確認"
        ],
        "agent.title": [
            .simplifiedChinese: "Shirayuki Agent", .traditionalChinese: "Shirayuki Agent", .english: "Shirayuki Agent", .japanese: "Shirayuki Agent"
        ],
        "agent.empty": [
            .simplifiedChinese: "发送消息开始新会话", .traditionalChinese: "傳送訊息開始新會話", .english: "Send a message to start a session", .japanese: "メッセージを送信してセッションを開始"
        ],
        "contentFilter.resultsHidden": [
            .simplifiedChinese: "结果已被屏蔽词隐藏", .traditionalChinese: "結果已被封鎖詞隱藏", .english: "Results hidden by blocked words", .japanese: "結果はブロックワードで非表示です"
        ],
        "settings.contentFilter": [
            .simplifiedChinese: "内容过滤", .traditionalChinese: "內容過濾", .english: "Content Filtering", .japanese: "コンテンツフィルター"
        ],
        "settings.contentFilter.subtitle": [
            .simplifiedChinese: "管理远程漫画屏蔽词", .traditionalChinese: "管理遠端漫畫封鎖詞", .english: "Manage blocked words for remote comics", .japanese: "リモート漫画のブロックワードを管理"
        ],
        "settings.contentFilter.words": [
            .simplifiedChinese: "屏蔽词", .traditionalChinese: "封鎖詞", .english: "Blocked Words", .japanese: "ブロックワード"
        ],
        "settings.contentFilter.word": [
            .simplifiedChinese: "词条", .traditionalChinese: "詞條", .english: "Word", .japanese: "ワード"
        ],
        "settings.contentFilter.add": [
            .simplifiedChinese: "添加屏蔽词", .traditionalChinese: "新增封鎖詞", .english: "Add Blocked Word", .japanese: "ブロックワードを追加"
        ],
        "settings.contentFilter.edit": [
            .simplifiedChinese: "编辑屏蔽词", .traditionalChinese: "編輯封鎖詞", .english: "Edit Blocked Word", .japanese: "ブロックワードを編集"
        ],
        "settings.contentFilter.saved": [
            .simplifiedChinese: "已保存", .traditionalChinese: "已儲存", .english: "Saved", .japanese: "保存しました"
        ],
        "settings.contentFilter.duplicate": [
            .simplifiedChinese: "该屏蔽词已存在", .traditionalChinese: "該封鎖詞已存在", .english: "Blocked word already exists", .japanese: "ブロックワードは既に存在します"
        ],
        "settings.contentFilter.agentConfirmation": [
            .simplifiedChinese: "Agent 修改前确认", .traditionalChinese: "Agent 修改前確認", .english: "Confirm Agent Changes", .japanese: "Agent の変更前に確認"
        ],
        "settings.contentFilter.agentConfirmationRisk": [
            .simplifiedChinese: "关闭后，Agent 可直接修改全部屏蔽词。", .traditionalChinese: "關閉後，Agent 可直接修改全部封鎖詞。", .english: "When off, Agent can change all blocked words without confirmation.", .japanese: "オフにすると Agent は確認なしで変更できます。"
        ],
        "settings.contentFilter.error": [
            .simplifiedChinese: "无法保存屏蔽词", .traditionalChinese: "無法儲存封鎖詞", .english: "Could not save blocked word", .japanese: "ブロックワードを保存できません"
        ],
        "settings.contentFilter.error.empty": [
            .simplifiedChinese: "词条不能为空", .traditionalChinese: "詞條不可為空", .english: "Word cannot be empty", .japanese: "ワードを空にできません"
        ],
        "settings.contentFilter.error.control_character": [
            .simplifiedChinese: "词条包含控制字符", .traditionalChinese: "詞條包含控制字元", .english: "Word contains a control character", .japanese: "制御文字が含まれています"
        ],
        "settings.contentFilter.error.too_long": [
            .simplifiedChinese: "词条不能超过 64 个字符", .traditionalChinese: "詞條不可超過 64 個字元", .english: "Word cannot exceed 64 characters", .japanese: "64 文字以内にしてください"
        ],
        "settings.contentFilter.error.limit_reached": [
            .simplifiedChinese: "最多保存 100 条", .traditionalChinese: "最多儲存 100 條", .english: "Maximum 100 blocked words", .japanese: "最大 100 件です"
        ],
        "settings.contentFilter.error.not_found": [
            .simplifiedChinese: "屏蔽词不存在", .traditionalChinese: "封鎖詞不存在", .english: "Blocked word not found", .japanese: "ブロックワードが見つかりません"
        ],
        "settings.contentFilter.error.duplicate_target": [
            .simplifiedChinese: "目标屏蔽词已存在", .traditionalChinese: "目標封鎖詞已存在", .english: "Target blocked word already exists", .japanese: "変更先は既に存在します"
        ],
        "settings.contentFilter.operations": [
            .simplifiedChinese: "操作", .traditionalChinese: "操作", .english: "Actions", .japanese: "操作"
        ],
        "settings.contentFilter.addBlocked": [
            .simplifiedChinese: "添加屏蔽词", .traditionalChinese: "新增封鎖詞", .english: "Add Blocked Word", .japanese: "ブロックワードを追加"
        ],
        "settings.contentFilter.addIncluded": [
            .simplifiedChinese: "添加只选词", .traditionalChinese: "新增只選詞", .english: "Add Included Word", .japanese: "含めるワードを追加"
        ],
        "settings.contentFilter.library": [
            .simplifiedChinese: "词库", .traditionalChinese: "詞庫", .english: "Word Libraries", .japanese: "ワードライブラリ"
        ],
        "settings.contentFilter.blockedCount": [
            .simplifiedChinese: "屏蔽词数量", .traditionalChinese: "封鎖詞數量", .english: "Blocked words", .japanese: "ブロックワード数"
        ],
        "settings.contentFilter.includedCount": [
            .simplifiedChinese: "只选词数量", .traditionalChinese: "只選詞數量", .english: "Included words", .japanese: "含めるワード数"
        ],
        "settings.contentFilter.viewBlocked": [
            .simplifiedChinese: "查看屏蔽词", .traditionalChinese: "查看封鎖詞", .english: "View Blocked Words", .japanese: "ブロックワードを表示"
        ],
        "settings.contentFilter.viewIncluded": [
            .simplifiedChinese: "查看只选词", .traditionalChinese: "查看只選詞", .english: "View Included Words", .japanese: "含めるワードを表示"
        ],
        "settings.contentFilter.danger": [
            .simplifiedChinese: "危险操作", .traditionalChinese: "危險操作", .english: "Danger Zone", .japanese: "危険な操作"
        ],
        "settings.contentFilter.deleteAllBlocked": [
            .simplifiedChinese: "删除所有屏蔽词", .traditionalChinese: "刪除所有封鎖詞", .english: "Delete All Blocked Words", .japanese: "すべてのブロックワードを削除"
        ],
        "settings.contentFilter.deleteAllIncluded": [
            .simplifiedChinese: "删除所有只选词", .traditionalChinese: "刪除所有只選詞", .english: "Delete All Included Words", .japanese: "すべての含めるワードを削除"
        ],
        "settings.contentFilter.reset": [
            .simplifiedChinese: "重置过滤配置", .traditionalChinese: "重設過濾設定", .english: "Reset Filter Settings", .japanese: "フィルター設定をリセット"
        ],
        "settings.contentFilter.deleteAllBlocked.confirm": [
            .simplifiedChinese: "将删除全部屏蔽词，不能撤销。", .traditionalChinese: "將刪除全部封鎖詞，無法復原。", .english: "This deletes every blocked word and cannot be undone.", .japanese: "すべてのブロックワードを削除します。元に戻せません。"
        ],
        "settings.contentFilter.deleteAllIncluded.confirm": [
            .simplifiedChinese: "将删除全部只选词，不能撤销。", .traditionalChinese: "將刪除全部只選詞，無法復原。", .english: "This deletes every included word and cannot be undone.", .japanese: "すべての含めるワードを削除します。元に戻せません。"
        ],
        "settings.contentFilter.reset.confirm": [
            .simplifiedChinese: "将删除屏蔽词和只选词，不能撤销。", .traditionalChinese: "將刪除封鎖詞和只選詞，無法復原。", .english: "This deletes both word libraries and cannot be undone.", .japanese: "両方のワードライブラリを削除します。元に戻せません。"
        ],
        "settings.appearance.animation": [
            .simplifiedChinese: "动画模式", .traditionalChinese: "動畫模式", .english: "Animation Mode", .japanese: "アニメーション"
        ],
        "settings.appearance.animation.standard": [
            .simplifiedChinese: "标准", .traditionalChinese: "標準", .english: "Standard", .japanese: "標準"
        ],
        "settings.appearance.animation.reduced": [
            .simplifiedChinese: "减少动态", .traditionalChinese: "減少動態", .english: "Reduced", .japanese: "軽減"
        ],
        "settings.appearance.animation.off": [
            .simplifiedChinese: "关闭", .traditionalChinese: "關閉", .english: "Off", .japanese: "オフ"
        ],
        "settings.appearance.agentButtonStyle": [
            .simplifiedChinese: "Agent 按钮样式", .traditionalChinese: "Agent 按鈕樣式", .english: "Agent Button Style", .japanese: "Agent ボタンスタイル"
        ],
        "settings.appearance.agentButtonStyle.accent": [
            .simplifiedChinese: "强调色", .traditionalChinese: "強調色", .english: "Accent", .japanese: "アクセント"
        ],
        "settings.appearance.agentButtonStyle.glass": [
            .simplifiedChinese: "玻璃", .traditionalChinese: "玻璃", .english: "Glass", .japanese: "ガラス"
        ],
        "settings.appearance.agentButtonOpacity": [
            .simplifiedChinese: "Agent 按钮透明度", .traditionalChinese: "Agent 按鈕透明度", .english: "Agent Button Opacity", .japanese: "Agent ボタン透明度"
        ],
        "settings.agent.history": [
            .simplifiedChinese: "Agent 会话", .traditionalChinese: "Agent 會話", .english: "Agent Sessions", .japanese: "Agent セッション"
        ],
        "settings.agent.history.count": [
            .simplifiedChinese: "会话数量", .traditionalChinese: "會話數量", .english: "Session Count", .japanese: "セッション数"
        ],
        "settings.agent.history.updated": [
            .simplifiedChinese: "当前会话更新", .traditionalChinese: "目前會話更新", .english: "Current Session Updated", .japanese: "現在のセッション更新"
        ],
        "settings.agent.history.size": [
            .simplifiedChinese: "当前会话大小", .traditionalChinese: "目前會話大小", .english: "Current Session Size", .japanese: "現在のセッションサイズ"
        ],
        "settings.agent.history.manage": [
            .simplifiedChinese: "管理会话历史", .traditionalChinese: "管理會話歷史", .english: "Manage Session History", .japanese: "セッション履歴を管理"
        ],
        "settings.agent.history.new": [
            .simplifiedChinese: "新建会话", .traditionalChinese: "新增會話", .english: "New Session", .japanese: "新規セッション"
        ],
        "settings.agent.history.cancelActive": [
            .simplifiedChinese: "取消当前 Agent 操作后继续？", .traditionalChinese: "取消目前 Agent 操作後繼續？", .english: "Cancel the active Agent operation and continue?", .japanese: "実行中の Agent 操作をキャンセルして続けますか？"
        ],
        "settings.storage.agent": [
            .simplifiedChinese: "Agent 会话", .traditionalChinese: "Agent 會話", .english: "Agent Sessions", .japanese: "Agent セッション"
        ],
        "settings.storage.agent.deleteAll": [
            .simplifiedChinese: "删除全部 Agent 会话", .traditionalChinese: "刪除全部 Agent 會話", .english: "Delete All Agent Sessions", .japanese: "Agent セッションをすべて削除"
        ],
        "settings.storage.agent.deleteAll.confirm": [
            .simplifiedChinese: "这会删除所有账号和匿名用户的本地 Agent 历史。", .traditionalChinese: "這會刪除所有帳號與匿名使用者的本機 Agent 歷史。", .english: "This deletes local Agent history for every account and anonymous use.", .japanese: "すべてのアカウントと匿名利用のローカル履歴を削除します。"
        ],
        "settings.storage.agent.deleteAll.done": [
            .simplifiedChinese: "Agent 会话已删除", .traditionalChinese: "Agent 會話已刪除", .english: "Agent sessions deleted", .japanese: "Agent セッションを削除しました"
        ],
        "settings.storage.agent.deleteAll.error": [
            .simplifiedChinese: "无法删除 Agent 会话", .traditionalChinese: "無法刪除 Agent 會話", .english: "Could not delete Agent sessions", .japanese: "Agent セッションを削除できません"
        ],
        "agent.state.input_too_large": [
            .simplifiedChinese: "输入超过 16 KiB", .traditionalChinese: "輸入超過 16 KiB", .english: "Input exceeds 16 KiB", .japanese: "入力が 16 KiB を超えています"
        ],
        "agent.state.session_limit_reached": [
            .simplifiedChinese: "当前会话已达到容量限制", .traditionalChinese: "目前會話已達容量限制", .english: "This session reached its size limit", .japanese: "このセッションは容量上限に達しました"
        ],
        "agent.state.configuration_required": [
            .simplifiedChinese: "请先配置 Agent", .traditionalChinese: "請先設定 Agent", .english: "Configure Agent first", .japanese: "Agent を設定してください"
        ],
        "agent.state.login_required": [
            .simplifiedChinese: "此操作需要登录", .traditionalChinese: "此操作需要登入", .english: "Sign in is required", .japanese: "ログインが必要です"
        ],
        "agent.state.agent_error": [
            .simplifiedChinese: "Agent 请求失败", .traditionalChinese: "Agent 請求失敗", .english: "Agent request failed", .japanese: "Agent リクエストに失敗しました"
        ],
        "agent.state.transport_configurationRequired": [
            .simplifiedChinese: "Agent 配置不完整（configurationRequired）", .traditionalChinese: "Agent 設定不完整（configurationRequired）", .english: "Agent configuration is incomplete (configurationRequired)", .japanese: "Agent設定が不完全です（configurationRequired）"
        ],
        "agent.state.transport_invalidEndpoint": [
            .simplifiedChinese: "Agent endpoint 无效（invalidEndpoint）", .traditionalChinese: "Agent endpoint 無效（invalidEndpoint）", .english: "Agent endpoint is invalid (invalidEndpoint)", .japanese: "Agent endpointが無効です（invalidEndpoint）"
        ],
        "agent.state.transport_redirectRejected": [
            .simplifiedChinese: "Agent endpoint 重定向被拒绝（redirectRejected）", .traditionalChinese: "Agent endpoint 重新導向遭拒（redirectRejected）", .english: "Agent endpoint redirect was rejected (redirectRejected)", .japanese: "Agent endpointのリダイレクトを拒否しました（redirectRejected）"
        ],
        "agent.state.transport_invalidImage": [
            .simplifiedChinese: "页面图片无效或过大（invalidImage）", .traditionalChinese: "頁面圖片無效或過大（invalidImage）", .english: "Page image is invalid or too large (invalidImage)", .japanese: "ページ画像が無効または大きすぎます（invalidImage）"
        ],
        "agent.state.transport_visionUnsupported": [
            .simplifiedChinese: "模型不支持图片输入（visionUnsupported）", .traditionalChinese: "模型不支援圖片輸入（visionUnsupported）", .english: "Model does not support image input (visionUnsupported)", .japanese: "モデルは画像入力に対応していません（visionUnsupported）"
        ],
        "agent.state.transport_invalidResponse": [
            .simplifiedChinese: "Provider 返回空响应或未知结构（invalidResponse）", .traditionalChinese: "Provider 回傳空回應或未知結構（invalidResponse）", .english: "Provider returned an empty or unknown response (invalidResponse)", .japanese: "Providerが空または未知形式の応答を返しました（invalidResponse）"
        ],
        "agent.state.transport_unauthorized": [
            .simplifiedChinese: "API 密钥无效或未授权（unauthorized）", .traditionalChinese: "API 金鑰無效或未授權（unauthorized）", .english: "API key is invalid or unauthorized (unauthorized)", .japanese: "APIキーが無効または未承認です（unauthorized）"
        ],
        "agent.state.transport_serverError": [
            .simplifiedChinese: "Provider 返回服务器错误（serverError）", .traditionalChinese: "Provider 回傳伺服器錯誤（serverError）", .english: "Provider returned a server error (serverError)", .japanese: "Providerがサーバーエラーを返しました（serverError）"
        ],
        "agent.state.transport_decodingFailed": [
            .simplifiedChinese: "Provider 响应无法解析（decodingFailed）", .traditionalChinese: "Provider 回應無法解析（decodingFailed）", .english: "Provider response could not be decoded (decodingFailed)", .japanese: "Provider応答を解析できません（decodingFailed）"
        ],
        "agent.state.transport_networkFailed": [
            .simplifiedChinese: "Provider 网络请求失败（networkFailed）", .traditionalChinese: "Provider 網路請求失敗（networkFailed）", .english: "Provider network request failed (networkFailed)", .japanese: "Providerへのネットワーク要求に失敗しました（networkFailed）"
        ],
        "agent.state.step_limit_reached": [
            .simplifiedChinese: "Agent 已达到内部步骤安全上限", .traditionalChinese: "Agent 已達到內部步驟安全上限", .english: "Agent reached the internal step safety limit", .japanese: "Agentは内部ステップ安全上限に達しました"
        ],
        "agent.state.tool_call_limit_reached": [
            .simplifiedChinese: "Agent 已达到 Tool Call 上限", .traditionalChinese: "Agent 已達到 Tool Call 上限", .english: "Agent reached the tool-call limit", .japanese: "AgentはTool Call上限に達しました"
        ]
    ]
}
