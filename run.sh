
# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/ddns.py"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/ddns.log"
MAX_LOG_SIZE_MB=5  # 日志文件最大1MB

echo "========================================"
echo "DDNS运行脚本启动"
echo "脚本目录: $SCRIPT_DIR"
echo "日志文件: $LOG_FILE"
echo "========================================"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 记录本次执行的开始信息到日志文件
echo "========================================" >> "$LOG_FILE"
echo "执行时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
echo "脚本目录: $SCRIPT_DIR" >> "$LOG_FILE"
echo "工作目录: $(pwd)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# 检查日志文件大小并清理（超过1MB时保留最近100行
if [ -f "$LOG_FILE" ]; then
    LOG_SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null || wc -c < "$LOG_FILE" 2>/dev/null)
    LOG_SIZE_MB=$((LOG_SIZE / 1024 / 1024))
    
    if [ "$LOG_SIZE_MB" -ge "$MAX_LOG_SIZE_MB" ]; then
        echo "📦 日志文件大小: ${LOG_SIZE_MB}MB (超过${MAX_LOG_SIZE_MB}MB)，正在清理..."
        echo "📦 日志文件大小: ${LOG_SIZE_MB}MB (超过${MAX_LOG_SIZE_MB}MB)，正在清理..." >> "$LOG_FILE"
        
        # 获取清理前的行数
        OLD_LINES=$(wc -l < "$LOG_FILE" 2>/dev/null)
        
        # 保留最近100行日志，不创建备份
        tail -n 100 "$LOG_FILE" > "$LOG_FILE.tmp"
        mv "$LOG_FILE.tmp" "$LOG_FILE"
        
        # 计算清理后的行数
        NEW_LINES=$(wc -l < "$LOG_FILE" 2>/dev/null)
        NEW_SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null || wc -c < "$LOG_FILE" 2>/dev/null)
        NEW_SIZE_MB=$((NEW_SIZE / 1024 / 1024))
        
        echo "✅ 日志清理完成，从 ${OLD_LINES} 行保留最近 ${NEW_LINES} 行，大小: ${NEW_SIZE_MB}MB"
        echo "✅ 日志清理完成，从 ${OLD_LINES} 行保留最近 ${NEW_LINES} 行，大小: ${NEW_SIZE_MB}MB" >> "$LOG_FILE"
    else
        echo "📦 日志文件大小: ${LOG_SIZE_MB}MB，无需清理"
        echo "📦 日志文件大小: ${LOG_SIZE_MB}MB，无需清理" >> "$LOG_FILE"
    fi
else
    echo "📦 日志文件不存在，将创建新文件"
    echo "📦 日志文件不存在，将创建新文件" >> "$LOG_FILE"
fi

echo "----------------------------------------" >> "$LOG_FILE"

# 检查Python脚本
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "❌ 错误: 主脚本不存在: $PYTHON_SCRIPT"
    echo "❌ 错误: 主脚本不存在: $PYTHON_SCRIPT" >> "$LOG_FILE"
    echo "请在正确的目录中运行此脚本" >> "$LOG_FILE"
    exit 1
fi

# 检查配置文件
CONFIG_FILE="$SCRIPT_DIR/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ 错误: 配置文件不存在: $CONFIG_FILE"
    echo "❌ 错误: 配置文件不存在: $CONFIG_FILE" >> "$LOG_FILE"
    echo "请确保 config.json 文件与脚本在同一目录" >> "$LOG_FILE"
    exit 1
fi

# 查找Python项目管理器安装的Python
# Python项目管理器的Python通常安装在这个目录结构下
PYTHON_MANAGER_DIR="/www/server/python_manager"

if [ -d "$PYTHON_MANAGER_DIR" ]; then
    # 查找最新安装的Python版本
    PYTHON_PATH=""
    
    # 尝试查找Python 3.x的版本（按版本号倒序排列，取最新的）
    for version_dir in $(ls -d "$PYTHON_MANAGER_DIR"/versions/* 2>/dev/null | sort -Vr); do
        python_bin="$version_dir/bin/python3"
        if [ -f "$python_bin" ]; then
            PYTHON_PATH="$python_bin"
            break
        fi
    done
    
    if [ -n "$PYTHON_PATH" ]; then
        echo "✅ 使用Python项目管理器Python: $PYTHON_PATH"
        echo "✅ 使用Python项目管理器Python: $PYTHON_PATH" >> "$LOG_FILE"
    else
        echo "❌ 错误: 在Python项目管理器中未找到Python3" >> "$LOG_FILE"
        echo "请在宝塔软件商店中安装Python项目管理器并安装Python3" >> "$LOG_FILE"
        exit 1
    fi
else
    echo "❌ 错误: Python项目管理器目录不存在" >> "$LOG_FILE"
    echo "请在宝塔软件商店中安装Python项目管理器" >> "$LOG_FILE"
    exit 1
fi

# 检查Python版本
PYTHON_VERSION=$($PYTHON_PATH -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')")
echo "Python版本: $PYTHON_VERSION" >> "$LOG_FILE"

# 检查requests模块
if ! $PYTHON_PATH -c "import requests" 2>/dev/null; then
    echo "❌ 错误: 缺少requests模块" >> "$LOG_FILE"
    echo "请使用Python项目管理器安装requests模块：" >> "$LOG_FILE"
    
    # 尝试获取pip路径
    PIP_PATH="${PYTHON_PATH%/*}/pip3"
    if [ -f "$PIP_PATH" ]; then
        echo "   $PIP_PATH install requests" >> "$LOG_FILE"
    else
        echo "   使用对应Python版本的pip安装: ${PYTHON_PATH/bin/python3/bin/pip3} install requests" >> "$LOG_FILE"
    fi
    exit 1
fi

echo "正在执行DDNS更新..." >> "$LOG_FILE"
echo "----------------------------------------" >> "$LOG_FILE"

# 执行DDNS脚本
cd "$SCRIPT_DIR" || {
    echo "❌ 错误: 无法切换到脚本目录" >> "$LOG_FILE"
    exit 1
}

# 执行Python脚本
$PYTHON_PATH "$PYTHON_SCRIPT"
EXIT_CODE=$?

# 记录结果
echo "----------------------------------------" >> "$LOG_FILE"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ DDNS更新成功" >> "$LOG_FILE"
else
    echo "❌ DDNS更新失败" >> "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"

exit $EXIT_CODE