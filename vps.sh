#!/bin/bash

set -e  # 出错就退出

# 确保以 root 运行
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请以 root 身份运行此脚本！（例如 sudo ./install-vps.sh）"
  exit 1
fi

####################### 第一步：用户输入信息 #######################

echo "============================="
echo "🚀 VPS 搭建脚本开始执行"
echo "请依次输入以下必要信息："
echo "============================="

# 1. 读取域名
read -rp "🌐 请输入你的域名（如 example.com）: " USER_DOMAIN
while [ -z "$USER_DOMAIN" ]; do
  read -rp "❗ 域名不能为空，请重新输入: " USER_DOMAIN
done

# 2. 读取 UUID
read -rp "🔑 请输入你的 VLESS UUID（推荐使用 https://www.uuidgenerator.net/ 生成）: " USER_UUID
while [ -z "$USER_UUID" ]; do
  read -rp "❗ UUID 不能为空，请重新输入: " USER_UUID
done

# 3. 读取 Trojan 密码
read -srp "🔐 请输入你的 Trojan 密码: " USER_TROJAN
echo
while [ -z "$USER_TROJAN" ]; do
  read -srp "❗ 密码不能为空，请重新输入: " USER_TROJAN
  echo
done

echo "✅ 信息已保存，开始自动部署..."

####################### 第二步：更新系统并安装工具 #######################

echo "🛠️ 正在更新系统并安装必要工具..."
apt-get update -y
apt-get install -y openssl cron socat curl unzip vim wget

####################### 第三步：安装 acme.sh 并申请证书 #######################

echo "🔐 正在安装 acme.sh..."
curl https://get.acme.sh | sh -s email=my@example.com
export PATH="$HOME/.acme.sh:$PATH"

if [ ! -f "$HOME/.acme.sh/acme.sh" ]; then
  echo "❌ acme.sh 安装失败，请检查网络！"
  exit 1
fi

~/.acme.sh/acme.sh --set-default-ca --server buypass

# 申请证书
echo "📄 正在为 $USER_DOMAIN 申请 ECC 证书..."
~/.acme.sh/acme.sh --issue -d "$USER_DOMAIN" --standalone -k ec-256

# 设置权限
chmod 755 "/root/.acme.sh/${USER_DOMAIN}_ecc"

# 设置自动更新
~/.acme.sh/acme.sh --upgrade --auto-upgrade

####################### 第四步：安装 nginx #######################

echo "🌐 正在安装 nginx..."
apt install -y nginx

echo "✅ nginx 安装完成，请根据需要修改网站目录：/var/www/html"

####################### 第五步：安装 xray #######################

echo "📦 正在安装 xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root

####################### 第六步：生成配置文件 #######################

echo "📝 正在生成 Xray 配置文件..."

cat > /usr/local/etc/xray/config.json <<EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$USER_UUID",
                        "flow": "xtls-rprx-direct"
                    }
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": 8388
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "xtls",
                "xtlsSettings": {
                    "alpn": ["http/1.1"],
                    "certificates": [
                        {
                            "certificateFile": "/root/.acme.sh/${USER_DOMAIN}_ecc/fullchain.cer",
                            "keyFile": "/root/.acme.sh/${USER_DOMAIN}_ecc/${USER_DOMAIN}.key"
                        }
                    ]
                }
            }
        },
        {
            "port": 8388,
            "listen": "127.0.0.1",
            "protocol": "trojan",
            "settings": {
                "clients": [
                    {
                        "password": "$USER_TROJAN"
                    }
                ],
                "fallbacks": [
                    {
                        "dest": "80"
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "none"
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF

echo "✅ 配置文件已生成：/usr/local/etc/xray/config.json"

####################### 第七步：开机自启 #######################

echo "🔧 正在设置开机自启..."
systemctl enable nginx
systemctl enable xray

echo "🎉 所有步骤完成！你现在可以运行以下命令启动服务："
echo "👉 systemctl restart nginx xray"
