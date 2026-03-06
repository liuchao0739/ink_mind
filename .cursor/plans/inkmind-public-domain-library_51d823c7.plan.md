---
name: inkmind-public-domain-library
overview: 替换现有示例书库，预置一批不涉版权的中文公版书（以四大名著等为代表），支持完整阅读体验。
todos:
  - id: replace-demo-books
    content: 移除现有示例小说条目，改为一批中文公版书（含四大名著）的目录配置。
    status: completed
  - id: add-public-domain-json
    content: 为选定的公版书编写章节 JSON 数据文件，保证若干长篇可相对完整阅读。
    status: completed
  - id: verify-reading-flow
    content: 在新书库下全面验证搜索、书架、阅读器、TTS、AI 书摘和统计等完整阅读流程。
    status: completed
isProject: false
---

## 墨智本地公版书库改造计划

### 一、目标与范围

- **目标**：
  - 移除当前自创/占位性质的示例书（如“墨海古今录”“星河边界笔记”），避免混淆评委。  
  - 预置一批**不涉及版权的中文公版书**，至少涵盖 10–20 本，保证其中 3–5 本长篇可“相对完整阅读”（章节较全），用于演示完整体验。  
  - 保持现有架构与 AI 功能（智荐、智记、智声、阅读画像）不变，只替换和扩展书库数据。
- **范围限制**：
  - 仅使用**版权已过期的原著**（如清代及更早作品），避免现代译本版权问题；
  - 优先中文原著，如：四大名著、部分古典小说/散文集等，不引入外文作品的中文翻译。

### 二、书目规划（建议）

- **重点长篇（尽量完整）**：
  - 《西游记》（节选版但章节较多，如前 30–40 回）
  - 《水浒传》（节选版，多数关键故事情节）
  - 《三国演义》（节选版，保证主要剧情链条完整）
  - 《红楼梦》（前 40 回为主，兼顾体积）
- **中短篇/选集（用于丰富类别）**：
  - 《聊斋志异》选篇集（若干经典故事，如《聂小倩》《画皮》《莲香》等）
  - 《儒林外史》节选章节
  - 若干古文选（可按“先秦诸子”“唐宋小品文”等分卷）
- 每本书在 `catalog.json` 中标注：`id`、`title`、`author`、`category`（如“古典名著/志怪/讽刺小说”）、`tags`、`wordCount` 估算、`status`、`intro` 等，以方便智荐和搜索。

### 三、数据结构与文件组织

- **文件布局**（复用现有结构）：
  - 目录：`[assets/books/](assets/books/)`  
  - 总目录：`[assets/books/catalog.json](assets/books/catalog.json)`  
  - 每本书一个详情文件：`assets/books/{bookId}.json`，结构类似现有：
    - `book`: 与 `Book` 模型对应的元数据；
    - `chapters`: 数组，每个元素含 `id`、`bookId`、`index`、`title`、`content`。
- **章节拆分策略**：
  - 对于长篇（如四大名著）：
    - 使用“回目/章节名”作为 `title`；
    - 将正文按“回”拆分，每回一章，保证阅读流畅；
    - 如果完整收录体积过大，可优先保留核心剧情章节，剩余章节后续补充。
  - 对于短篇集（如《聊斋志异》选篇）：
    - 每篇故事一个 `Chapter`，`title` 为篇名；
    - `content` 为该篇完整文本。

### 四、与现有代码的衔接点

- **Book 模型与加载逻辑**
  - 模型已存在于 `[lib/data/models/book.dart](lib/data/models/book.dart)`，字段满足新书需求：`id/title/author/category/tags/wordCount/status/intro/sourceType` 等。  
  - `[lib/data/datasources/local_assets/book_asset_data_source.dart](lib/data/datasources/local_assets/book_asset_data_source.dart)` 中 `loadCatalog()` 将从 `catalog.json` 读入书目并通过 `Book.fromJson` 解析；保持接口不变，仅替换数据源内容即可。
