#!/bin/bash

# 日志文件
LOG_FILE="/tmp/open-chatgpt.log"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log "========== 脚本开始执行 =========="

# 从 PopClip 环境变量读取选中的内容
TEXT="$POPCLIP_TEXT"
log "选中内容长度: ${#TEXT} 字符"

# 从 PopClip 配置读取 ChatGPT Base URL
CHATGPT_BASE_URL="${POPCLIP_OPTION_CHATGPT_BASE_URL:-https://chatgpt.com/}"
log "ChatGPT Base URL: $CHATGPT_BASE_URL"

# URL 编码 prompt 参数
# 优先使用 python3，如果不可用则使用 perl
# 注意: 这里用退出码而不是输出是否为空来判断成败，
# 因为空选区编码后本身就是空串，不能当作编码失败。
ENCODED_TEXT=$(python3 -c "import sys; from urllib.parse import quote; print(quote(sys.argv[1]))" "$TEXT" 2>/dev/null)
ENCODE_OK=$?

if [[ $ENCODE_OK -ne 0 ]]; then
    log "python3 不可用，尝试使用 perl"
    ENCODED_TEXT=$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$TEXT" 2>/dev/null)
    ENCODE_OK=$?
fi

if [[ $ENCODE_OK -ne 0 ]]; then
    log "错误: 无法进行 URL 编码"
    /usr/bin/osascript -e "display dialog \"URL 编码失败！\\n\\n请确保系统安装了 python3 或 perl。\" buttons {\"OK\"} default button \"OK\" with icon stop"
    exit 1
fi

log "URL 编码完成"

# 构建完整 URL
# 注意: 这里刻意不使用 ChatGPT 原生的 ?q=，也不用通用的 ?prompt=，
# 而是用带前缀的私有 key(injectp / injectport)，统一走自己的 prompt_injector 用户脚本，
# 避免和官方现有/后续新增的参数撞车导致重复注入。
#
# 短文本直接用 ?injectp= 传递；超长文本改用一次性本地 HTTP 服务 + ?injectport=，
# 避免 URL 过长被截断导致中文乱码（与 open-chatgpt-with-prompt.sh 同一套协议）。
PROMPT_PORT="${POPCLIP_OPTION_PROMPT_PORT:-18232}"
MAX_URL_ENCODED_LEN=1500

if [[ ${#ENCODED_TEXT} -le $MAX_URL_ENCODED_LEN ]]; then
    URL="${CHATGPT_BASE_URL}?injectp=${ENCODED_TEXT}"
    log "短文本，使用 ?injectp= 传递"
else
    log "长文本(${#ENCODED_TEXT} > ${MAX_URL_ENCODED_LEN})，启动本地服务 127.0.0.1:${PROMPT_PORT}"
    python3 -c "
import http.server, socketserver, sys
text = sys.stdin.buffer.read()
socketserver.TCPServer.allow_reuse_address = True
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type','text/plain; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin','*')
        self.end_headers()
        self.wfile.write(text)
    def log_message(self, *a): pass
with socketserver.TCPServer(('127.0.0.1', ${PROMPT_PORT}), H) as s:
    s.handle_request()
" <<< "$TEXT" &
    URL="${CHATGPT_BASE_URL}?injectport=${PROMPT_PORT}"
fi

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
