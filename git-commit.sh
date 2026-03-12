#!/bin/bash
# Git 提交脚本

set -e

cd "$(dirname "$0")"

# 配置 Git（如果需要）
if ! git config --global user.email >/dev/null 2>&1; then
    git config user.email "developer@inkmind.app"
    git config user.name "InkMind Developer"
fi

# 添加所有改动
echo "📦 添加改动..."
git add -A

# 提交改动
echo "💾 提交改动..."
git commit -m "feat: 实现全网搜索功能

- 添加搜索引擎数据源接口 (SearchEngineDataSource)
- 实现 SerpAPI 搜索数据源（可选，需 API Key）
- 实现通用网页爬虫数据源（免 API Key，基于 DuckDuckGo）
- 添加搜索服务层和状态管理 (Riverpod)
- 创建搜索页面和网页内容阅读器
- 在首页添加全网搜索入口
- 添加 ApiClient dio getter

功能特点：
- 支持全网搜索任意网页内容
- 本地缓存搜索结果（6小时）和内容（7天）
- 智能内容提取和章节分割
- 支持离线阅读"

# 推送到远程
echo "🚀 推送到远程仓库..."
git push origin main

echo "✅ 提交完成！"