- **书库与搜索**
  - `[lib/data/repositories/book_repository.dart](lib/data/repositories/book_repository.dart)` 的 `getAllBooks()` / `searchBooks()` 已实现基于 `Book` 列表的本地搜索；
  - 新书目加入后，`HomePage`（`[lib/features/home/home_page.dart](lib/features/home/home_page.dart)`）的“全部书库”和“智荐”为新的公版书服务，无需改逻辑。
- **阅读器与进度**
  - 阅读器 `ReaderPage` 使用 `Chapter` 的 `content` 字段展示正文（当前已在 `[lib/data/models/chapter.dart](lib/data/models/chapter.dart)` 中定义）；
  - 只要各书的 `chapters` 数组填充正确，即可直接享受现有的进度记录、TTS 朗读和 AI 书摘等能力。

### 五、具体实施步骤

1. **清理现有示例书**
  - 调整 `[assets/books/catalog.json](assets/books/catalog.json)`：
    - 暂时移除或注释掉当前的“墨海古今录”“星河边界笔记”等自创书籍条目；
    - 保留或替换为新的公版书条目列表。
  - 若不再需要原 demo 书的详情文件（如 `inkmind_classic_tales.json` 等），可以在后续阶段考虑删除以减小体积（注意先从 `catalog.json` 剔除引用）。
2. **准备公版书 JSON 数据**
  - 为每本选定公版书手动或脚本化生成 `{bookId}.json` 文件，内容包括：
    - `book` 元数据：书名、作者（例如“施耐庵”“罗贯中”等）、分类和简介；
    - `chapters`：按章节/回目拆分的正文文本。
  - 为了便于演示，可以先重点完成 3–5 本长篇的前若干十回（保证 Demo 中能充分滚动、跳转章节），再补充其它书目的若干章节。
3. **维护目录文件 `catalog.json`**
  - 将所有公版书的 `book` 元数据整理进 `books` 数组，每个对象包含：
    - `id`（与详情文件中的 bookId 一致）；
    - `title`、`author`、`category`、`tags`；
    - `wordCount` 估算值（可根据章节字数总和粗略填充）；
    - `status`（如 `completed`）；
    - `intro`（简短的书籍介绍）；
    - `sourceType`: 固定为 `asset`；
    - `heatScore`: 简单排序用的热度分值，可按名气和希望展示优先级手动设置。
  - 对于未来可能接入线上公版 API 的书，可以先不在 `catalog.json` 中出现，等远程方案确定后再加入。
4. **验证阅读体验**
  - 本地跑起 Flutter 应用：
    - 确认首页“全部书库”中能看到新增的公版书列表；
    - 随机选择几本书，进入阅读器，检查章节标题与正文是否正确；
    - 验证：
      - 加入/移除书架；
      - 退出后再次进入是否正确恢复阅读进度；
      - TTS 朗读与 AI 书摘在这些公版书上是否可以正常工作（至少保证不会报错）；
      - 阅读统计页面是否能正确计入这些书的阅读时长。
5. **（可选）为四大名著增加 AI 书摘示例**
  - 对于部分章节（如《西游记》第一回、《三国演义》第一回等），在 `assets/books/{bookId}_highlights.json` 中预置高质量书摘，类似现有 demo 结构；
  - 这样在 Demo 中点“本章书摘（智记）”时，不仅有规则抽取的句子，还有手工优化的“AI 摘要/金句”，更有说服力。

### 六、对大赛材料的补充点

- 在 PPT 中新增一页“公版书源与版权策略”：
  - 说明应用内预置书籍全部为版权已到期的中文古典名著，或你自己创作的内容；
  - 强调热门现代作品（如《三体》《剑来》）采用“官方链接 + 本地导入”的双路径，不抓取、不缓存正文；
  - 结合本地阅读体验截图，展示完整流程：搜索 → 加书架 → 打开章节 → 智声朗读 → 智记书摘 → 阅读画像。

