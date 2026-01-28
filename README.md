# 📡 阿里云DDNS IPv6动态域名解析脚本

一个专为IPv6环境设计的阿里云动态域名解析脚本，完美集成于宝塔面板环境，支持多子域名自动更新。

## ✨ 功能特性

- ✅ **全自动IPv6解析**：自动检测公网IPv6地址变化
- ✅ **多子域名支持**：同时管理根域名、www及其他自定义子域名
- ✅ **智能缓存机制**：避免不必要的API调用，节省资源
- ✅ **宝塔面板集成**：专为宝塔环境优化，使用Python项目管理器
- ✅ **服务联动**：可选DNS更新后自动重启nginx/宝塔等服务
- ✅ **自动日志管理**：日志文件自动轮转，防止过大
- ✅ **错误处理完善**：详细日志记录，便于排查问题

## 📋 系统要求

- **操作系统**：CentOS 7+/Ubuntu 18.04+（推荐）
- **控制面板**：宝塔面板（已安装）
- **Python环境**：宝塔Python项目管理器 + Python 3.8+
- **域名服务**：阿里云域名（已实名认证）

## 🚀 快速开始

### 1. 环境准备
```bash
# 确保已安装宝塔面板和Python项目管理器
# 在Python项目管理器中安装Python 3.8+版本


下载脚本

```bash
cd /www
git clone https://github.com/hia1321/ddns_ipv6.git
cd ddns_ipv6

# 通过Python项目管理器安装requests模块
/www/server/python_manager/versions/3.12.0/bin/pip3 install requests
# 或使用清华镜像加速
/www/server/python_manager/versions/3.12.0/bin/pip3 install requests -i https://pypi.tuna.tsinghua.edu.cn/simple
