#!/bin/bash

set -e

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请以 root 权限运行此脚本！"
  exit 1
fi

# 第一步：更新系统并安装必要工具
echo "🛠️ 正在更新系统并安装必要工具..."
apt-get update -y
apt-get install -y openssl cron socat curl unzip vim wget

# 第二步：安装 acme.sh 并申请证书
echo "🔐 正在安装 acme.sh..."
curl https://get.acme.sh | sh -s email=my@example.com
export PATH="$HOME/.acme.sh:$PATH"
if [ ! -f "$HOME/.acme.sh/acme.sh" ]; then
  echo "❌ acme.sh 安装失败，请检查网络或手动安装！"
  exit 1
fi

"$HOME/.acme.sh/acme.sh" --set-default-ca --server buypass

# 用户输入域名
read -rp "🌐 请输入您的域名（例如 example.com）: " DOMAIN
while [ -z "$DOMAIN" ]; do
  read -rp "❗ 域名不能为空，请重新输入: " DOMAIN
done

# 申请证书
echo "📄 正在为 $DOMAIN 申请 ECC 证书..."
"$HOME/.acme.sh/acme.sh" --issue -d "$DOMAIN" --standalone -k ec-256

chmod 755 "$HOME/.acme.sh/${DOMAIN}_ecc"

# 设置 acme 自动更新
"$HOME/.acme.sh/acme.sh" --upgrade --auto-upgrade

# 安装 nginx
echo "📦 安装 nginx..."
apt install -y nginx
echo "✅ nginx 已安装成功，默认站点目录为 /var/www/html"

# 安装 xray
echo "📦 安装 xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root

# 用户输入 UUID
read -rp "🔑 请输入 VLESS 的 UUID（格式如 550e8400-e29b-41d4-a716-446655440000）: " VLESS_ID
while [ -z "$VLESS_ID" ]; do
  read -rp "❗ UUID 不能为空，请重新输入: " VLESS_ID
done

# 用户输入 Trojan 密码
read -srp "🔐 请输入 Trojan 密码: " TROJAN_PASSWORD
echo
while [ -z "$TROJAN_PASSWORD" ]; do
  read -srp "❗ 密码不能为空，请重新输入: " TROJAN_PASSWORD
  echo
done

# 写入配置文件
echo "📝 正在生成 Xray 配置文件..."
cat > /usr/local/etc/xray/config.json << EOF
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

# 启用服务
echo "🔧 设置 nginx 和 xray 开机自启..."
systemctl enable nginx
systemctl enable xray

echo "🎉 安装与配置全部完成！你可以使用以下命令立即重启应用配置："
echo "  👉 systemctl restart nginx xray"
