---
name: inkmind-paged-reader-and-chapters
overview: 为 InkMind 的本地 TXT 与公版书实现类似「七猫免费小说」的分页阅读体验：自动分章节、分页渲染、章节导航与基础阅读控制。
todos:
  - id: chapter-parser-local
    content: 为本地 TXT 导入实现章节解析工具并接入 LocalBookDataSource.loadBookDetail
    status: completed
  - id: reader-state-page
    content: 扩展 ReaderState/ReaderController 以支持 pageIndex 与基于页的进度存储
    status: completed
  - id: page-composer
    content: 实现 PageComposer 文本分页工具并在 ReaderPage 中使用 PageView 渲染每一页
    status: completed
  - id: reader-ui-refactor
    content: 重构 ReaderPage 的 UI 为沉浸式阅读器样式，加入顶部/底部工具条、章节导航与阅读设置
    status: completed
  - id: regression-test
    content: 回归测试资产书、公版在线书、本地导入书的阅读、书摘、朗读与阅读统计是否正常
    status: completed
isProject: false
---

## 目标

- **自动分章节**：本地导入 TXT 不再是一整章，支持常见中英文章节标题规则（如“第X章”“第X回”“CHAPTER I”）。
- **分页阅读体验**：正文按屏幕尺寸、字体等参数自动分页，通过横向滑动切页，对标主流网文阅读器。
- **章节导航与进度**：支持在章节间跳转、记忆阅读进度（精确到页），并兼容现有阅读统计、AI 书摘/朗读。

## 架构与数据流

使用现有 `Book`/`Chapter`/`ReadingProgress` 模型，只在本地书籍加载与 Reader 页面上扩展逻辑：

```mermaid
flowchart LR
  home[HomePage] -->|选择书/导入 TXT| repo[BookRepository]
  repo -->|getChaptersForBook| dataSourceAsset[BookAssetDataSource]
  repo -->|getChaptersForBook| dataSourceLocal[LocalBookDataSource]
  dataSourceLocal --> parser[ChapterParser]
  parser --> chapters[List<Chapter>]
  chapters --> controller[ReaderController]
  controller --> state[ReaderState]
  state --> pageEngine[PageComposer]
  pageEngine --> ui[ReaderPage(PageView)]
  ui -->|onPageChanged| controller
  controller --> progress[ReadingRepository(ReadingProgress.pageIndex)]
```



## 具体改动方案

### 1. 本地 TXT 自动分章节

- **新增章节解析工具**：在 `[lib/data/utils/chapter_parser.dart](lib/data/utils/chapter_parser.dart)`（新文件）中实现 `ChapterParser`：
  - 输入：`Book book, String fullText`。
  - 输出：`List<Chapter>`，保证至少返回 1 章（找不到标题就整本一章作为兜底）。
  - 使用多条正则匹配常见章节标题：
    - 中文长篇：`^第[一二三四五六七八九十百千0-9]+[章回节卷].`*。
    - 英文：`^(CHAPTER|Chapter|chapter)\s+[IVXLCDM0-9]+\b.`*。
  - 算法：
    - 按行切分全文，逐行扫描；遇到匹配行时认为是新的章节标题，记录上一个章节的内容边界。
    - 去掉文件头可能出现的空行和版权声明（可根据长度/关键字如 `Project Gutenberg` 做简单过滤）。
    - 为每章构造 `Chapter`：`id: '${book.id}_ch$index'`，`title` 使用匹配行内容，`content` 为累积的正文文本。
- **接入本地数据源**：修改 `[lib/data/datasources/local_storage/local_book_data_source.dart](lib/data/datasources/local_storage/local_book_data_source.dart)` 的 `loadBookDetail`：
  - 保留现有 Hive 读取 Book 元数据逻辑。
  - 读取文件全文后，不再直接返回单章：
    - 调用 `ChapterParser.parse(book, text)` 得到 `chapters`。
    - 对于没有显式 `title` 的首章，可以使用书名或“序章”作为标题。
  - 返回 `(stored, chapters)`，类型与资产、公版数据源保持一致，方便 `BookRepository` 复用。
- **仓库层无需大改**：`[lib/data/repositories/book_repository.dart](lib/data/repositories/book_repository.dart)` 已经根据 `BookSourceType.localFile` 调用 `LocalBookDataSource.loadBookDetail` 并缓存 `List<Chapter>`，只需确保缓存键仍是 `book.id` 即可。

### 2. Reader 状态扩展：支持分页

- **扩展 ReaderState**（`[lib/features/reader/reader_page.dart](lib/features/reader/reader_page.dart)`）：
  - 在 `ReaderState` 中新增字段：
    - `int currentPageIndex`：当前章节内页码（从 0 开始）。
    - `List<int> pageCountPerChapter`：每章节的总页数（可选，初期也可以只记录当前章节的页数）。
  - `copyWith` 同步新增字段。
- **与 ReadingProgress 对齐**（`[lib/data/models/reading_progress.dart](lib/data/models/reading_progress.dart)` 已有 `pageIndex`）：
  - 在 `ReaderController.init()` 中：
    - 读取 `progress.pageIndex`，如果不为空则用作 `currentPageIndex`，否则默认为 0。
  - 在保存进度时（新增方法而不是复用 `updateScroll`）：
    - 新增 `Future<void> updatePage({required int chapterIndex, required int pageIndex})`：
      - 更新 `state.currentChapterIndex`/`state.currentPageIndex`。
      - 向 `ReadingRepository.saveProgress` 写入 `pageIndex`，`scrollOffset` 可置 0。
- **兼容旧数据**：
  - 如果历史进度只有 `scrollOffset`，则按照当前章节长度粗略推一个 `pageIndex`（例如 0），不做精确映射，避免复杂迁移逻辑。

