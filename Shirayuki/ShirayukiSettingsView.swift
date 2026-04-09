import SwiftUI

struct ShirayukiSettingsView: View {
    @Binding var isPresented: Bool
    @Binding var darkModeEnabled: Bool
    @Binding var videoBlockEnabled: Bool

    let clearingCache: Bool
    let cacheMessage: String?
    let todayString: String
    let sdkDisplay: String
    let minimumCompatibilityDisplay: String
    let onClearCache: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("网页设置") {
                    Toggle("暗夜模式", isOn: $darkModeEnabled)
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
                    LabeledContent("版本号", value: "v0.0.1")
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
