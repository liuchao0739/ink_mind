---
name: inkmind-logo-and-online-books
overview: 补齐墨智应用的品牌 Logo，并为在线图书内容接入设计合法、可扩展的书源方案（含四大名著与版权作品接入策略）。
todos:
  - id: logo-assets
    content: 设计并接入墨智应用 Logo（App Icon、Web Favicon、应用内品牌位）。
    status: completed
  - id: remote-public-domain-source
    content: 设计并实现公版/古籍类在线书源的数据结构与调用流程。
    status: completed
  - id: remote-copyright-links
    content: 为《三体》《剑来》等版权作品设计官方链接跳转与本地导入双路径支持。
    status: completed
isProject: false
---

## 墨智 Logo 与在线书源方案

### 一、目标与约束

- **目标 1**：为墨智应用补齐统一的 Logo 方案，至少覆盖应用图标（各端 App Icon）、Web Favicon，并为后续 UI 中的品牌展示预留组件。  
- **目标 2**：在现有本地书库基础上，增加“从网络获取完整书籍内容”的能力：
  - 优先支持**四大名著等公版/古籍**的完整在线获取；
  - 为《三体》《剑来》等**仍在版权期的作品**设计合理的接入方式（避免直接侵权下载）。
- **约束**：
  - 不自建后端，所有能力以前端调用公开 API / 打开官方阅读链接为主；
  - 避免对盗版站点的抓取和缓存，把 Demo 的重点放在“能力设计 + 架构”而非绕版权。

### 二、Logo 与品牌落地方案

- **Logo 设计方向（文案级约束）**
  - 图形元素：
    - 墨滴/墨迹 + 书页轮廓，暗示“墨”；
    - 简化的电路/芯片线条围绕墨滴或书脊，暗示“智”。
  - 字体元素：
    - 中文主标：`墨智`，简洁黑体或略带书法笔意；
    - 英文副标：`InkMind`，搭配轻量无衬线字体，可在 splash / 引导页中同时展示。
- **Flutter 侧落地（代码层规划，不立即改动）**
  - 在 `pubspec.yaml` 中规划使用 `flutter_launcher_icons`（已在后续开发阶段添加），生成多端 App Icon：
    - 源文件放置于 `[assets/branding/icon.png](assets/branding/icon.png)`；
    - Android / iOS / Web / 桌面统一从此源导出各尺寸图标。
  - Web Favicon：
    - 在 `web/favicon.png` 中替换为 Logo 版本，并更新 `web/index.html` 中的 `<link rel="icon">` 如有需要。
  - 应用内品牌位：
    - 在 `lib/features/home/home_page.dart` 顶部 AppBar 或首页顶部区域预留一块品牌展示：
      - 小 Logo + 文案：“墨智 · InkMind —— AI 多端智能阅读”；
    - 可选：在首次启动时增加简单的 Splash / Welcome 页，展示 Logo 与“智荐 / 智声 / 智记”三个标签。

### 三、网络书源整体架构设计

- **书源类型划分**
  - `LocalAssets`：现有内置 JSON 示例书（`assets/books/*.json`）。
  - `LocalFiles`：未来通过 TXT/EPUB 导入的本地书籍（用户自己提供三体等）。
  - `RemotePublicDomain`：公版/古籍类书籍，通过公开 API 合法获取（如四大名著、古籍接口）。
  - `RemoteCopyrightedLink`：仍在版权期的热门作品（如《三体》《剑来》），只存**元数据 + 官方阅读链接**，不存/拉取正文。
- **数据层扩展（在现有模型上的规划）**
  - 在 `[lib/data/models/book.dart](lib/data/models/book.dart)` 的 `Book` 模型中：
    - 已有 `sourceType` 字段，可扩展枚举含义：`asset` / `localFile` / `publicDomainApi` / `copyrightLink`；
    - 新增可选字段 `remoteApiId`（如第三方 API 的 bookId）、`externalUrl`（如起点/七猫/QQ 阅读官方阅读地址）。
  - 新增 `RemoteBookDataSource` 接口：
    - `Future<List<Book>> searchRemote(String keyword)`；
    - `Future<(Book, List<Chapter>)> fetchPublicDomainBook(String apiBookId)`；
  - 在 `BookRepository` 中增加聚合逻辑：
    - 先查本地；
    - 若未命中且用户开启“在线搜索”，则附加远程结果（标记来源不同，UI 中以徽标提示“在线书源”）。
