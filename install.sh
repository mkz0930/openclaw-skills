#!/bin/bash
# OpenClaw Browser Relay - 一键安装脚本
# 支持自动检测环境 + 下载文件 + 安装依赖

set -e  # 遇到错误立即退出

echo "🚀 OpenClaw Browser Relay - 一键安装"
echo "========================================"

# 检查平台
if [[ "$(uname -s)" != "Linux" ]]; then
    echo "⚠️  本脚本只能在 WSL2/Linux 上运行"
    exit 1
fi

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 未安装，请安装：sudo apt install python3"
    exit 1
fi
echo "✅ Python3 已安装"

# 检查 pip
if ! command -v pip3 &> /dev/null && ! command -v pip &> /dev/null; then
    echo "❌ pip 未安装，请安装：sudo apt install python3-pip"
    exit 1
fi
echo "✅ pip 已安装"

# 安装依赖（使用 --break-system-packages 或虚拟环境）
echo "📦 安装 Python 依赖..."

# 检查是否已有 websockets
if python3 -c "import websockets; print('websockets installed')" 2>/dev/null; then
    echo "✅ websockets 已安装"
else
    echo "💡 创建虚拟环境安装依赖..."
    python3 -m venv /tmp/relay-venv
    /tmp/relay-venv/bin/pip install websockets --quiet
    echo "✅ 虚拟环境已创建：/tmp/relay-venv"
fi

# 检查 WSL2 IP
WSL_IP=$(hostname -I | awk '{print $1}')
if [[ -z "$WSL_IP" ]] || [[ ! "$WSL_IP" =~ ^172\.25\. ]]; then
    echo "⚠️  WSL2 IP 检测失败：$WSL_IP"
    echo "💡 请确认在 WSL2 中运行，并能访问 172.25.0.1"
else
    echo "✅ WSL2 IP: $WSL_IP"
fi

# 创建目录结构
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_DIR="$SCRIPT_DIR/extension"
SERVER_DIR="$SCRIPT_DIR/server"

echo "📁 创建目录结构..."

# 检查 extension 目录
if [[ ! -d "$EXT_DIR" ]]; then
    echo "❌ 扩展目录不存在：$EXT_DIR"
    echo "💡 请从 GitHub 下载完整包"
    exit 1
fi

# 检查 server 目录
if [[ ! -d "$SERVER_DIR" ]]; then
    echo "❌ 服务目录不存在：$SERVER_DIR"
    exit 1
fi

echo "✅ 目录结构正常"

# 启动服务（后台）
echo "🌐 启动 WebSocket Server..."

SERVER_LOG="/tmp/openclaw-relay-server.log"

# 检查是否已在运行
if pgrep -f "python3 server.py" > /dev/null; then
    echo "⚠️  Server 已在运行，跳过启动"
else
    cd "$SERVER_DIR"
    nohup python3 server.py > "$SERVER_LOG" 2>&1 &
    SERVER_PID=$!
    echo "✅ Server 已启动 (PID: $SERVER_PID)"
    echo "   日志：$SERVER_LOG"
    
    # 等待服务启动
    sleep 2
    
    # 验证端口
    if ss -tlnp | grep -q ":19000"; then
        echo "✅ Server 监听端口 19000"
    else
        echo "❌ Server 启动失败，请检查日志：$SERVER_LOG"
        exit 1
    fi
fi

# 检查虚拟环境
if [[ -d "/tmp/relay-venv" ]]; then
    echo "💡 虚拟环境：/tmp/relay-venv (使用此环境运行 Python 脚本)"
fi

# 生成配置文件
echo "📝 生成配置文件..."

CONFIG_FILE="$SCRIPT_DIR/config.json"
cat > "$CONFIG_FILE" << 'EOFCONFIG'
{
    "ws_url": "ws://172.25.0.1:19000",
    "chrome_extension_path": "E:\\openclaw\\extensions\\openclaw-browser-relay\\extension",
    "server_log": "/tmp/openclaw-relay-server.log"
}
EOFCONFIG

echo "✅ 配置文件已生成：$CONFIG_FILE"

# 创建快捷命令
echo "🚀 创建快捷命令..."

_alias_file="$SCRIPT_DIR/.alias.sh"
cat > "$_alias_file" << 'EOFALIAS'
# OpenClaw Browser Relay - 快捷命令
alias relay-status="ss -tlnp | grep :19000"
alias relay-log="tail -f /tmp/openclaw-relay-server.log"
alias relay-stop="pkill -f 'python3 server.py'"

# 测试命令
relay-test() {
    python3 -c "
import asyncio, websockets, json
async def test():
    async with websockets.connect('ws://172.25.0.1:19000') as ws:
        await ws.send(json.dumps({'type': 'agent', 'version': '1.0.0'}))
        msg = await asyncio.wait_for(ws.recv(), timeout=5)
        print('Connected!')
        print(json.loads(msg))
asyncio.run(test())
"
}
EOFALIAS

echo "✅ 快捷命令已生成：$_alias_file"

# 输出下一步
echo ""
echo "========================================"
echo "✅ 安装完成！"
echo "========================================"
echo ""
echo "📋 下一步操作："
echo "1. Windows Chrome 加载 extension 目录"
echo "2. 附加亚马逊标签页（点击插件图标）"
echo "3. 运行：source $_alias_file && relay-test"
echo ""
echo "💡 配置文件：$CONFIG_FILE"
echo "💡 Server 日志：$SERVER_LOG"
echo "💡 虚拟环境：/tmp/relay-venv"
