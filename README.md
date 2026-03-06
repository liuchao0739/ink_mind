## InkMind（墨智）简介

InkMind：直译为“墨水思维”，巧妙结合了阅读与智能，暗示用户通过这款应用，不仅能畅读书海，还能获得 AI 带来的思维拓展和智慧体验。

### 名称寓意

- **“墨”**：代表传统阅读的载体——书籍、文字、墨水，承载深厚的文化底蕴和知识积累，与“七猫免费小说”等阅读产品的本质一脉相承。  
- **“智”**：代表人工智能（AI），对应本项目的核心能力：智能推荐、个性化阅读、语音合成、阅读进度与行为分析等，让阅读更高效、更贴心。  
- **InkMind**：用英文呈现为 “墨水 + 思维”，强调“以文字为介质，用 AI 打开思维边界”的体验——不仅是看书，更是与知识和故事进行更智能的互动。

### AI 能力命名体系

- **智荐**：AI 推荐算法，根据阅读历史、题材偏好和热度为你生成“为你推荐”的书单。  
- **智声**：AI 朗读模块，基于 TTS 将文字变成声音，支持通勤/闭眼听书场景。  
- **智记**：AI 书摘模块，通过预置摘要 + 本地规则抽取，为每章生成关键句和小结，帮助你快速回顾重点内容。

这一整套命名，使“墨智”既有文化气质，又紧扣 “AI + 阅读” 主题，便于在大赛和后续品牌运营中持续扩展。

## 内容来源与版权策略

- **本地示例书（sourceType = asset）**：应用内置少量公版/古籍的节选内容，仅作为阅读体验示例和 UI 演示，不追求“全本收藏”。这些内容直接存放在 `assets/books/` 中。
- **公版在线书库（sourceType = publicDomainApi）**：通过远程公版 API 在线获取书籍元数据与章节正文，正文不打包进应用，只在用户发起阅读时按需从网络拉取并在本地渲染。
- **正版跳转书目（sourceType = copyrightLink）**：对处于版权保护期、但有官方阅读页面的作品，仅在应用内展示元数据和“前往官方阅读”入口，通过浏览器或官方 App 打开阅读链接，不抓取和缓存其正文。

整体原则是：**公版内容可以在线抓取与全文阅读，仍在版权期的作品只做“发现 + 跳转”，不在应用内存储或传播其文本内容**。

## 多端构建说明

### 环境要求

- 已安装 Flutter，并通过 `fvm` 管理版本：
  - 鸿蒙：`custom_3.22.1`（3.22.1-ohos-1.0.7）
  - 其他端：`3.35.3` 或兼容版本

### Android 构建

```bash
cd ink_mind
fvm use custom_3.22.1
fvm flutter pub get
fvm flutter run -d android
fvm flutter build apk --release
```

### iOS 构建（需 macOS + Xcode）

```bash
cd ink_mind
fvm use custom_3.22.1
fvm flutter pub get
fvm flutter run -d ios
fvm flutter build ios --release
```

### Web 构建

```bash
cd ink_mind
fvm use custom_3.22.1
fvm flutter pub get
fvm flutter run -d chrome
fvm flutter build web --release
```

### Windows / macOS 桌面端

确保 Flutter 桌面支持已开启（`flutter config --enable-macos-desktop` / `--enable-windows-desktop`）。

```bash
cd ink_mind
fvm use custom_3.22.1
fvm flutter pub get
fvm flutter run -d macos   # 或 windows
fvm flutter build macos --release   # 或 build windows
```

### 鸿蒙（HarmonyOS）构建（示意）

> 前提：已正确安装 Flutter for HarmonyOS 的工具链，并保证 `custom_3.22.1` 指向 3.22.1-ohos-1.0.7 SDK。

```bash
cd ink_mind
fvm use custom_3.22.1
fvm flutter pub get
fvm flutter run -d ohos   # 具体设备 ID 视本机环境而定
fvm flutter build ohos --release
```

不同端共用同一套 Flutter 代码，UI 采用响应式布局；鸿蒙如遇第三方插件不兼容（如 `flutter_tts`、`file_picker`），可在对应端通过条件编译或特性开关降级关闭相关入口，以保证核心“阅读 + 书架 + 本地进度”可顺利运行。