- **调用外部 API 的候选方案（规划层，不绑死具体服务）**
  - **四大名著 / 古籍**：
    - 利用类似天聚数行的“古籍查询 API”这类平台（如搜索结果中的 `[古籍查询API接口 - TianAPI][3]`），获取《论语》《山海经》以及部分古典名著；
    - 或选用“免费小说/古籍 API”中明确标注可用于个人/学习场景的接口，优先只用于公版书。
  - **通用小说搜索（谨慎使用）**：
    - 像“找小说 API”这类接口可以搜索并返回 txt 链接，但存在稳定性和版权风险，只在 Demo/PPT 中作为“可以接入的通路”展示，不在正式环境长期依赖。
- **版权作品策略（《三体》《剑来》）**
  - 不直接从第三方站点抓取完整正文，也不在本地缓存整书文本。  
  - 在应用中：
    - 提供搜索结果卡片：展示封面、简介、作者、评分等，来源标注为“起点官方”“七猫官方”等；
    - 点击后通过 `url_launcher` 打开官方阅读地址（浏览器或官方 App），作为“跳转阅读”；
    - 若用户将自己合法获得的 TXT 导入，应用将其当作 `LocalFile` 处理，仅在用户设备内阅读。
  - 在 PPT 中明确写出这一策略：**墨智尊重版权，通过官方链接与本地导入两条路径支持热门作品阅读**。

### 四、具体功能规划

#### 1. 在线搜索入口设计

- 在 `HomePage` 搜索框下方增加一个开关或提示：
  - 文案示例：“在本地书库基础上，尝试从在线公版书源扩展搜索结果（仅公版/免费资源）”。
- 搜索逻辑：
  - 本地结果优先展示；
  - 若勾选了“在线扩展”，则在列表尾部追加“来自网络”的书籍分组：
    - 对 `RemotePublicDomain` 类型：可直接点击进入阅读（在线拉取章节）；
    - 对 `RemoteCopyrightedLink` 类型：点击后打开官方阅读链接。

#### 2. 公版/古籍在线阅读流程

- 从 `searchRemote` 返回 `Book` + 简要章节信息；
- 用户点击后：
  - 若为公版资源：调用 `fetchPublicDomainBook` 拉取完整章节列表和正文（可缓存到本地以提升后续访问速度）；
  - 重用现有 `ReaderPage` 展示内容，阅读进度与统计逻辑与本地书一致。
- 在 UI 中标记“网络公版资源”，避免用户误以为是本地预置。

#### 3. 版权作品联动流程

- 搜索 `三体` / `剑来`：
  - 在远程数据源中只保存：书名、作者、封面 URL、简介、所属平台、官方阅读 URL；
  - 结果卡片上加一个标签：“前往官方阅读”。
- 点击卡片：
  - 使用 `url_launcher` 打开浏览器或对应 App，不在墨智内渲染正文；
  - 可选：允许用户将该书加入“关注列表”，仅作为书签记录，方便下次一键跳转。

#### 4. 小程序与后续扩展（结构预留）

- 由于目前无小程序端代码，本期只在架构层强调：
  - 数据层（Book / Chapter / Repositories）与 UI 解耦，方便迁移到 Flutter + 小程序容器；
  - 外部 API 调用通过统一的 `RemoteBookDataSource` 抽象，未来在小程序环境中可替换为小程序原生网络/云函数调用。

### 五、实现步骤建议（后续开发用）

1. **品牌资源落地**：
  - 设计并导出一套基础 Logo（1024x1024 PNG）；
  - 在 `pubspec.yaml` 中规划 `flutter_launcher_icons` 配置并生成多端图标；
  - 替换 `web/favicon.png`，并在首页 AppBar 显示小 Logo + 文案。
2. **数据模型与仓库扩展**：
  - 为 `Book` 增加 `remoteApiId`、`externalUrl` 等字段，并扩展 `sourceType` 枚举；
  - 新增 `RemoteBookDataSource` 抽象与简单实现（如使用一个公开的公版书 API）。
3. **搜索与结果展示改造**：
  - 在首页搜索逻辑中调用本地 + 远程两类数据源；
  - 在 UI 中分组展示“本地书库 / 在线公版资源 / 官方阅读链接”。
4. **阅读流程拓展**：
  - 对 `RemotePublicDomain` 书籍，重用 `ReaderPage` 显示远程正文，并复用进度/统计逻辑；
  - 对 `RemoteCopyrightedLink` 书籍，统一通过 `url_launcher` 跳转，不托管正文。
5. **文案与大赛材料更新**：
  - 在 `README` 和 PPT 中补充“书源策略”与“版权合规设计”一页，突出你对版权的尊重和技术取舍。

这份规划不会改动你当前代码，只是明确后续如何在**品牌 Logo**与**在线书源（尤其是四大名著 vs 《三体》《剑来》）**之间做一个既酷又合规的实现路径。