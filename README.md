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

# 介绍

**Shirayuki** 是一个基于 `SwiftUI + 原生 Pica API` 构建的第三方漫画客户端，目标是在不改动官方服务的前提下，提供流畅的原生浏览与阅读体验。

项目通过直连官方 REST API 获取数据，所有界面与交互均由 SwiftUI 原生渲染，支持 iOS 与 macOS 双平台。

## 功能概览

- **首页**：最新漫画、日榜 / 周榜 / 月榜切换，下拉刷新，无限滚动
- **分类**：网格浏览全部分类，支持点击进入分类漫画列表
- **搜索**：关键词搜索、热门搜索词、历史记录（上限 20 条）、排序筛选
- **漫画详情**：完整元数据、创作者信息、标签、点赞、收藏、阅读进度、章节列表（支持正序 / 倒序 / 折叠）、推荐漫画
- **阅读器**：
  - 纵向滚动 / 横向翻页双模式
  - 双击 / 捏合缩放
  - 章节切换、页码显示与 Slider 跳转
  - 自动翻页（2 ~ 60 秒可调）
  - 菜单锁定、阅读进度自动保存、继续阅读
- **个人中心**：用户信息、EXP / 等级、收藏浏览、每日打卡
- **设置**：系统 / 浅色 / 深色主题、多语言切换（简中 / 繁中 / 英 / 日）、API 线路切换、图片质量切换、缓存清理

## 文件结构

```text
+-- Shirayuki                 <- App 主体源码
│   +-- Models/              <- 数据模型（部分内联于 PicaAPI.swift）
│   +-- Network/             <- API 客户端、DTO、服务、图片加载
│   +-- Services/            <- 全局状态、Token/凭证存储、阅读进度、主题/语言/图片质量
│   +-- ViewModels/          <- 各页面视图模型
│   +-- Views/               <- SwiftUI 视图与自定义组件
│   +-- Assets.xcassets/
│   +-- ShirayukiApp.swift   <- App 入口
+-- Shirayuki.xcodeproj      <- Xcode 工程
+-- ShirayukiTests           <- 单元测试
+-- ShirayukiUITests         <- UI 测试
+-- Package.swift            <- Swift Package Manager 配置
+-- LICENSE
+-- README.md
```

## 使用方法

- 从 [Releases](https://github.com/chitsanfei/shirayuki/releases) 下载已打包的应用文件；或者，从 [Github Action](https://github.com/chitsanfei/shirayuki/actions/workflows/ios-unsigned-ipa.yml) 下载最新一次构建的 Unsigned iOS IPA 文件。
- 下载完成后，使用 AltStore、TrollStore 或其它自签名工具进行签名安装。
- 将下载得到的安装包导入上述工具，并使用你自己的 Apple ID 或对应证书完成签名。
- 签名完成后，将应用安装到 iPhone / iPad / Mac 即可使用。

## 开发说明

> [!WARNING]
> 本项目的维护者和 PicaACG 开发团队无任何关联。
> 使用自行承担风险。

- 纯原生 API 客户端，所有数据均通过官方 REST API 获取。
- 支持 iOS 16+ / macOS 14+，构建工具要求 Swift 5.9+。

待修复 & 添加：

- [ ] 添加 AI 翻译功能
- [ ] 添加离线下载和阅读功能
- [ ] 阅读页稳定性优化
- [ ] 评论区显示，懒加载和界面性能

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
- [Apple Liquid Glass](https://developer.apple.com/documentation/SwiftUI/Landmarks-Building-an-app-with-Liquid-Glass)：UI
