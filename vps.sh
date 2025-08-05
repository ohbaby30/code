#!/bin/bash
set -e  # 有错就退出

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请使用 root 权限运行本脚本！（如 sudo ./install.sh）"
  exit 1
fi

##############################
## 🧩 第一步：统一收集用户输入
##############################

echo "=============================="
echo "🚀 Xray 搭建开始前，请先输入必要信息："
echo "=============================="

# 输入域名
read -rp "🌐 请输入你的域名（如 example.com）: " DOMAIN
while [ -z "$DOMAIN" ]; do
  read -rp "❗ 域名不能为空，请重新输入: " DOMAIN
done

# 输入 UUID
read -rp "🔑 请输入你的 VLESS UUID: " UUID
while [ -z "$UUID" ]; do
  read -rp "❗ UUID 不能为空，请重新输入: " UUID
done

# 输入 Trojan 密码
read -srp "🔐 请输入你的 Trojan 密码: " TROJAN_PASS
echo
while [ -z "$TROJAN_PASS" ]; do
  read -srp "❗ 密码不能为空，请重新输入: " TROJAN_PASS
  echo
done

echo ""
echo "✅ 信息输入完毕，开始自动部署..."

################################
## 🛠️ 第二步：系统更新 & 工具安装
################################

apt-get update -y
apt-get install -y openssl cron socat curl unzip vim wget

################################
## 🔐 第三步：安装 acme.sh & 申请证书
################################

echo "📦 安装 acme.sh..."
curl https://get.acme.sh | sh -s email=my@example.com
export PATH="$HOME/.acme.sh:$PATH"

~/.acme.sh/acme.sh --set-default-ca --server buypass

echo "📄 正在为 $DOMAIN 申请证书..."
~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone -k ec-256

chmod 755 "/root/.acme.sh/${DOMAIN}_ecc"
~/.acme.sh/acme.sh --upgrade --auto-upgrade

################################
## 🌐 第四步：安装 nginx
################################

apt-get install -y nginx
echo "✅ nginx 安装完成，默认网页目录为：/var/www/html"

################################
## 📦 第五步：安装 xray
################################

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root

################################
## 📝 第六步：生成 xray 配置文件
################################

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

echo "✅ 配置文件已写入：/usr/local/etc/xray/config.json"

################################
## 🚀 第七步：设置开机启动
################################

systemctl enable nginx
systemctl enable xray

echo ""
echo "🎉 安装完成！你现在可以运行以下命令启动服务："
echo "👉 systemctl restart nginx xray"
