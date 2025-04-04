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
    echo "无 IPv4，准备安装 WARP..."
    install_warp
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

# ========= 自动生成客户端配置 =========
gen_config() {
  mkdir -p "$CONFIG_DIR"
  server=$(curl -s6 ifconfig.io || curl -s ifconfig.me)
  port=$((20000 + RANDOM % 20000))
  password=$(head -c 6 /dev/urandom | md5sum | cut -c1-8)
  sni="www.bing.com"
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

# ========= 主菜单 =========
show_menu() {
  clear
  echo "########################################"
  echo -e "#   \033[36mHysteria 2 一键终极管理脚本\033[0m   #"
  echo "########################################"
  echo "1. 一键搭建客户端（全自动）"
  echo "2. 卸载 客户端"
  echo "3. 生成客户端配置"
  echo "4. 启动客户端"
  echo "5. 设置开机启动（客户端）"
  echo "6. 显示节点链接与二维码"
  echo "7. 检查代理是否连通"
  echo "------------------------------"
  echo "8. 安装并配置 Hysteria 服务端"
  echo "0. 退出"
  echo ""
  read -rp "请选择操作 [0-8]: " opt

  case $opt in
    1) full_auto_setup;;
    2) uninstall_hysteria && sleep 1;;
    3) gen_config && sleep 1;;
    4) run_client && sleep 1;;
    5) setup_autostart && sleep 1;;
    6) cat "$CONFIG_DIR/url.txt" && echo "" && ls "$QRCODE_IMG" && sleep 1;;
    7) curl --socks5 127.0.0.1:5678 https://ip.gs && sleep 1;;
    8) install_server && sleep 1;;
    0) exit 0;;
    *) red "无效选项！" && sleep 1;;
  esac
  read -n 1 -s -r -p "按任意键返回菜单..."
  show_menu
}

show_menu
