
echo "========================================"
echo "阿里云DDNS环境检查"
echo "使用: 宝塔软件商店Python项目管理器安装的Python"
echo "日志文件: logs/ddns.log"
echo "日志自动清理: 超过1MB时保留最近100行"
echo "========================================"
echo ""

# 获取脚本所在目录
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "脚本目录: $CURRENT_DIR"
echo ""

# 检查Python项目管理器环境
echo "🐍 检查Python项目管理器环境..."

PYTHON_MANAGER_DIR="/www/server/python_manager"

if [ ! -d "$PYTHON_MANAGER_DIR" ]; then
    echo "❌ 错误: Python项目管理器未安装"
    echo ""
    echo "请按以下步骤操作："
    echo "1. 登录宝塔面板"
    echo "2. 进入'软件商店'"
    echo "3. 搜索'Python项目管理器'"
    echo "4. 点击安装"
    echo "5. 安装完成后，在Python项目管理器中安装Python3版本（推荐3.8+）"
    exit 1
fi

echo "✅ 检测到Python项目管理器: $PYTHON_MANAGER_DIR"

# 查找Python版本
echo "🔍 查找可用的Python版本..."
PYTHON_VERSIONS=$(ls -d "$PYTHON_MANAGER_DIR"/versions/* 2>/dev/null | sort -Vr)

if [ -z "$PYTHON_VERSIONS" ]; then
    echo "❌ 错误: Python项目管理器中未安装任何Python版本"
    echo ""
    echo "请按以下步骤操作："
    echo "1. 打开Python项目管理器"
    echo "2. 点击'Python版本管理'"
    echo "3. 安装一个Python版本（推荐Python 3.8+）"
    exit 1
fi

# 显示可用的Python版本
echo "✅ 可用的Python版本："
for version_dir in $PYTHON_VERSIONS; do
    python_bin="$version_dir/bin/python3"
    if [ -f "$python_bin" ]; then
        version_name=$(basename "$version_dir")
        PYTHON_VERSION=$("$python_bin" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>/dev/null)
        echo "   📦 $version_name -> $PYTHON_VERSION"
    fi
done

# 使用最新版本的Python进行后续检查
LATEST_PYTHON_DIR=$(echo "$PYTHON_VERSIONS" | head -n1)
PYTHON_PATH="$LATEST_PYTHON_DIR/bin/python3"
PIP_PATH="$LATEST_PYTHON_DIR/bin/pip3"

if [ ! -f "$PYTHON_PATH" ]; then
    echo "❌ 错误: 未找到Python3可执行文件"
    exit 1
fi

echo ""
echo "✅ 使用Python: $PYTHON_PATH"
PYTHON_VERSION=$($PYTHON_PATH -c "import sys; print(f'Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')")
echo "   $PYTHON_VERSION"

# 检查requests模块
echo ""
echo "📦 检查requests模块..."
if $PYTHON_PATH -c "import requests" 2>/dev/null; then
    REQUESTS_VERSION=$($PYTHON_PATH -c "import requests; print(f'requests {requests.__version__}')")
    echo "✅ 检测到 $REQUESTS_VERSION"
else
    echo "❌ 缺少requests模块"
    echo ""
    echo "请手动安装requests模块："
    echo ""
    echo "方法一：通过Python项目管理器安装"
    echo "1. 打开Python项目管理器"
    echo "2. 选择对应Python版本"
    echo "3. 点击'模块管理'"
    echo "4. 搜索'requests'并安装"
    echo ""
    echo "方法二：命令行安装"
    if [ -f "$PIP_PATH" ]; then
        echo "   $PIP_PATH install requests"
        echo "   或使用国内镜像源加速："
        echo "   $PIP_PATH install requests -i https://pypi.tuna.tsinghua.edu.cn/simple"
    else
        echo "   请先确保pip已安装，然后运行: pip install requests"
    fi
    echo ""
    echo "注意：必须为当前使用的Python版本安装requests模块"
fi

echo ""

# 检查必要文件
echo "📄 检查必要文件..."

if [ -f "$CURRENT_DIR/ddns.py" ]; then
    echo "✅ 主程序文件: ddns.py"
else
    echo "❌ 缺失: ddns.py"
    echo "请确保主程序文件存在"
    exit 1
fi

if [ -f "$CURRENT_DIR/config.json" ]; then
    echo "✅ 配置文件: config.json"
    
    # 检查配置文件格式
    if $PYTHON_PATH -c "import json; json.load(open('$CURRENT_DIR/config.json'))" 2>/dev/null; then
        echo "✅ 配置文件格式正确"
        
        # 检查关键配置项
        ACCESS_KEY=$(grep -o '"access_key_id": *"[^"]*"' "$CURRENT_DIR/config.json" | cut -d'"' -f4)
        if [[ "$ACCESS_KEY" == "请修改为您的AccessKey ID" || "$ACCESS_KEY" == "LTAI5tYourAccessKeyID" ]]; then
            echo "⚠️  注意: access_key_id 需要修改为您的阿里云AccessKey ID"
        fi
        
        SECRET_KEY=$(grep -o '"access_key_secret": *"[^"]*"' "$CURRENT_DIR/config.json" | cut -d'"' -f4)
        if [[ "$SECRET_KEY" == "请修改为您的AccessKey Secret" || "$SECRET_KEY" == "YourAccessKeySecret" ]]; then
            echo "⚠️  注意: access_key_secret 需要修改为您的阿里云AccessKey Secret"
        fi
        
        DOMAIN=$(grep -o '"main_domain": *"[^"]*"' "$CURRENT_DIR/config.json" | cut -d'"' -f4)
        if [[ "$DOMAIN" == "yourdomain.com" || "$DOMAIN" == "请修改为您的域名" ]]; then
            echo "⚠️  注意: main_domain 需要修改为您的域名"
        fi
    else
        echo "❌ 配置文件格式错误，请检查JSON格式"
    fi
else
    echo "❌ 缺失: config.json"
    echo ""
    echo "请创建配置文件，参考以下内容："
    echo "----------------------------------------"
    cat << 'EOF'
{
  "access_key_id": "请修改为您的AccessKey ID",
  "access_key_secret": "请修改为您的AccessKey Secret",
  "main_domain": "yourdomain.com",
  
  "sub_domains": [
    {
      "name": "@",
      "enabled": true,
      "record_type": "AAAA",
      "comment": "根域名"
    }
  ],
  
  "cache": {
    "enabled": true,
    "cached_ip": "",
    "cache_timestamp": 0
  },
  
  "logging": {
    "log_file": "./logs/ddns.log",
    "max_log_days": 30
  }
}
EOF
    echo "----------------------------------------"
    echo ""
    read -p "是否要创建默认配置文件？(Y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        cat > "$CURRENT_DIR/config.json" << 'EOF'
{
  "access_key_id": "请修改为您的AccessKey ID",
  "access_key_secret": "请修改为您的AccessKey Secret",
  "main_domain": "yourdomain.com",
  
  "sub_domains": [
    {
      "name": "@",
      "enabled": true,
      "record_type": "AAAA",
      "comment": "根域名"
    }
  ],
  
  "cache": {
    "enabled": true,
    "cached_ip": "",
    "cache_timestamp": 0
  },
  
  "logging": {
    "log_file": "./logs/ddns.log",
    "max_log_days": 30
  }
}
EOF
        echo "✅ 已创建默认配置文件: $CURRENT_DIR/config.json"
        echo "请编辑此文件并修改您的阿里云AccessKey和域名"
    fi
fi

if [ -f "$CURRENT_DIR/run.sh" ]; then
    echo "✅ 运行脚本: run.sh"
else
    echo "❌ 缺失: run.sh"
fi

echo ""

# 检查文件权限
echo "🔧 检查脚本权限..."
chmod +x "$CURRENT_DIR/run.sh" 2>/dev/null && echo "✅ run.sh 已设置执行权限"
chmod +x "$CURRENT_DIR/install_fixed.sh" 2>/dev/null && echo "✅ install_fixed.sh 已设置执行权限"

echo ""

# 创建日志目录
echo "📁 创建日志目录..."
mkdir -p "$CURRENT_DIR/logs" && echo "✅ 日志目录: $CURRENT_DIR/logs"
echo "📄 日志文件: $CURRENT_DIR/logs/ddns.log"
echo "📏 自动清理: 超过1MB时保留最近100行（无备份）"

echo ""

echo "========================================"
echo "✅ 环境检查完成"
echo "========================================"
echo ""

# 定时任务设置指导
echo "========================================"
echo "📅 定时任务设置指导"
echo "========================================"
echo ""
echo "为了让DDNS自动更新，您需要在宝塔面板中设置计划任务："
echo ""
echo "1. 打开宝塔面板"
echo "2. 进入'计划任务'"
echo "3. 点击'添加计划任务'"
echo "4. 配置如下："
echo ""
echo "   🔧 任务类型: Shell脚本"
echo "   📝 任务名称: 阿里云DDNS自动更新"
echo "   ⏰ 执行周期: 每5分钟"
echo "   📜 脚本内容:"
echo "   ----------------------------------------"
echo "   bash $CURRENT_DIR/run.sh"
echo "   ----------------------------------------"
echo ""
echo "5. 点击'确定'保存"
echo ""
echo "💡 重要说明："
echo "   - Python环境: 使用Python项目管理器安装的Python"
echo "   - 日志文件: $CURRENT_DIR/logs/ddns.log"
echo "   - 自动清理: 每次运行时检测，超过1MB时保留最近100行"
echo "   - 无备份: 清理时不会创建备份文件"
echo ""
echo "🧪 手动测试运行："
echo "   cd $CURRENT_DIR"
echo "   ./run.sh"
echo ""
echo "📊 查看日志："
echo "   tail -f $CURRENT_DIR/logs/ddns.log"
echo ""
echo "========================================"
echo ""
echo "📋 快速配置检查清单："
echo ""
echo "   ✅ 1. 已安装宝塔面板"
echo "   ✅ 2. 已安装Python项目管理器"
echo "   ✅ 3. 已在Python项目管理器中安装Python3"
echo "   ⚠️  4. 请确保已安装requests模块"
echo "   ✅ 5. 已检查配置文件格式"
echo "   ⚠️  6. 请修改config.json中的以下配置："
echo "      - access_key_id: 阿里云AccessKey ID"
echo "      - access_key_secret: 阿里云AccessKey Secret"
echo "      - main_domain: 您的域名"
echo "   ✅ 7. 已设置脚本执行权限"
echo "   ✅ 8. 已创建日志目录"
echo "   📅 9. 请在宝塔面板设置定时任务"
echo ""
echo "📌 注意事项："
echo "   1. 确保阿里云AccessKey有DNS修改权限"
echo "   2. 确保域名已实名认证并转入阿里云"
echo "   3. 建议定期备份配置文件"
echo "   4. 日志会自动清理，无需手动管理"
echo "   5. 使用Python项目管理器安装的Python，确保requests模块已安装"
echo ""
echo "❓ 常见问题："
echo "   Q: 运行失败，提示'缺少requests模块'"
echo "   A: 请为使用的Python版本安装requests模块"
echo "      通过Python项目管理器的'模块管理'功能安装"
echo ""
echo "   Q: 日志文件在哪里？"
echo "   A: $CURRENT_DIR/logs/ddns.log"
echo ""
echo "   Q: 如何手动更新？"
echo "   A: 执行: cd $CURRENT_DIR && ./run.sh"
echo ""
echo "========================================"
echo "🎉 安装完成！请按照上面的指导配置定时任务。"
echo "========================================"