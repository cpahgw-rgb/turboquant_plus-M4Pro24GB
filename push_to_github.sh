#!/bin/bash
# GitHub 레포 생성 및 푸시 스크립트
# 실행: chmod +x push_to_github.sh && ./push_to_github.sh

set -e

REPO_NAME="turboquant_plus-M4Pro24GB"

echo "=== GitHub 레포 생성 및 푸시 ==="
echo ""

# gh CLI 확인
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI(gh)가 설치되어 있지 않습니다."
    echo "   설치: brew install gh"
    echo "   인증: gh auth login"
    exit 1
fi

# 인증 확인
if ! gh auth status &> /dev/null 2>&1; then
    echo "❌ GitHub에 로그인되어 있지 않습니다."
    echo "   실행: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI 인증 확인됨"

# git 초기화
if [ ! -d .git ]; then
    git init
    echo "✅ git 초기화 완료"
fi

# 레포 생성
echo ""
echo "📦 GitHub 레포 생성 중: $REPO_NAME (public)..."
gh repo create "$REPO_NAME" --public --description "Local LLM setup for Apple M4 Pro 48GB — TurboQuant KV cache compression + MoE models" || {
    echo "ℹ️  레포가 이미 존재할 수 있습니다. 계속 진행합니다."
}

# remote 설정
GITHUB_USER=$(gh api user -q .login)
REMOTE_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"

if git remote get-url origin &> /dev/null 2>&1; then
    git remote set-url origin "$REMOTE_URL"
else
    git remote add origin "$REMOTE_URL"
fi
echo "✅ Remote 설정: $REMOTE_URL"

# 커밋 및 푸시
git add -A
git commit -m "Initial commit: TurboQuant + MoE local LLM setup for M4 Pro 48GB

- setup_turboquant_plus.sh: llama.cpp + TurboQuant Metal kernels (recommended)
- setup_turboquant.sh: MLX-based TurboQuant (Python fallback)
- setup_flash_moe.sh: SSD expert streaming for 397B model
- verify_setup.sh: environment verification
- ANALYSIS_fusion.md: detailed fusion analysis" || {
    echo "ℹ️  변경사항이 없거나 이미 커밋됨"
}

git branch -M main
git push -u origin main

echo ""
echo "✅ 완료! 레포 주소:"
echo "   https://github.com/${GITHUB_USER}/${REPO_NAME}"
echo ""
echo "🔗 바로 열기:"
gh repo view --web
