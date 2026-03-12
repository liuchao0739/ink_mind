#!/bin/bash
# 全网搜索功能提交脚本

echo "正在提交 InkMind 全网搜索功能..."

# 配置 git（如果尚未配置）
if ! git config --global user.email >/dev/null 2>&1; then
  git config --global user.email "developer@inkmind.app"
  git config --global user.name "InkMind Developer"
fi

# 添加所有文件
git add -A

# 创建提交
git commit -m "feat: 实现全网搜索功能

- 添加搜索引擎数据源接口和实现
- 集成 DuckDuckGo 免费搜索（无需 API Key）
- 支持 SerpAPI 高级搜索（需配置 API Key）
- 实现网页内容智能爬取和解析
- 添加本地缓存机制（搜索结果缓存6小时，内容缓存7天）
- 创建搜索页面 UI 和网页内容阅读器
- 在首页添加全网搜索入口

技术细节：
- 使用 Riverpod 管理搜索状态
- 支持 Hive 本地持久化缓存
- 自动章节分割和内容提取
- 响应式搜索界面"

# 推送到远程仓库
git push origin main

echo "提交完成！"
echo ""
echo "已修改的文件："
git log --oneline -1 --name-status
