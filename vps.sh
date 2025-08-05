#!/bin/bash

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 权限运行此脚本！"
  exit 1
fi

# 第一步：更新系统并安装必要工具
echo "正在更新系统并安装必要工具..."
apt-get update
apt-get install -y openssl cron socat curl unzip vim wget

# 第二步：安装 acme.sh 并申请证书
echo "正在安装 acme.sh..."
curl https://get.acme.sh | sh -s email=x@x.xxx
if [ ! -f ~/.acme.sh/acme.sh ]; then
  echo "acme.sh 安装失败，请检查网络或手动安装！"
  exit 1
fi
source ~/.bashrc
acme.sh --set-default-ca --server buypass

# 暂停并提示用户输入域名，替换 x.x.x 后继续
echo "请在此输入您的域名（例如 example.com），输入后按回车继续："
read -r DOMAIN
while [ -z "$DOMAIN" ]; do
  echo "错误：域名不能为空！请重新输入："
  read -r DOMAIN
done
echo "正在为 $DOMAIN 申请证书..."
/root/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone -k ec-256

# 设置证书目录权限
chmod 755 /root/.acme.sh/"${DOMAIN}_ecc"

# 设置 acme.sh 自动更新
acme.sh --upgrade --auto-upgrade

# 第三步：安装 nginx
echo "正在安装 nginx..."
apt update && apt install nginx -y
echo "nginx 已安装完成！请自行到 /var/www/html 目录下修改 HTML 文件以配置您的网站内容。"

# 第四步：安装 xray
echo "正在安装 xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root

# 第五步：修改 xray 配置文件
echo "正在配置 xray..."

# 暂停并提示用户输入 VLESS ID
echo "请在此输入 VLESS 的客户端 ID（建议使用 UUID，例如 550e8400-e29b-41d4-a716-446655440000），输入后按回车继续："
read -r VLESS_ID
while [ -z "$VLESS_ID" ]; do
  echo "错误：VLESS ID 不能为空！请重新输入："
  read -r VLESS_ID
done

# 暂停并提示用户输入 Trojan 密码
echo "请在此输入 Trojan 密码（建议使用复杂密码），输入后按回车继续："
read -s -r TROJAN_PASSWORD
while [ -z "$TROJAN_PASSWORD" ]; do
  echo
  echo "错误：Trojan 密码不能为空！请重新输入："
  read -s -r TROJAN_PASSWORD
done
echo

# 写入 xray 配置文件
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
                    "alpn": [
                        "http/1.1"
                    ],
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

echo "xray 配置文件已生成！"

# 第六步：设置开机自启
echo "正在设置 xray 和 nginx 开机自启..."
systemctl enable xray
systemctl enable nginx

echo "配置完成！请重启系统以应用所有更改：reboot"
