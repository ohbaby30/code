#!/bin/bash
set -e

# 检查是否root
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请用 root 权限运行脚本"
  exit 1
fi

echo ""
echo "=============================="
echo "🚀 Xray+Trojan 一键安装脚本（webroot模式申请证书）"
echo "=============================="
echo ""

# 输入用于申请证书的邮箱
while true; do
  echo "✉️  请输入申请证书的邮箱（必须格式合法）："
  read -rp "> " EMAIL
  if [[ "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo "✅ 邮箱格式正确：$EMAIL"
    break
  else
    echo "❗ 邮箱格式错误，请重新输入"
  fi
done
echo ""

# 输入域名
while true; do
  echo "🌐 请输入你的域名（如 example.com）："
  read -rp "> " DOMAIN
  if [ -n "$DOMAIN" ]; then
    echo "✅ 域名已确认：$DOMAIN"
    break
  else
    echo "❗ 域名不能为空，请重新输入"
  fi
done
echo ""

# 输入UUID
while true; do
  echo "🔑 请输入VLESS UUID（例如：550e8400-e29b-41d4-a716-446655440000）："
  read -rp "> " UUID
  if [ -n "$UUID" ]; then
    echo "✅ UUID已确认：$UUID"
    break
  else
    echo "❗ UUID不能为空，请重新输入"
  fi
done
echo ""

# 输入Trojan密码（隐藏输入）
while true; do
  echo "🔐 请输入Trojan密码（输入时不可见）："
  read -srp "> " TROJAN_PASS
  echo
  if [ -n "$TROJAN_PASS" ]; then
    echo "✅ Trojan密码已确认"
    break
  else
    echo "❗ 密码不能为空，请重新输入"
  fi
done
echo ""

echo "所有输入完成，开始安装部署..."
sleep 2

# 更新系统及安装必要依赖，包括 nginx
echo "📦 更新系统及安装依赖中..."
apt-get update -y
apt-get install -y openssl cron socat curl unzip vim wget nginx

# 确保 nginx 启动并开机自启
# systemctl enable nginx
# systemctl start nginx

# 确保 webroot 目录存在，默认 /var/www/html
if [ ! -d /var/www/html ]; then
  mkdir -p /var/www/html
fi

# 安装 acme.sh 并注册账号
echo "🔐 安装 acme.sh 并注册账号..."
curl https://get.acme.sh | sh -s email="$EMAIL"
export PATH="$HOME/.acme.sh:$PATH"
~/.acme.sh/acme.sh --set-default-ca --server buypass

# 使用 webroot 模式申请证书
echo "📄 为域名 $DOMAIN 使用 webroot 模式申请 ECC 证书..."
~/.acme.sh/acme.sh --issue -d "$DOMAIN" --webroot /var/www/html -k ec-256

chmod 755 "/root/.acme.sh/${DOMAIN}_ecc"
~/.acme.sh/acme.sh --upgrade --auto-upgrade
echo "✅ 证书申请完成"

# 安装 xray
echo "📦 安装 xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root

# 写入 xray 配置文件
echo "📝 生成 xray 配置文件..."
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
            "id": "$UUID",
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
          "alpn": [ "http/1.1" ],
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
            "password": "$TROJAN_PASS"
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

# 设置 xray 开机自启
systemctl enable xray
systemctl enable nginx

echo ""
echo "🎉 安装完成！请执行命令启动服务："
echo "   systemctl restart nginx xray"
echo "网页目录：/var/www/html"
echo "配置文件路径：/usr/local/etc/xray/config.json"
