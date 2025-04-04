#!/bin/bash

# ========= 全局变量 =========
CONFIG_DIR="/root/hy"
YAML_CONFIG="$CONFIG_DIR/hy-client.yaml"
JSON_CONFIG="$CONFIG_DIR/hy-client.json"
QRCODE_IMG="$CONFIG_DIR/hysteria-node.png"
BIN_PATH="/usr/local/bin/hysteria"
SERVICE_NAME="hysteria-client"
SERVER_CONFIG="/etc/hysteria/config.yaml"
SERVER_SERVICE="hysteria-server"

# ========= 工具函数 =========
green() { echo -e "\033[32m$1\033[0m"; }
red() { echo -e "\033[31m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
line() { echo "----------------------------------------"; }

# ========= 检测 IPv6-only =========
check_ipv6_only() {
  echo -n "[+] 检测 IPv4 出口... "
  if curl -s --max-time 3 -4 https://ip.gs >/dev/null; then
    echo "有 IPv4"
  else
    echo "无 IPv4 检测到。是否安装 WARP？"
    echo "1. 不安装 (默认)"
    echo "2. 安装 WARP"
    read -rp "请选择 [1-2]: " warp_choice
    [[ "$warp_choice" == "2" ]] && install_warp
  fi
}

# ========= 自动安装 WARP =========
install_warp() {
  if [[ -f /usr/bin/warp-go ]]; then
    echo "WARP 已安装"
    return
  fi
  bash <(curl -fsSL https://warp.deno.dev/auto) || red "WARP 安装失败！"
}

# ========= 安装 Hysteria =========
install_hysteria() {
  mkdir -p "$CONFIG_DIR"
  if [[ ! -f "$BIN_PATH" ]]; then
    echo "[+] 安装 Hysteria 2..."
    curl -fsSL https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64 -o "$BIN_PATH"
    chmod +x "$BIN_PATH"
    green "Hysteria 安装完成"
  else
    yellow "Hysteria 已安装"
  fi
}

# ========= 自动生成并启动服务端配置 =========
install_server_auto() {
  mkdir -p /etc/hysteria

  echo "请选择服务端监听端口方式："
  echo "1. 默认随机端口"
  echo "2. 自定义端口"
  read -rp "请输入选项 [1-2]（默认1）: " port_mode
  if [[ "$port_mode" == "2" ]]; then
    read -rp "请输入自定义端口（如 39228）: " port
  else
    port=$((20000 + RANDOM % 20000))
  fi

  echo "是否自定义连接密码？"
  echo "1. 随机生成（默认）"
  echo "2. 手动输入密码"
  read -rp "请选择 [1-2]: " pw_mode
  if [[ "$pw_mode" == "2" ]]; then
    read -rp "请输入密码: " password
  else
    password=$(head -c 6 /dev/urandom | md5sum | cut -c1-8)
  fi

  echo "请输入伪装域名（默认 www.bing.com）:"
  read -rp "域名: " sni
  [[ -z "$sni" ]] && sni="www.bing.com"

  cat > "$SERVER_CONFIG" <<EOF
listen: ":$port"
auth:
  type: password
  password: $password
tls:
  alpn:
    - h3
  insecure: true
masquerade:
  type: proxy
  proxy:
    url: https://$sni
    rewriteHost: true
quic:
  initStreamReceiveWindow: 16777216
  maxStreamReceiveWindow: 16777216
  initConnReceiveWindow: 33554432
  maxConnReceiveWindow: 33554432
EOF

  cat > /etc/systemd/system/$SERVER_SERVICE.service <<EOF
[Unit]
Description=Hysteria 2 Server
After=network.target

[Service]
ExecStart=$BIN_PATH server -c $SERVER_CONFIG
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reexec
  systemctl enable --now $SERVER_SERVICE
  green "服务端已启动，监听端口: $port"
  echo "$port" > "$CONFIG_DIR/port.txt"
  echo "$password" > "$CONFIG_DIR/password.txt"
  echo "$sni" > "$CONFIG_DIR/sni.txt"
}

# ========= 自动生成客户端配置 =========
gen_config() {
  mkdir -p "$CONFIG_DIR"
  server=$(curl -s6 ifconfig.io || curl -s ifconfig.me)
  port=$(cat "$CONFIG_DIR/port.txt")
  password=$(cat "$CONFIG_DIR/password.txt")
  sni=$(cat "$CONFIG_DIR/sni.txt")
  insecure=true

  cat > "$YAML_CONFIG" <<EOF
server: "$server:$port"
auth: $password
tls:
  sni: $sni
  insecure: $insecure
quic:
  initStreamReceiveWindow: 16777216
  maxStreamReceiveWindow: 16777216
  initConnReceiveWindow: 33554432
  maxConnReceiveWindow: 33554432
fastOpen: true
socks5:
  listen: 127.0.0.1:5678
transport:
  udp:
    hopInterval: 30s
EOF

  cat > "$JSON_CONFIG" <<EOF
{
  "server": "$server:$port",
  "auth": "$password",
  "tls": {
    "sni": "$sni",
    "insecure": $insecure
  },
  "quic": {
    "initStreamReceiveWindow": 16777216,
    "maxStreamReceiveWindow": 16777216,
    "initConnReceiveWindow": 33554432,
    "maxConnReceiveWindow": 33554432
  },
  "socks5": {
    "listen": "127.0.0.1:5678"
  },
  "transport": {
    "udp": {
      "hopInterval": "30s"
    }
  }
}
EOF

  url="hysteria2://$password@$server:$port/?sni=$sni&insecure=1"
  echo "$url" > "$CONFIG_DIR/url.txt"
  qrencode -o "$QRCODE_IMG" "$url"
}

# ========= 启动客户端 =========
run_client() {
  nohup "$BIN_PATH" client -c "$YAML_CONFIG" > "$CONFIG_DIR/client.log" 2>&1 &
  sleep 1
  green "Hysteria 客户端已启动。日志：$CONFIG_DIR/client.log"
}

# ========= 设置开机启动 =========
setup_autostart() {
  cat > /etc/systemd/system/$SERVICE_NAME.service <<EOF
[Unit]
Description=Hysteria 2 Client
After=network.target

[Service]
ExecStart=$BIN_PATH client -c $YAML_CONFIG
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reexec
  systemctl enable --now $SERVICE_NAME
  green "已添加为开机自启服务：$SERVICE_NAME"
}

# ========= 一键全自动客户端搭建 =========
full_auto_setup() {
  check_ipv6_only
  install_hysteria
  install_server_auto
  gen_config
  run_client
  setup_autostart
  green "✅ 全部完成，代理已运行！"
  echo "🌐 出口检测："
  curl --socks5 127.0.0.1:5678 https://ip.gs
  echo "📷 二维码已保存：$QRCODE_IMG"
  echo "🔗 节点链接："
  cat "$CONFIG_DIR/url.txt"
  exit 0
}
