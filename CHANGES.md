# InkMind 全网搜索功能 - 修改摘要

## 功能概述

实现了全网搜索功能，允许用户：
- 🔍 搜索全网公开的网页内容
- 📖 直接在应用内阅读网页文章
- 💾 自动缓存内容，支持离线阅读
- 📚 将搜索结果添加到书架

## 新增文件

### 数据源层
1. `lib/data/datasources/remote/search_engine_data_source.dart`
   - 搜索引擎数据源抽象接口
   - 定义 SearchResult 和 BookContent 模型

2. `lib/data/datasources/remote/serpapi_search_data_source.dart`
   - SerpAPI 搜索引擎实现
   - 支持 Google 搜索结果
   - 需要配置 SerpAPI Key

3. `lib/data/datasources/remote/universal_web_crawler_data_source.dart`
   - 通用网页爬虫实现（推荐）
   - 使用 DuckDuckGo 免费搜索
   - 无需 API Key
   - 支持多种搜索引擎（DuckDuckGo、SearX、Bing）

### 服务层
4. `lib/features/search/web_search_service.dart`
   - 搜索服务层
   - Riverpod 状态管理
   - 多数据源并行搜索

### UI 层
5. `lib/features/search/web_search_page.dart`
   - 搜索页面
   - 搜索栏和结果列表
   - 添加到书架功能

6. `lib/features/search/web_content_reader.dart`
   - 网页内容阅读器
   - 章节切换
   - 字体大小调整
   - 章节列表

### 文档
7. `docs/web_search_setup.md`
   - 功能使用指南
   - API Key 配置说明
   - 故障排除

## 修改文件

1. `lib/core/network/api_client.dart`
   - 添加公开的 `dio` getter

2. `lib/features/home/home_page.dart`
   - 添加全网搜索入口按钮

## 技术架构

```
用户操作
    ↓
WebSearchPage (UI)
    ↓
SearchNotifier (Riverpod State)
    ↓
WebSearchService
    ↓
UniversalWebCrawlerDataSource / SerpApiSearchDataSource
    ↓
WebCrawler / SerpAPI
    ↓
网页内容 / 搜索结果
```

## 关键特性

### 1. 智能内容提取
- 自动识别网页正文区域
- 过滤广告、导航栏等无关内容
- 支持多种 HTML 结构

### 2. 本地缓存
- 搜索结果缓存 6 小时
- 网页内容缓存 7 天
- Hive 本地持久化存储

### 3. 内容处理
- 自动识别章节标题
- 智能分段显示
- 长文平均分割

### 4. 多数据源支持
- DuckDuckGo（默认，免费）
- SerpAPI（可选，更准确）
- 可扩展其他搜索引擎

## 使用方式

1. 打开应用
2. 点击右上角 "全网搜索" 图标
3. 输入关键词搜索
4. 点击结果开始阅读

## 配置选项

### 使用免费爬虫（默认）
```dart
WebSearchService(
  useSerpApi: false,
)
```

### 使用 SerpAPI
1. 前往 https://serpapi.com 注册
2. 获取 API Key
3. 配置：
```dart
WebSearchService(
  serpApiKey: 'your-api-key',
  useSerpApi: true,
)
```

## 已知限制

1. 某些网站有反爬机制，无法直接获取内容
2. DuckDuckGo 搜索结果可能不如商业 API 准确
3. 内容提取依赖网页结构，复杂页面可能提取不完整

## 后续优化方向

1. 添加更多搜索引擎（百度、Bing API）
2. 增强内容提取算法（使用 Readability.js）
3. 支持 JavaScript 渲染的页面
4. 添加搜索历史记录和收藏功能
