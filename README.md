

<div align="center">
    <hr>
    <img src="./.assets/icon.png" height="200" alt="Shirayuki">
    <h1>Shirayuki</h1>
    <b>一个为 PicACG（哔咔漫画）打造的第三方 iOS / macOS 客户端</b>
</div>

<br>

<p align="center">
    <a href="https://github.com/chitsanfei/shirayuki/issues"><img src="https://img.shields.io/github/issues/chitsanfei/shirayuki"></a>
    <a href="https://github.com/chitsanfei/shirayuki/forks"><img src="https://img.shields.io/github/forks/chitsanfei/shirayuki"></a>
    <a href="https://github.com/chitsanfei/shirayuki"><img src="https://img.shields.io/github/stars/chitsanfei/shirayuki"></a>
    <a href="https://github.com/chitsanfei/shirayuki/blob/master/LICENSE"><img src="https://img.shields.io/github/license/chitsanfei/shirayuki"></a>
    <a href="https://github.com/chitsanfei/shirayuki"><img src="https://img.shields.io/github/commit-activity/t/chitsanfei/shirayuki"></a>
</p>

---

## 介绍

Shirayuki 是用 SwiftUI 编写的 PicACG（哔咔漫画）第三方客户端，支持 iOS 和 macOS。

## 功能

- **浏览**：首页推荐、日 / 周 / 月榜、分类、搜索和排序筛选。
- **漫画详情**：章节、标签、推荐漫画、点赞、收藏和阅读进度。
- **评论**：查看评论、发表评论和回复。一级评论在列表边缘继续滑动后松开翻页，二级回复使用分页按钮。
- **阅读**：纵向滚动或横向翻页、缩放、自动翻页、进度保存，支持章节下载和离线阅读。
- **个人中心**：账户信息、收藏和每日打卡。
- **设置**：主题、语言、API 线路、图片质量、缓存和漫画筛选词。
- **AI 助手**：读取漫画与评论信息，协助收藏、评论等操作。支持 OpenAI Chat Completions / Responses 和 Anthropic Messages 兼容接口，默认模型为 DeepSeek `deepseek-chat`。

## 安装

从 [Releases](https://github.com/chitsanfei/shirayuki/releases) 下载应用，或到 [GitHub Actions](https://github.com/chitsanfei/shirayuki/actions/workflows/ios-unsigned-ipa.yml) 下载最新的未签名 iOS IPA。

iOS 安装包需要通过 AltStore、TrollStore 等工具签名或安装。

## AI 助手与隐私

- 登录凭据和模型 API Key 分开保存在系统钥匙串中。
- 使用助手时，必要的漫画、评论等信息会发送给你配置的模型服务；发送当前阅读页图片前会单独征求确认。
- 发表评论、回复、删除、点赞和举报都属于风险操作，需先开启风险权限。Ask 模式逐次确认，YOLO 模式按授权自动执行。
- 会话记录保存在本机，并按账户隔离。你主动输入的文本会原样保存，请勿在对话中粘贴密码或密钥。

## 开发

- 支持 iOS 17+ / macOS 14+，使用 Xcode 构建，Swift 5.9+。
- 评论页面和 AI 助手共用 `CommentRepository`。写请求不自动重试，网络失败后请先刷新，避免重复提交。
- 评论删除受服务端权限限制，普通账户可能无法使用。

本项目与 PicACG 官方无关，使用风险请自行承担。

## 许可证

`Shirayuki` 采用 `GPL-3.0` 许可证进行开源。

```text
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
```

## 参考

- [haka_comic](https://github.com/raoxwup/haka_comic)：接口实现、UI
- [pica-go](https://github.com/niuhuan/pica-go)：评论写入、回复及删除/隐藏接口参考
- [Apple Liquid Glass](https://developer.apple.com/documentation/SwiftUI/Landmarks-Building-an-app-with-Liquid-Glass)：UI
