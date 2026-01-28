"""

阿里云 ipv6 DDNS域名动态解析

"""

import os
import sys
import json
import time
import logging
import hashlib
import hmac
import base64
import urllib.parse
import subprocess
import socket
import requests
from datetime import datetime

class AliyunDDNSFixed:
    """阿里云DDNS"""
    
    def __init__(self):
        # 自动确定配置路径
        script_dir = os.path.dirname(os.path.abspath(__file__))
        config_file = os.path.join(script_dir, "config.json")
        
        print(f"📂 脚本目录: {script_dir}")
        print(f"📄 配置文件: {config_file}")
        
        self.config_file = config_file
        self.config = self.load_config(config_file)
        self.setup_logging()
        
    def load_config(self, config_file):
        """加载配置文件"""
        print(f"正在加载配置文件: {config_file}")
        
        if not os.path.exists(config_file):
            print(f"❌ 配置文件不存在: {config_file}")
            print("请创建配置文件或运行安装脚本")
            sys.exit(1)
        
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                config = json.load(f)
            
            print("✅ 配置文件加载成功")
            
            # 设置默认值
            defaults = {
                "cache": {
                    "enabled": True,
                    "cached_ip": "",
                    "cache_timestamp": 0
                },
                "logging": {
                    "log_file": "./logs/ddns.log",  # 固定为ddns.log
                    "max_log_days": 30
                }
            }
            
            # 合并默认值
            for key, value in defaults.items():
                if key not in config:
                    config[key] = value
                elif isinstance(value, dict):
                    for sub_key, sub_value in value.items():
                        if sub_key not in config[key]:
                            config[key][sub_key] = sub_value
            
            return config
            
        except json.JSONDecodeError as e:
            print(f"❌ 配置文件格式错误: {str(e)}")
            print("请检查config.json是否为有效的JSON格式")
            sys.exit(1)
        except Exception as e:
            print(f"❌ 加载配置文件失败: {str(e)}")
            sys.exit(1)
    
    def save_config(self):
        """保存配置到文件"""
        try:
            
            """
            # 备份原文件
            backup_file = f"{self.config_file}.backup"
            if os.path.exists(self.config_file):
                import shutil
                shutil.copy2(self.config_file, backup_file)
            """
            
            # 保存配置
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, ensure_ascii=False, indent=2)
            
            return True
        except Exception as e:
            self.logger.error(f"保存配置失败: {str(e)}")
            return False
    
    def setup_logging(self):
        """设置日志"""
        log_config = self.config.get("logging", {})
        log_file = log_config.get("log_file", "./logs/ddns.log")
        
        # 如果是相对路径，转换为绝对路径
        if log_file.startswith("./"):
            script_dir = os.path.dirname(self.config_file)
            log_file = os.path.join(script_dir, log_file[2:])
        
        log_dir = os.path.dirname(log_file)
        
        # 创建日志目录
        os.makedirs(log_dir, exist_ok=True)
        
        # 配置日志
        self.logger = logging.getLogger("AliyunDDNS")
        self.logger.setLevel(logging.INFO)
        
        # 清除已有处理器
        self.logger.handlers.clear()
        
        # 文件处理器 - 使用追加模式
        file_handler = logging.FileHandler(log_file, encoding='utf-8', mode='a')
        file_handler.setLevel(logging.INFO)
        
        # 格式
        formatter = logging.Formatter(
            '%(asctime)s - %(levelname)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        file_handler.setFormatter(formatter)
        
        # 添加处理器
        self.logger.addHandler(file_handler)
        
        # 添加日志分隔线，便于区分不同执行
        self.logger.info("=" * 60)
        self.logger.info(f"阿里云DDNS启动 - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    def check_configuration(self):
        """检查配置是否正确"""
        self.logger.info("检查配置...")
        
        errors = []
        
        # 检查AccessKey
        access_key_id = self.config.get("access_key_id", "")
        access_key_secret = self.config.get("access_key_secret", "")
        
        if not access_key_id or access_key_id.startswith("LTAI5tYourAccessKeyID") or access_key_id == "请修改为您的AccessKey ID":
            errors.append("❌ 请修改config.json中的access_key_id为您自己的阿里云AccessKey ID")
        elif access_key_id.startswith("LTAI5t") and len(access_key_id) > 10:
            self.logger.info(f"✅ AccessKey ID格式正确: {access_key_id[:10]}...")
        else:
            errors.append("❌ AccessKey ID格式不正确")
        
        if not access_key_secret or "YourAccessKeySecret" in access_key_secret or access_key_secret == "请修改为您的AccessKey Secret":
            errors.append("❌ 请修改config.json中的access_key_secret为您自己的阿里云AccessKey Secret")
        elif len(access_key_secret) > 10:
            self.logger.info(f"✅ AccessKey Secret格式正确: {access_key_secret[:10]}...")
        else:
            errors.append("❌ AccessKey Secret格式不正确")
        
        # 检查域名
        main_domain = self.config.get("main_domain", "")
        if not main_domain or main_domain == "yourdomain.com" or main_domain == "请修改为您的域名":
            errors.append("❌ 请修改config.json中的main_domain为您自己的域名")
        else:
            self.logger.info(f"✅ 主域名: {main_domain}")
        
        # 检查子域名
        sub_domains = self.config.get("sub_domains", [])
        if not sub_domains:
            errors.append("❌ 至少需要配置一个子域名")
        else:
            self.logger.info(f"✅ 配置了 {len(sub_domains)} 个子域名")
        
        # 输出结果
        if errors:
            for error in errors:
                self.logger.error(error)
            self.logger.error("配置检查失败，请修复以上问题")
            return False
        else:
            self.logger.info("✅ 配置检查通过")
            return True
    
    def get_public_ip(self):
        """获取公网IPv6地址"""
        self.logger.info("获取公网IPv6地址...")
        
        apis = [
            "https://api64.ipify.org?format=text",
            "https://v6.ident.me", 
            "https://ipv6.icanhazip.com"
        ]
        
        for api in apis:
            try:
                self.logger.debug(f"尝试从 {api} 获取IP")
                response = requests.get(api, timeout=10)
                response.raise_for_status()
                ip = response.text.strip()
                
                # 验证IPv6格式
                if ':' in ip and '.' not in ip:
                    try:
                        socket.inet_pton(socket.AF_INET6, ip)
                        if not ip.startswith('fe80') and ip != '::1':
                            self.logger.info(f"✅ 获取到IPv6地址: {ip}")
                            return ip
                    except socket.error:
                        continue
                        
            except Exception as e:
                self.logger.debug(f"API {api} 失败: {str(e)}")
                continue
        
        # 尝试从系统接口获取
        try:
            cmd = "ip -6 addr show scope global | grep -v deprecated | grep inet6 | awk '{print $2}' | cut -d'/' -f1"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
            
            if result.returncode == 0:
                ips = result.stdout.strip().split('\n')
                for ip in ips:
                    ip = ip.strip()
                    if ip and ':' in ip and not ip.startswith('fe80'):
                        self.logger.info(f"✅ 从系统接口获取到IPv6: {ip}")
                        return ip
        except Exception as e:
            self.logger.debug(f"系统接口获取失败: {str(e)}")
        
        self.logger.error("❌ 无法获取IPv6地址")
        return None
    
    def get_cached_ip(self):
        """从config.json获取缓存的IP"""
        cache_config = self.config.get("cache", {})
        if not cache_config.get("enabled", True):
            return None
        
        cached_ip = cache_config.get("cached_ip", "")
        cache_timestamp = cache_config.get("cache_timestamp", 0)
        
        if cached_ip:
            # 检查缓存时间（24小时）
            if time.time() - cache_timestamp < 86400:
                self.logger.info(f"从配置缓存读取IP: {cached_ip}")
                return cached_ip
            else:
                self.logger.info("配置缓存已过期")
                return None
        
        return None
    
    def save_cached_ip(self, ip):
        """保存IP到config.json的缓存"""
        cache_config = self.config.get("cache", {})
        if not cache_config.get("enabled", True):
            return
        
        # 更新缓存信息
        cache_config["cached_ip"] = ip
        cache_config["cache_timestamp"] = int(time.time())
        self.config["cache"] = cache_config
        
        # 保存到配置文件
        if self.save_config():
            self.logger.info(f"IP保存到配置缓存: {ip}")
        else:
            self.logger.warning(f"保存配置缓存失败")
    
    def aliyun_api_call(self, action, params):
        """调用阿里云API"""
        access_key_id = self.config.get("access_key_id")
        access_key_secret = self.config.get("access_key_secret")
        
        if not access_key_id or not access_key_secret:
            self.logger.error("❌ AccessKey未配置")
            return None
        
        # 公共参数
        common_params = {
            'Format': 'JSON',
            'Version': '2015-01-09',
            'AccessKeyId': access_key_id,
            'SignatureMethod': 'HMAC-SHA1',
            'Timestamp': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
            'SignatureVersion': '1.0',
            'SignatureNonce': str(int(time.time() * 1000)),
            'Action': action,
        }
        
        # 合并参数
        all_params = {**common_params, **params}
        
        # 生成签名
        signature = self._generate_signature(all_params, access_key_secret)
        all_params['Signature'] = signature
        
        # 发送请求
        url = 'https://alidns.aliyuncs.com/'
        
        try:
            self.logger.debug(f"调用API: {action}")
            response = requests.get(url, params=all_params, timeout=15)
            result = response.json()
            
            if 'Code' in result:
                self.logger.error(f"API错误: {result.get('Code')} - {result.get('Message')}")
                return None
            
            return result
        except Exception as e:
            self.logger.error(f"API调用失败: {str(e)}")
            return None
    
    def _generate_signature(self, params, access_key_secret):
        """生成阿里云API签名"""
        # 排序参数
        sorted_params = sorted(params.items())
        
        # 构建待签名字符串
        canonicalized_query_string = ''
        for k, v in sorted_params:
            canonicalized_query_string += '&' + self._percent_encode(k) + '=' + self._percent_encode(str(v))
        
        canonicalized_query_string = canonicalized_query_string[1:]
        
        # 构造StringToSign
        string_to_sign = 'GET&%2F&' + self._percent_encode(canonicalized_query_string)
        
        # 计算签名
        key = access_key_secret + '&'
        signature = hmac.new(key.encode('utf-8'), string_to_sign.encode('utf-8'), hashlib.sha1).digest()
        
        # Base64编码
        signature_base64 = base64.b64encode(signature).decode('utf-8')
        
        return signature_base64
    
    def _percent_encode(self, string):
        """URL编码"""
        result = urllib.parse.quote(string, safe='')
        result = result.replace('+', '%20')
        result = result.replace('*', '%2A')
        result = result.replace('%7E', '~')
        return result
    
    def get_dns_record(self, sub_domain, record_type):
        """获取DNS记录"""
        main_domain = self.config.get("main_domain")
        
        if not main_domain:
            self.logger.error("❌ 主域名未配置")
            return None
        
        params = {
            'DomainName': main_domain,
            'RRKeyWord': sub_domain,
            'Type': record_type,
        }
        
        result = self.aliyun_api_call('DescribeDomainRecords', params)
        
        if result and 'DomainRecords' in result and 'Record' in result['DomainRecords']:
            records = result['DomainRecords']['Record']
            if records:
                return records[0]
        
        return None
    
    def update_dns_record(self, sub_domain, record_type, ip_address):
        """更新DNS记录"""
        main_domain = self.config.get("main_domain")
        full_domain = f"{sub_domain}.{main_domain}" if sub_domain != "@" else main_domain
        
        # 获取现有记录
        record = self.get_dns_record(sub_domain, record_type)
        
        if not record:
            # 创建新记录
            params = {
                'DomainName': main_domain,
                'RR': sub_domain,
                'Type': record_type,
                'Value': ip_address,
            }
            
            result = self.aliyun_api_call('AddDomainRecord', params)
            
            if result and 'RecordId' in result:
                self.logger.info(f"✅ 创建DNS记录: {full_domain} -> {ip_address}")
                return True
            else:
                self.logger.error(f"❌ 创建DNS记录失败: {full_domain}")
                return False
        else:
            # 检查是否需要更新
            if record.get('Value') == ip_address:
                self.logger.info(f"✅ DNS记录未变化: {full_domain} -> {ip_address}")
                return True
            
            # 更新记录
            params = {
                'RecordId': record['RecordId'],
                'RR': sub_domain,
                'Type': record_type,
                'Value': ip_address,
            }
            
            result = self.aliyun_api_call('UpdateDomainRecord', params)
            
            if result and 'RecordId' in result:
                self.logger.info(f"✅ 更新DNS记录: {full_domain} -> {ip_address}")
                return True
            else:
                self.logger.error(f"❌ 更新DNS记录失败: {full_domain}")
                return False
    
    def run(self):
        """运行DDNS更新"""
        try:
            # 1. 检查配置
            if not self.check_configuration():
                return False
            
            # 2. 获取当前IP
            current_ip = self.get_public_ip()
            if not current_ip:
                return False
            
            # 3. 检查IP是否变化
            cached_ip = self.get_cached_ip()
            
            if cached_ip == current_ip:
                self.logger.info("✅ IP地址未变化，无需更新")
                return True
            
            self.logger.info(f"🔄 IP地址变化: {cached_ip or '无缓存'} -> {current_ip}")
            
            # 4. 更新所有子域名
            success_count = 0
            fail_count = 0
            sub_domains = self.config.get("sub_domains", [])
            
            for domain in sub_domains:
                if not domain.get("enabled", True):
                    continue
                
                sub_domain = domain["name"]
                record_type = domain.get("record_type", "AAAA")
                comment = domain.get("comment", "")
                
                self.logger.info(f"处理域名: {sub_domain} ({comment})")
                
                if self.update_dns_record(sub_domain, record_type, current_ip):
                    success_count += 1
                else:
                    fail_count += 1
            
            # 5. 如果更新成功，保存缓存
            if success_count > 0:
                self.save_cached_ip(current_ip)
            
            # 6. 如果需要重启服务
            service_config = self.config.get("service_restart", {})
            if success_count > 0 and service_config.get("enabled", False):
                services = service_config.get("services", ["nginx", "bt"])
                delay = service_config.get("delay", 10)
                
                self.logger.info(f"等待 {delay} 秒后重启服务...")
                time.sleep(delay)
                
                for service in services:
                    self.logger.info(f"重启服务: {service}")
                    try:
                        if service == "nginx":
                            subprocess.run(['service', 'nginx', 'restart'], check=True)
                        elif service == "bt":
                            subprocess.run(['bt', 'restart'], check=True)
                        elif service == "apache":
                            subprocess.run(['service', 'apache2', 'restart'], check=True)
                        self.logger.info(f"✅ 服务 {service} 重启成功")
                    except Exception as e:
                        self.logger.error(f"❌ 重启服务 {service} 失败: {str(e)}")
            
            # 7. 输出结果
            self.logger.info("=" * 60)
            self.logger.info(f"更新完成: 成功 {success_count} 个，失败 {fail_count} 个")
            
            return fail_count == 0
            
        except Exception as e:
            self.logger.error(f"❌ DDNS运行失败: {str(e)}")
            import traceback
            self.logger.error(traceback.format_exc())
            return False

def main():
    """主函数"""
    try:
        ddns = AliyunDDNSFixed()
        success = ddns.run()
        
        if success:
            print("✅ DDNS更新成功")
            sys.exit(0)
        else:
            print("❌ DDNS更新失败")
            sys.exit(1)
            
    except KeyboardInterrupt:
        print("\n程序被用户中断")
        sys.exit(130)
    except Exception as e:
        print(f"❌ 程序运行异常: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()