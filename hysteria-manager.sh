#!/bin/bash

# ========= 全局变量 =========
CONFIG_DIR="/root/hy"
YAML_CONFIG="$CONFIG_DIR/hy-client.yaml"
JSON_CONFIG="$CONFIG_DIR/hy-client.json"
QRCODE_IMG="$CONFIG_DIR/hysteria-node.png"
BIN_PATH="/usr/local/bin/hysteria"
SERVICE_NAME="hysteria-client"

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

# ========= 安装 Hysteria 2 =========
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

# ========= 卸载 Hysteria =========
uninstall_hysteria() {
  systemctl stop $SERVICE_NAME 2>/dev/null
  systemctl disable $SERVICE_NAME 2>/dev/null
  rm -f "$BIN_PATH" "$YAML_CONFIG" "$JSON_CONFIG" "$QRCODE_IMG"
  green "已卸载 Hysteria 客户端与配置文件"
}

# ========= 生成配置 =========
gen_config() {
  read -rp "请输入服务端地址（如 1.2.3.4 或 [IPv6]）: " server
  read -rp "请输入端口（默认随机 20000-50000）: " port
  [[ -z "$port" ]] && port=$((20000 + RANDOM % 30000))
  read -rp "请输入连接密码（留空则自动生成）: " password
  [[ -z "$password" ]] && password=$(head -c 6 /dev/urandom | md5sum | cut -c1-8)
  read -rp "请输入伪装 SNI 域名（默认 www.bing.com）: " sni
  [[ -z "$sni" ]] && sni="www.bing.com"

  echo "请选择证书验证方式："
  echo "1) 跳过验证（默认）"
  echo "2) 自定义证书路径"
  read -rp "选择 [1-2]: " cert_mode

  insecure=true
  cert_path=""
  key_path=""

  if [[ "$cert_mode" == "2" ]]; then
    insecure=false
    read -rp "请输入 cert 证书路径: " cert_path
    read -rp "请输入 key 私钥路径: " key_path
  fi

  # 写入 YAML 配置
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

  # JSON 配置
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

  # 生成分享链接
  url="hysteria2://$password@$server:$port/?sni=$sni"
  [[ "$insecure" == true ]] && url+="&insecure=1"
  echo "$url" > "$CONFIG_DIR/url.txt"

  # 生成二维码
  qrencode -o "$QRCODE_IMG" "$url"
  green "配置生成完成！节点链接："
  echo "$url"
  echo "二维码已保存到 $QRCODE_IMG"
}

# ========= 运行客户端 =========
run_client() {
  nohup "$BIN_PATH" client -c "$YAML_CONFIG" > "$CONFIG_DIR/client.log" 2>&1 &
  sleep 1
  green "Hysteria 客户端已启动。日志：$CONFIG_DIR/client.log"
}

# ========= 创建 Systemd =========
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

# ========= 主菜单 =========
show_menu() {
  clear
  echo "########################################"
  echo -e "#   \033[36mHysteria 2 一键终极管理脚本\033[0m   #"
  echo "########################################"
  echo "1. 安装 Hysteria 2"
  echo "2. 卸载 Hysteria 2"
  echo "3. 创建/更新配置文件"
  echo "4. 启动客户端"
  echo "5. 设置开机自启"
  echo "6. 显示节点链接与二维码"
  echo "7. 检查代理是否连通"
  echo "0. 退出"
  echo ""
  read -rp "请选择操作 [0-7]: " opt

  case $opt in
    1) install_hysteria && sleep 1;;
    2) uninstall_hysteria && sleep 1;;
    3) gen_config && sleep 1;;
    4) run_client && sleep 1;;
    5) setup_autostart && sleep 1;;
    6) cat "$CONFIG_DIR/url.txt" && echo "" && ls "$QRCODE_IMG" && sleep 1;;
    7) curl --socks5 127.0.0.1:5678 https://ip.gs && sleep 1;;
    0) exit 0;;
    *) red "无效选项！" && sleep 1;;
  esac
  read -n 1 -s -r -p "按任意键返回菜单..."
  show_menu
}

check_ipv6_only
show_menu
