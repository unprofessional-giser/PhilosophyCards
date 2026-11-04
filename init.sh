#!/bin/bash

# ============================================
# PhilosophyCards - 从零初始化并推送（完整版）
# 用法: ./init.sh <远程仓库地址>
# 例:   ./init.sh git@github.com:unprofessional-giser/PhilosophyCards.git
# 例:   ./init.sh https://github.com/unprofessional-giser/PhilosophyCards.git
# ============================================

set -e  # 任何一步失败就停

REMOTE="$1"

# ---------- 参数检查 ----------
if [ -z "$REMOTE" ]; then
  echo "❌ 请传入远程仓库地址"
  echo ""
  echo "   SSH 方式:"
  echo "   ./init.sh git@github.com:你的用户名/PhilosophyCards.git"
  echo ""
  echo "   HTTPS 方式:"
  echo "   ./init.sh https://github.com/你的用户名/PhilosophyCards.git"
  exit 1
fi

echo "📦 项目: PhilosophyCards"
echo "🔗 远程: $REMOTE"
echo ""

# ---------- Git 身份检查 ----------
echo "🔍 检查 Git 身份..."
if ! git config user.name >/dev/null 2>&1 || ! git config user.email >/dev/null 2>&1; then
  echo ""
  echo "❌ 未配置 Git 身份！请先运行以下命令："
  echo ""
  echo "   git config user.name \"你的名字\""
  echo "   git config user.email \"你的GitHub邮箱\""
  echo ""
  echo "   填完后再重新运行本脚本。"
  exit 1
fi
echo "✅ 身份: $(git config user.name) <$(git config user.email)>"

# ---------- 初始化仓库 ----------
if [ -d ".git" ]; then
  echo "⚠️  已有 .git，跳过初始化"
else
  git init
  git branch -M main
  echo "✅ 仓库初始化完成"
fi

# ---------- .gitignore ----------
if [ ! -f ".gitignore" ]; then
  cat > .gitignore <<'EOF'
.DS_Store
.vscode/
node_modules/
__pycache__/
.env
*.pyc
dist/
build/
Packages/
Package.resolved
EOF
  echo "✅ 已创建 .gitignore"
else
  echo "⚠️  .gitignore 已存在，跳过"
fi

# ---------- 关联远程 ----------
echo "🔗 配置远程仓库..."
git remote remove origin 2>/dev/null || true
git remote add origin "$REMOTE"
echo "✅ 远程仓库已关联"

# ---------- 显示待提交文件 ----------
echo ""
echo "📋 以下文件将被提交："
git add .
git status --short

# ---------- 提交 ----------
echo ""
echo "📝 提交中..."
if git commit -m "Initial commit: PhilosophyCards 概念卡片桌面插件"; then
  echo "✅ 提交成功"
else
  echo ""
  echo "❌ 提交失败（可能无文件变动）"
  exit 1
fi

# ---------- 推送 ----------
echo ""
echo "🚀 推送到远程..."

# 检测是 SSH 还是 HTTPS
if [[ "$REMOTE" == git@* ]]; then
  echo "   检测到 SSH 地址，测试连接..."
  if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "✅ SSH 连接正常"
  else
    echo "⚠️  SSH 可能未配置，如果推送失败请："
    echo "   1. 运行: ssh-keygen -t ed25519 -C \"你的邮箱\""
    echo "   2. 将 ~/.ssh/id_ed25519.pub 内容添加到 GitHub → Settings → SSH keys"
    echo "   或改用 HTTPS 地址重新运行本脚本"
  fi
fi

if git push -u origin main; then
  echo ""
  echo "🎉🎉🎉 推送成功！"
  echo ""
  echo "   去这里看看: ${REMOTE/%.git/}"
  echo "   或: https://github.com/unprofessional-giser/PhilosophyCards"
else
  echo ""
  echo "❌ 推送失败"
  echo ""
  echo "   常见原因："
  echo "   1. SSH 未配置 → 改用 HTTPS 地址重试"
  echo "   2. 远程仓库不为空 → 先运行: git pull --rebase origin main"
  echo "   3. 权限不足 → 检查 GitHub 登录状态"
  echo ""
  echo "   手动重试: git push -u origin main"
  exit 1
fi