# InkMind 全网搜索功能使用指南

## 功能概述

全网搜索功能允许你：
- 🔍 搜索全网公开的网页内容
- 📖 直接在应用内阅读网页文章
- 💾 自动缓存内容，支持离线阅读
- 📚 将搜索结果添加到书架

## 实现架构

### 新增文件
```
lib/
├── data/datasources/remote/
│   ├── search_engine_data_source.dart      # 搜索引擎数据源接口
│   ├── serpapi_search_data_source.dart     # SerpAPI 搜索实现
│   └── universal_web_crawler_data_source.dart  # 通用爬虫（免 API Key）
├── features/search/
│   ├── web_search_service.dart             # 搜索服务层
│   └── web_search_page.dart                # 搜索页面 UI
└── features/home/home_page.dart            # 添加搜索入口
```

## 使用方式

### 方式一：使用免费爬虫（推荐，无需 API Key）

默认使用 DuckDuckGo 搜索引擎，无需申请任何 API Key。

```dart
// 在 WebSearchService 中
WebSearchService(
  useSerpApi: false,  // 不使用 SerpAPI
)
```

### 方式二：使用 SerpAPI（搜索结果更准确）

1. 前往 https://serpapi.com 注册账号
2. 获取 API Key
3. 在代码中配置：

```dart
WebSearchService(
  serpApiKey: 'your-serpapi-key',
  useSerpApi: true,
)
```

## 功能特点

### 1. 智能内容提取
- 自动识别网页正文内容
- 过滤广告和导航栏
- 支持多种网页结构

### 2. 本地缓存
- 搜索结果缓存 6 小时
- 网页内容缓存 7 天
- 支持离线阅读

### 3. 内容分段
- 自动识别章节标题
- 支持长文分段阅读
- 智能分页显示

## 使用步骤

1. **打开应用** → 点击右上角 "全网搜索" 图标
2. **输入关键词** → 搜索想看的文章或书籍
3. **点击结果** → 等待内容加载
4. **开始阅读** → 支持添加到书架

## 注意事项

⚠️ **免责声明**
- 本功能仅供个人学习研究使用
- 请遵守相关法律法规
- 尊重网站版权和内容使用条款
- 不要频繁请求同一网站，避免被封 IP

## 故障排除

### 搜索不到结果
- 检查网络连接
- 尝试更换关键词
- 确认网站允许爬虫访问

### 内容加载失败
- 某些网站有反爬机制，无法直接获取
- 可以尝试在浏览器中打开原链接
- 支持手动导入本地 TXT 文件阅读

## 后续优化方向

1. **添加更多搜索引擎**
   - Bing API
   - Google Custom Search
   - 百度搜索

2. **增强内容提取**
   - 使用 Readability 算法
   - 支持 JavaScript 渲染的页面
   - 更好的正文识别

3. **功能增强**
   - 搜索历史记录
   - 搜索建议
   - 结果筛选和排序
