#!/bin/bash

# 日志文件
LOG_FILE="/tmp/send-to-claude.log"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log "========== 脚本开始执行 =========="

# 保存选中内容到临时文件
TEMP_FILE="/tmp/claude-context-$(date +%s).txt"

# 从 PopClip 环境变量读取选中的内容
echo "$POPCLIP_TEXT" > "$TEMP_FILE"
log "已保存选中内容到: $TEMP_FILE"
log "内容长度: ${#POPCLIP_TEXT} 字符"

# 清理超过1天的旧临时文件
find /tmp -name "claude-context-*.txt" -mtime +1 -delete 2>/dev/null

# 从 PopClip 配置读取延迟时间，默认 2.5 秒
DELAY_TIME=${POPCLIP_OPTION_DELAY_TIME:-2.5}
log "延迟时间: ${DELAY_TIME} 秒"

# 使用 AppleScript 创建新的 iTerm2 窗口并执行命令
log "开始执行 AppleScript..."

APPLESCRIPT_OUTPUT=$(/usr/bin/osascript 2>&1 <<APPLESCRIPT
tell application "iTerm"
    -- 使用 claude profile 创建新窗口
    set newWindow to (create window with profile "claude")

    -- 在新窗口中执行命令
    tell current session of newWindow
        -- 先查看文件内容
        write text "cat ${TEMP_FILE}"
        delay 0.5
        -- 然后执行 claude code 命令
        write text "claude code"
        delay ${DELAY_TIME}
        write text "@${TEMP_FILE}"
    end tell
end tell
APPLESCRIPT
)

APPLESCRIPT_EXIT_CODE=$?
log "AppleScript 退出码: $APPLESCRIPT_EXIT_CODE"
log "AppleScript 输出: $APPLESCRIPT_OUTPUT"

if [ $APPLESCRIPT_EXIT_CODE -ne 0 ]; then
    log "错误: AppleScript 执行失败"
    /usr/bin/osascript -e "display dialog \"AppleScript 执行失败！\n\n错误信息: $APPLESCRIPT_OUTPUT\n\n日志文件: /tmp/send-to-claude.log\" buttons {\"OK\"} default button \"OK\" with icon stop"
    exit 1
fi

log "AppleScript 执行完成"
log "========== 脚本执行结束 =========="
