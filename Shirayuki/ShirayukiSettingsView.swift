import SwiftUI

struct ShirayukiSettingsView: View {
    @Binding var isPresented: Bool
    @Binding var darkModeOption: DarkModeOption
    @Binding var videoBlockEnabled: Bool
    @Environment(\.colorScheme) private var systemColorScheme

    let clearingCache: Bool
    let cacheMessage: String?
    let todayString: String
    let sdkDisplay: String
    let minimumCompatibilityDisplay: String
    let onClearCache: () -> Void
    
    private var currentEffectiveMode: String {
        switch darkModeOption {
        case .system:
            return "跟随系统 (当前: \(systemColorScheme == .dark ? "深色" : "浅色"))"
        case .light:
            return "日间模式"
        case .dark:
            return "暗夜模式"
        }
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.2"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("网页主题") {
                    Picker("主题模式", selection: $darkModeOption) {
                        ForEach(DarkModeOption.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(currentEffectiveMode)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Toggle("屏蔽视频加载", isOn: $videoBlockEnabled)
                }

                Section("缓存") {
                    Button(role: .destructive, action: onClearCache) {
                        HStack {
                            Text("清空缓存")
                            Spacer()
                            if clearingCache { ProgressView() }
                        }
                    }

                    if let cacheMessage {
                        Text(cacheMessage)
                            .font(.footnote)
                    }
                }

                Section("信息") {
                    LabeledContent("项目", value: "Shirayuki")
                    LabeledContent("作者") {
                        Link("@chitsanfei", destination: URL(string: "https://github.com/chitsanfei")!)
                    }
                    LabeledContent("版本号", value: appVersion)
                    LabeledContent("日期", value: todayString)
                    LabeledContent("SDK", value: sdkDisplay)
                    LabeledContent("Swift", value: "5.0")
                    LabeledContent("最低兼容", value: minimumCompatibilityDisplay)
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { isPresented = false }
                }
            }
        }
    }
}
