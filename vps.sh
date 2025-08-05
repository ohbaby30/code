#!/bin/bash

set -e  # 出错时终止脚本

# 检查是否以 root 身份运行
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请以 root 身份运行此脚本（例如 sudo ./install-vps.sh）"
  exit 1
fi

echo "🚀 开始搭建 VPS 环境..."

############### 第一步：更新系统并安装工具 #################

echo "🛠️ 正在安装必要工具..."
apt-get update -y
apt-get install -y openssl cron socat curl unzip vim wget

############### 第二步：安装 acme.sh #################

echo "🔐 正在安装 acme.sh..."
curl https://get.acme.sh | sh -s email=my@example.com
export PATH="$HOME/.acme.sh:$PATH"

if [ ! -f "$HOME/.acme.sh/acme.sh" ]; then
  echo "❌ acme.sh 安装失败，请检查网络！"
  exit 1
fi

~/.acme.sh/acme.sh --set-default-ca --server buypass

# 输入域名
read -rp "🌐 请输入你的域名（如：example.com）: " DOMAIN
while [ -z "$DOMAIN" ]; do
  read -rp "❗ 域名不能为空，请重新输入: " DOMAIN
done

# 申请证书
echo "📄 正在为 $DOMAIN 申请证书..."
~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone -k ec-256

# 设置证书权限
chmod 755 "/root/.acme.sh/${DOMAIN}_ecc"

# 设置自动更新
~/.acme.sh/acme.sh --upgrade --auto-upgrade

############### 第三步：安装 nginx #################

echo "🌐 正在安装 nginx..."
apt update && apt install -y nginx

echo "✅ nginx 安装成功，请根据需要自行修改网站内容：/var/www/html"

############### 第四步：安装 xray #################

echo "📦 正在安装 xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root

############### 第五步：生成配置 #################

# 输入 UUID
read -rp "🔑 请输入 VLESS 的 UUID（推荐使用 https://www.uuidgenerator.net/ 生成）: " VLESS_ID
while [ -z "$VLESS_ID" ]; do
  read -rp "❗ UUID 不能为空，请重新输入: " VLESS_ID
done

# 输入 Trojan 密码
read -srp "🔐 请输入 Trojan 的密码: " TROJAN_PASSWORD
echo
while [ -z "$TROJAN_PASSWORD" ]; do
  read -srp "❗ 密码不能为空，请重新输入: " TROJAN_PASSWORD
  echo
done

# 生成 xray 配置文件
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
                        "id": "$VLESS_ID",
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
                            "certificateFile": "/root/.acme.sh/${DOMAIN}_ecc/fullchain.cer",
                            "keyFile": "/root/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key"
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
                        "password": "$TROJAN_PASSWORD"
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

echo "✅ Xray 配置文件已生成！"

############### 第六步：开机自启 #################

echo "🚦 正在设置 nginx 和 xray 开机自启..."
systemctl enable nginx
systemctl enable xray

echo "🎉 搭建完成！你可以使用以下命令启动服务："
echo "👉 systemctl restart nginx xray"
