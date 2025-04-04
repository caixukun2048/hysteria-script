#!/bin/bash

# ====================================================
# Hysteria 2 一键安装脚本
# 原作者: flame1ce
# GitHub 仓库: https://github.com/flame1ce/hysteria2-install
# 许可协议: MIT License
# ====================================================

# 检查系统是否为 Debian 或 Ubuntu
if [[ ! -f /etc/debian_version ]]; then
    echo "本脚本仅支持 Debian 或 Ubuntu 系统。"
    exit 1
fi

# 更新系统并安装必要的软件包
apt update && apt install -y wget curl

# 下载并运行 Hysteria 2 官方安装脚本
bash <(curl -fsSL https://get.hy2.sh/)

# 提示用户输入配置参数
read -p "请输入监听端口（默认: 8443）: " PORT
PORT=${PORT:-8443}

read -p "请输入域名: " DOMAIN

read -p "请输入密码（默认: Hy2Best2024@）: " PASSWORD
PASSWORD=${PASSWORD:-Hy2Best2024@}

# 创建 Hysteria 配置目录
mkdir -p /etc/hysteria

# 创建配置文件
cat << EOF > /etc/hysteria/config.yaml
listen: :$PORT

acme:
  domains:
    - $DOMAIN
  email: test@sharklasers.com

auth:
  type: password
  password: $PASSWORD

masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true
EOF

# 启动并设置 Hysteria 服务开机自启
systemctl start hysteria-server.service
systemctl enable hysteria-server.service

# 等待服务启动
sleep 10

# 检查服务状态
STATUS=$(systemctl is-active hysteria-server.service)
if [ "$STATUS" == "active" ]; then
    echo "Hysteria 2 安装并启动成功！"
    echo "配置详情："
    echo "域名: $DOMAIN"
    echo "端口: $PORT"
    echo "密码: $PASSWORD"
else
    echo "Hysteria 2 启动失败，请检查服务状态。"
fi
