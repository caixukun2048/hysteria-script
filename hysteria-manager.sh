#!/bin/bash

# 菜单显示函数
echo_menu() {
  clear
  echo -e "\e[32m#############################################################\e[0m"
  echo -e "#                 \e[36mHysteria 2 一键安装脚本\e[0m                  #"
  echo -e "#############################################################\e[0m"
  echo -e "\n 1. 安装 Hysteria 2"
 2. 卸载 Hysteria 2
 ------------------------------------------------------------
 3. 关闭、开启、重启 Hysteria 2
 4. 修改 Hysteria 2 配置
 5. 显示 Hysteria 2 配置文件
 ------------------------------------------------------------
 0. 退出脚本\n"
  read -rp "请输入选项 [0-5]: " input
  case "$input" in
    1)
      install_hysteria
      install_server_auto
      systemctl restart $SERVER_SERVICE
      green "Hysteria 安装完成"
      read -n 1 -s -r -p "按任意键返回菜单..."
      echo_menu
      ;;
    2)
      systemctl stop $SERVER_SERVICE
      systemctl disable $SERVER_SERVICE
      rm -f $BIN_PATH
      rm -f /etc/systemd/system/$SERVER_SERVICE.service
      rm -rf /etc/hysteria
      green "Hysteria 已卸载"
      read -n 1 -s -r -p "按任意键返回菜单..."
      echo_menu
      ;;
    3)
      echo -e "\n1. 启动  2. 停止  3. 重启\n"
      read -rp "选择操作 [1-3]: " act
      case "$act" in
        1) systemctl start $SERVER_SERVICE;;
        2) systemctl stop $SERVER_SERVICE;;
        3) systemctl restart $SERVER_SERVICE;;
      esac
      read -n 1 -s -r -p "按任意键返回菜单..."
      echo_menu
      ;;
    4)
      nano $SERVER_CONFIG
      systemctl restart $SERVER_SERVICE
      green "配置已更新"
      read -n 1 -s -r -p "按任意键返回菜单..."
      echo_menu
      ;;
    5)
      cat $SERVER_CONFIG
      read -n 1 -s -r -p "按任意键返回菜单..."
      echo_menu
      ;;
    0)
      exit 0
      ;;
    *)
      red "无效输入，请重新选择"
      sleep 1
      echo_menu
      ;;
  esac
}

# 运行菜单
echo_menu