### 3. 分页引擎：根据屏幕尺寸切分页面

- **新增分页工具类**：在 `[lib/features/reader/page_composer.dart](lib/features/reader/page_composer.dart)`（新文件或放在 reader 目录下）实现 `PageComposer`：
  - 定义数据结构：
    - `class PageSlice { final int start; final int end; }`，表示章节正文在字符串中的子区间。
  - 关键 API：
    - `List<PageSlice> paginate({required String text, required TextStyle style, required double maxWidth, required double maxHeight, required EdgeInsets padding});`
  - 实现思路：
    - 使用 `TextPainter`：
      - 每次从 `start` 开始，创建 `TextSpan(text: text.substring(start), style: style)`，在给定 `maxWidth` 下 `layout`。
      - 利用 `getPositionForOffset`/`getOffsetAfter` 等方法估算在 `maxHeight` 内能容纳的最大字符位置，得到 `end`。
      - 循环直至遍历完整个正文，生成若干 `PageSlice`。
    - 对于极短章节仍保证至少一页。
- **ReaderPage 中调用分页**：
  - 将当前基于 `ListView` 的实现重构为：
    - 使用 `LayoutBuilder` 拿到 `constraints`，扣掉顶部章节标题、上下内边距后计算 `pageHeight`。
    - 针对 `state.chapters[state.currentChapterIndex].content` 调用 `PageComposer.paginate`（受 `UserPreference.fontSize/lineHeight` 影响）。
    - 生成 `List<PageSlice>` 并缓存（可以存在组件内部的 `State` 中，也可以通过 `ReaderController` 缓存当前章节页切分）。
  - 使用 `PageView.builder` 构建每一页：
    - 每页内容：
      - 顶部显示章节标题和当前页/总页（例如“1/12”）。
      - 中间为正文文本 `text.substring(slice.start, slice.end)`，应用 `UserPreference` 对应的 `TextStyle`，保证与分页计算一致。
    - `onPageChanged` 中调用 `controller.updatePage`，同步 `currentPageIndex` 与 `ReadingProgress`。

### 4. Reader UI 重构：更像「阅读器」

- **隐藏系统 AppBar，使用沉浸式顶部区域**：
  - 将现有 `AppBar` 替换为：
    - 使用 `Scaffold` 的 `extendBodyBehindAppBar` 或完全移除系统 `appBar`，在 `ReaderPage` 顶部叠加一个自定义半透明栏，显示书名/章节标题及返回按钮。
    - 点击正文区域单击时显示/隐藏顶部/底部栏（类似七猫/起点的交互）。
- **底部阅读工具条**：
  - 在 `ReaderPage` 中加入底部 `AnimatedOpacity` 容器，包含：
    - 当前章节名 + 页进度（例如“第 3 章 · 5/20 页”）。
    - 上一章/目录/下一章按钮：
      - 上/下一章：调用 `ReaderController` 新增的 `goToPrevChapter`/`goToNextChapter`，重置 `currentPageIndex=0` 并重新分页。
      - 目录：弹出全屏/底部 `ModalBottomSheet` 展示章节列表，可点选跳转。
    - 设置按钮：弹出设置面板（见下一条）。
- **阅读设置面板**：
  - 在底部工具条增加“AA”图标，点击后弹出 `BottomSheet`：
    - 字体大小调整（`UserPreference.fontSize`）。
    - 行距调整（`UserPreference.lineHeight`）。
    - 深浅主题切换（`UserPreference.isDarkMode`，简单切背景色与文字色）。
  - 调整偏好后：
    - 通过 `ReaderController` 更新 `UserPreference`（可在 `ReadingRepository` 或独立 `PreferenceRepository` 持久化）。
    - 触发重新分页（重新调用 `PageComposer.paginate`）。
- **保留 AI 功能**：
  - `AI 书摘` 与 `朗读本章` 仍针对 `currentChapterIndex` 工作，不需要内容层面的改动，只是入口从旧 AppBar 移到自定义顶部/底部工具栏中。

### 5. 阅读进度与统计的配合

- **阅读进度存储**：
  - 每次 `onPageChanged` 或切换章节时：
    - 调用 `updatePage` 写入 `ReadingProgress`：`chapterIndex` + `pageIndex`。
    - 将 `scrollOffset` 固定为 0 或用 `pageIndex * pageHeight` 粗略记一份，兼容旧逻辑。
- **阅读统计**：
  - 保留现有 `_recordReadingSession` 实现，统计只与阅读时长相关，不依赖滚动或页数，因此基本无需改动。

### 6. 渐进式兼容与性能注意点

- **兼容资产书与公版 API**：
  - 这些来源本来就以章节形式提供；分页仅在 `ReaderPage` 层做，与数据源无关。
- **性能优化（可选，后续迭代）**：
  - 对于章节极长的小说：
    - 可限制一次分页的最大字符数，超过部分拆成多个“虚拟章节”，以降低单次 `TextPainter` 压力。
    - 或在进入章节时异步后台分页，并在第一页先渲染出来，后续页在滑动时按需补齐。

## 验收标准

- 导入一部长篇 TXT（中文或英文），进入阅读页：
  - 能自动识别并展示章节列表，章节标题基本符合原书结构。
  - 阅读时为横向翻页，切页体验平滑，顶部/底部工具条可显示/隐藏。
  - 关闭应用后再次打开同一本书，可以回到上次阅读的章节与页码。
  - 调整字体大小/行距/夜间模式后，分页重新计算，内容不会出现明显重叠或空白页。
- 现有资产书、公版书、AI 书摘、朗读、本地导入功能均可正常使用，无崩溃。

