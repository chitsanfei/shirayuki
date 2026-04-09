<div align="center">
    <hr>
    <img src="./.assets/icon.png" height="200" alt="Shirayuki">
    <h1>Shirayuki</h1>
    <b>一个为了更方便的（bushi）去 PikaACG 打造的第三方 iOS 客户端</b>
</div>

<br>

<p align="center">
    <a href="https://github.com/chitsanfei/shirayuki/issues"><img src="https://img.shields.io/github/issues/chitsanfei/shirayuki"></a>
    <a href="https://github.com/chitsanfei/shirayuki/forks"><img src="https://img.shields.io/github/forks/chitsanfei/shirayuki"></a>
    <a href="https://github.com/chitsanfei/shirayuki"><img src="https://img.shields.io/github/stars/chitsanfei/shirayuki"></a>
    <a href="https://github.com/chitsanfei/shirayuki/blob/main/LICENSE"><img src="https://img.shields.io/github/license/chitsanfei/shirayuki"></a>
    <a href="https://github.com/chitsanfei/shirayuki"><img src="https://img.shields.io/github/commit-activity/t/chitsanfei/shirayuki"></a>
</p>

---

# 介绍

**Shirayuki** 是一个基于 `SwiftUI + WKWebView` 构建的第三方 iOS 客户端，目标是在不改动 PikaACG 后端的前提下，用原生界面和交互去接管移动端网页体验。

为什么要设计这个呢？首先是练手，其次是 *luguanluguanlulushijiandaole*。

项目目前主要通过网页承载内容，再由原生层补齐一些更接近 App 的能力，例如底部导航、阅读退出、暗夜模式、视频屏蔽、缓存清理和状态同步等。

目标站点前端结构若发生变化，App 的功能也需要同步调整。

## 功能概览

- 原生底部导航切换
- WebView 页面路径与登录状态同步
- 阅读器场景识别与退出按钮
- 网页暗色增强
- 缓存清理

## 文件结构

```text
+-- Shirayuki                 <- App 主体源码
+-- Shirayuki.xcodeproj      <- Xcode 工程
+-- ShirayukiTests           <- 单元测试
+-- ShirayukiUITests         <- UI 测试
+-- LICENSE
+-- README.md
```

## 使用方法

-  从 [Releases](https://github.com/chitsanfei/shirayuki/releases) 下载已打包的应用文件。

- 下载完成后，使用 AltStore, TrollStore 或其它自签名工具进行签名安装。

- 将下载得到的安装包导入上述工具，并使用你自己的 Apple ID 或对应证书完成签名。

- 签名完成后，将应用安装到 iPhone 即可使用。

## 开发说明

> [!WARNING]
> 本项目的维护者和 BikaACG 开发团队无任何关联。
> 使用自行承担风险。

当前项目为原生壳应用,大部分功能的稳定性都依赖目标网页结构。

待修复&添加的:

- 兼容性
- 阅读页交互稳定性
- UI 测试与状态同步测试补全

## 许可证

`Shirayuki` 采用 `MIT` 许可证进行开源。

```text
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

## 相关链接

- https://github.com/chitsanfei/shirayuki
- https://manhuabika.com
- https://developer.apple.com/xcode/swiftui/
