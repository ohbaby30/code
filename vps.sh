#!/bin/bash
set -e  # 有错误就停止执行

# 检查是否是 root 用户
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请以 root 身份运行本脚本！（例如：sudo ./install.sh）"
  exit 1
fi

echo ""
echo "=============================="
echo "🚀 Xray + Trojan 一键安装脚本"
echo "=============================="
echo ""

##############################################
# 🧩 第一步：让用户输入必要信息（明确停顿 + 确认）
##############################################

# 输入域名
while true; do
  echo -e "🌐 请输入你的域名（如：example.com）："
  read -rp "> " DOMAIN
  if [ -n "$DOMAIN" ]; then
    echo "✅ 域名已确认：$DOMAIN"
    break
  else
    echo "❗ 域名不能为空，请重新输入！"
  fi
done
echo ""

# 输入 UUID
while true; do
  echo -e "🔑 请输入你的 VLESS UUID（如：550e8400-e29b-41d4-a716-446655440000）："
  read -rp "> " UUID
  if [ -n "$UUID" ]; then
    echo "✅ UUID 已确认：$UUID"
    break
  else
    echo "❗ UUID 不能为空，请重新输入！"
  fi
done
echo ""

# 输入 Trojan 密码
while true; do
  echo -e "🔐 请输入你的 Trojan 密码（不会显示内容）："
  read -srp "> " TROJAN_PASS
  echo
  if [ -n "$TROJAN_PASS" ]; then
    echo "✅ Trojan 密码已确认"
    break
  else
    echo "❗ 密码不能为空，请重新输入！"
  fi
done
echo ""
echo "🎯 所有输入已完成，开始执行自动部署..."
sleep 2

##############################################
# 🛠️ 第二步：更新系统并安装工具
##############################################

echo "📦 安装必要系统工具..."
apt-get update -y
apt-get install -y openssl cron socat curl unzip vim wget

##############################################
# 🔐 第三步：安装 acme.sh 并申请证书
##############################################

echo "🔐 安装 acme.sh..."
curl https://get.acme.sh | sh -s email=chinainai0720@google.com
export PATH="$HOME/.acme.sh:$PATH"

if [ ! -f "$HOME/.acme.sh/acme.sh" ]; then
  echo "❌ acme.sh 安装失败，请检查网络！"
  exit 1
fi

~/.acme.sh/acme.sh --set-default-ca --server buypass

echo "📄 为 $DOMAIN 申请 ECC 证书中..."
~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone -k ec-256

chmod 755 "/root/.acme.sh/${DOMAIN}_ecc"
~/.acme.sh/acme.sh --upgrade --auto-upgrade

##############################################
# 🌐 第四步：安装 nginx
##############################################

echo "🌐 安装 nginx..."
apt install -y nginx
echo "✅ nginx 安装完成，网站目录位于 /var/www/html，请根据需要自行修改页面"

##############################################
# 📦 第五步：安装 Xray
##############################################

echo "📦 安装 Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root

##############################################
# 📝 第六步：生成 Xray 配置文件
##############################################

echo "📝 正在写入配置文件..."

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

echo "✅ 配置文件写入成功：/usr/local/etc/xray/config.json"

##############################################
# 🚀 第七步：设置开机自启
##############################################

systemctl enable nginx
systemctl enable xray

echo ""
echo "🎉 所有安装已完成！你现在可以执行以下命令启动服务："
echo "👉 systemctl restart nginx xray"
echo "📄 网站目录：/var/www/html"
echo "📁 配置路径：/usr/local/etc/xray/config.json"
