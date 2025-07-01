#!/bin/bash

# 飛鼠電商自動化系統 - 自動化部署腳本
# 使用方法: ./deploy.sh [staging|production]

set -e  # 如果任何命令失敗，立即退出

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函數：輸出帶顏色的消息
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 檢查參數
ENVIRONMENT=${1:-production}

log_info "🚀 開始部署飛鼠電商自動化系統到 $ENVIRONMENT 環境"

# 檢查必要的工具
log_info "檢查部署工具..."

if ! command -v git &> /dev/null; then
    log_error "Git 未安裝，請先安裝 Git"
    exit 1
fi

if ! command -v node &> /dev/null; then
    log_error "Node.js 未安裝，請先安裝 Node.js 18.x 或更高版本"
    exit 1
fi

if ! command -v vercel &> /dev/null; then
    log_warning "Vercel CLI 未安裝，正在安裝..."
    npm install -g vercel
fi

# 檢查必要的文件
log_info "檢查項目文件..."

required_files=(
    "index.html"
    "vercel.json"
    "package.json"
    "api/browserless-proxy.js"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        log_error "缺少必要文件: $file"
        exit 1
    fi
done

log_success "所有必要文件都存在"

# 檢查 .env 文件
if [ -f ".env" ]; then
    log_info "發現 .env 文件，請確保敏感資訊不會被提交到 Git"
fi

# 驗證 package.json
log_info "驗證 package.json..."
if ! node -e "JSON.parse(require('fs').readFileSync('package.json', 'utf8'))"; then
    log_error "package.json 格式錯誤"
    exit 1
fi

# 驗證 vercel.json
log_info "驗證 vercel.json..."
if ! node -e "JSON.parse(require('fs').readFileSync('vercel.json', 'utf8'))"; then
    log_error "vercel.json 格式錯誤"
    exit 1
fi

# Git 狀態檢查
log_info "檢查 Git 狀態..."
if [ -n "$(git status --porcelain)" ]; then
    log_warning "發現未提交的變更："
    git status --short
    read -p "是否要繼續部署？(y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "部署已取消"
        exit 0
    fi
fi

# 提交變更（如果有的話）
if [ -n "$(git status --porcelain)" ]; then
    log_info "提交變更到 Git..."
    git add .
    git commit -m "Deploy: $(date '+%Y-%m-%d %H:%M:%S')"
    git push
fi

# Vercel 登入檢查
log_info "檢查 Vercel 登入狀態..."
if ! vercel whoami &> /dev/null; then
    log_info "請登入 Vercel..."
    vercel login
fi

# 部署到 Vercel
log_info "部署到 Vercel ($ENVIRONMENT)..."

if [ "$ENVIRONMENT" = "staging" ]; then
    vercel
else
    vercel --prod
fi

# 獲取部署 URL
DEPLOY_URL=$(vercel ls | grep "$(basename "$PWD")" | head -1 | awk '{print $2}')

if [ -n "$DEPLOY_URL" ]; then
    log_success "🎉 部署成功！"
    log_info "部署 URL: https://$DEPLOY_URL"
    
    # 自動開啟瀏覽器（可選）
    if command -v open &> /dev/null; then
        read -p "是否要開啟瀏覽器查看部署結果？(y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open "https://$DEPLOY_URL"
        fi
    fi
else
    log_warning "無法獲取部署 URL，請手動檢查 Vercel 控制台"
fi

# 部署後測試
log_info "執行部署後測試..."

if command -v curl &> /dev/null && [ -n "$DEPLOY_URL" ]; then
    if curl -sf "https://$DEPLOY_URL" > /dev/null; then
        log_success "網站可正常訪問"
    else
        log_error "網站無法訪問，請檢查部署狀態"
    fi
fi

# 顯示後續步驟
log_info "📋 後續步驟："
echo "1. 訪問部署的網站並測試所有功能"
echo "2. 在 Vercel 控制台設置環境變數（如需要）"
echo "3. 配置 API 金鑰和認證資訊"
echo "4. 測試自動化工作流程"
echo "5. 設置監控和警報"

log_success "部署完成！"