---
name: network-and-logging-hardening
overview: Introduce proper HTTP client, error handling, and logging/UX feedback around network requests so that online reading failures are visible and diagnosable instead of just showing a spinner.
todos:
  - id: net-client
    content: 创建统一 ApiClient（基于 Dio 或 http）并配置超时、日志
    status: completed
isProject: false
---

## 目标

- **引入一致的网络访问层**（基于 Dio 或封装好的 `http`），集中配置超时、重试、拦截器等，而不是到处裸 `http.get`。
- **增加日志与错误可视化**：网络失败/解析异常时既能在控制台看到详细日志，也能在 UI 上快速提示用户，而不是无限菊花。

## 架构分析

- 当前网络调用都在 `GutendexBookDataSource` 中直接使用 `package:http`：

```90:151:lib/data/datasources/remote/gutendex_book_data_source.dart
final response = await _client.get(uri);
if (response.statusCode != 200) return const [];
...
final textResponse = await _client.get(Uri.parse(textUrl));
if (textResponse.statusCode != 200) {
  return (_bookFromGutendex(decoded, apiBookId), const <Chapter>[]);
}
```

- **问题点**：
  - 无统一超时配置：如果目标站点卡住，UI 只会一直菊花转。
  - 无日志：失败时直接返回空列表，控制台看不到 URL、状态码、报错栈，难以排查。
  - UI 层（`HomePage` / `ReaderPage`）只根据 `books.isEmpty` / `chapters.isEmpty` 做静态文案，不知道是“真没书”还是“网络挂了”。

## 设计思路

- **网络层**：
  - 新增一个简单的 `ApiClient` 抽象，例如 `lib/core/network/api_client.dart`：
    - 封装 Dio（或继续用 `http` 但加上统一超时 + 拦截器式日志）。
    - 所有远程数据源（当前只有 `GutendexBookDataSource`，未来可能还有别的）都通过它发请求。
  - 统一在这里做：
    - 请求/响应日志打印（URL、query、status、body 长度、耗时）。
    - 超时设置（比如连接 5s、响应 15s）。
    - 错误归一化成自定义异常，如 `NetworkException`、`ServerException`、`ParsingException`。
- **数据源层（`GutendexBookDataSource`）**：
  - 将现在的 `http.Client` 替换为注入的 `ApiClient`：
    - `searchRemote` 和 `fetchPublicDomainBook` 都捕获异常并向上抛或返回失败态。
  - 对典型错误加日志：
    - 无法解析 JSON / 文本时，打印 bookId、响应截断片段。
- **仓库层（`BookRepository`）**：
  - 在 `searchBooks` / `getChaptersForBook` 中捕获网络异常：
    - 将错误包装到一个自定义类型（例如 `BookLoadException`）或直接 rethrow，由上层 Provider 通过 `AsyncError` 暴露。
- **UI 层反馈**：
  - `HomePage` 中的 `_bookListProvider` 已经是 `FutureProvider<List<Book>>`，可以通过 `.when(error: ...)` 显示错误文案和重试按钮：

```277:284:lib/features/home/home_page.dart
error: (error, stackTrace) {
  return Center(
    child: Text(
      '加载书库失败：$error',
      textAlign: TextAlign.center,
    ),
  );
},
```

- 计划：
  - 将 `error` 分情况展示，例如网络错误显示“网络异常，请检查网络或稍后重试”，并提供“重试”按钮触发 `ref.refresh(_bookListProvider)`。
  - 在 `ReaderPage` 中，如果 `getChaptersForBook` 抛出异常，则在 body 中显示错误提示 + 重试/返回按钮，而不是直接落入“本书暂无可阅读章节”。

## 具体实施步骤

1. **引入 Dio + 基础 ApiClient**
  - 在 `pubspec.yaml` 中添加 `dio` 依赖（或决定继续用 `http`，但创建 `ApiClient` 封装）。
  - 新建 `[lib/core/network/api_client.dart]`：
    - 负责构建 Dio 实例，设置 base options（超时、headers）、日志拦截器（打印 URL、statusCode、耗时、错误）。
    - 提供 `getJson`, `getText` 等方法，统一抛出自定义异常。
2. **改造 GutendexBookDataSource**
  - 将构造函数改为接收 `ApiClient` 而非 `http.Client`：
    - `searchRemote` 使用 `apiClient.getJson('/books', query: {...})`。
    - `fetchPublicDomainBook` 使用 `apiClient.getJson('/books/$id')` 和 `apiClient.getText(textUrl)`。
  - 遇到非 200 或解析失败时：
    - 打日志（由 ApiClient 拦截器输出），并抛出 `NetworkException` / `ParsingException`。
3. **在 BookRepository 中传递错误**
  - `searchBooks` 中：
    - `remoteSource.searchRemote` 用 `try/catch` 包一下，将异常 rethrow 或转换成描述性错误信息，让上层 Provider 能拿到。
  - `getChaptersForBook` 中：
    - 对 `fetchPublicDomainBook` 的异常进行捕获并向上抛出（让阅读页能知道是网络问题，而不是章节为空）。
4. **UI 层错误反馈与重试**
  - `HomePage`：
    - 在 `booksAsync.when(error: ...)` 里根据错误类型显示不同提示，并提供“重试”按钮（`onPressed: () => ref.refresh(_bookListProvider)`）。
  - `ReaderPage`：
    - 为 `ReaderState` 增加 `errorMessage` 字段，`ReaderController.init` 捕获异常后写入错误信息。
    - `build` 方法根据 `state.errorMessage` 渲染一个错误占位（提示 + 重试按钮调用 `controller.init()`）。
5. **日志调试说明**
  - 在 `README` 增加简短一节：
    - 说明网络日志打印位置（Dio 拦截器）、调试方法（在控制台看 URL/状态码）。
    - 提醒开发环境确保有 `INTERNET` 权限（Android Debug/Profile Manifest 已配）。

这样改完后：

- 请求挂起/超时时不会无限菊花，会有超时异常 + 明确提示；
- 控制台能看到具体的 URL、状态码和错误信息，便于你快速判断是自己的解析问题，还是对方服务问题。

