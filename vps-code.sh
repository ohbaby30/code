#!/bin/bash

# VPS Toolkit 脚本集合 by ohbaby30
# GitHub: https://github.com/ohbaby30/vps-code

# 遇到错误立即退出
set -e

# 彩色输出定义
GREEN="\033[1;32m"
CYAN="\033[1;36m"
RED="\033[1;31m"
RESET="\033[0m"

show_menu() {
    echo -e ""
    echo -e "${CYAN}请选择要执行的脚本：${RESET}"
    echo -e ""
    echo -e "${GREEN}1)${RESET} VPS 流媒体解锁测试 (unlock.media)"
    echo -e "${GREEN}2)${RESET} VPS 回程线路测试 (testrace.sh)"
    echo -e ""
    echo -e "${GREEN}0)${RESET} 退出"
}

run_test() {
    case $1 in
        1)
            echo -e "${CYAN}开始执行 unlock.media 测试...${RESET}"
            bash <(curl -L -s check.unlock.media)
            ;;
        2)
            echo -e "${CYAN}下载并运行 testrace.sh 回程线路测试...${RESET}"
            wget -q https://raw.githubusercontent.com/nanqinlang-script/testrace/master/testrace.sh
            bash testrace.sh
            rm -f testrace.sh
            ;;
        0)
            echo -e "${GREEN}已退出。${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项，请重试。${RESET}"
            ;;
    esac
}

# 主循环
while true; do
    clear
    show_menu
    echo
    read -p "输入选项编号: " choice
    echo
    run_test "$choice"
    echo
    read -p "按回车继续..." temp
done
