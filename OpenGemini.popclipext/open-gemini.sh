#!/bin/bash

# 日志文件
LOG_FILE="/tmp/open-gemini.log"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log "========== 脚本开始执行 =========="

# 从 PopClip 环境变量读取选中的内容
TEXT="$POPCLIP_TEXT"
log "选中内容长度: ${#TEXT} 字符"

# 从 PopClip 配置读取 Gemini Base URL
GEMINI_BASE_URL="${POPCLIP_OPTION_GEMINI_BASE_URL:-https://gemini.google.com/app}"
log "Gemini Base URL: $GEMINI_BASE_URL"

# URL 编码 prompt 参数
# 优先使用 python3，如果不可用则使用 perl
ENCODED_TEXT=$(python3 -c "import sys; from urllib.parse import quote; print(quote(sys.argv[1]))" "$TEXT" 2>/dev/null)

if [[ -z "$ENCODED_TEXT" ]]; then
    log "python3 不可用，尝试使用 perl"
    ENCODED_TEXT=$(perl -MURI::Escape -e "print uri_escape('$TEXT');" 2>/dev/null)
fi

if [[ -z "$ENCODED_TEXT" ]]; then
    log "错误: 无法进行 URL 编码"
    /usr/bin/osascript -e "display dialog \"URL 编码失败！\\n\\n请确保系统安装了 python3 或 perl。\" buttons {\"OK\"} default button \"OK\" with icon stop"
    exit 1
fi

log "URL 编码完成"

# 构建完整 URL
URL="${GEMINI_BASE_URL}?prompt=${ENCODED_TEXT}"
log "完整 URL: $URL"

# 打开浏览器
log "正在打开浏览器..."
/usr/bin/open "$URL"

if [ $? -eq 0 ]; then
    log "浏览器打开成功"
else
    log "错误: 浏览器打开失败"
    exit 1
fi

log "========== 脚本执行结束 =========="
