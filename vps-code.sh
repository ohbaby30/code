#!/bin/bash

# VPS Toolkit 脚本集合 by ohbaby30
# GitHub: https://github.com/ohbaby30/code

# 彩色输出定义
GREEN="\033[1;32m"
CYAN="\033[1;36m"
RESET="\033[0m"

show_menu() {
cat <<EOF

  ${CYAN}请选择要执行的脚本：${RESET}

${GREEN}1)${RESET} VPS 流媒体解锁测试 (unlock.media)
${GREEN}2)${RESET} VPS 回程线路测试 (testrace.sh)

${GREEN}0)${RESET} 退出
EOF
}

run_test() {
    case $1 in
        1)  bash <(curl -L -s check.unlock.media) ;;
        2)  wget https://raw.githubusercontent.com/nanqinlang-script/testrace/master/testrace.sh && bash testrace.sh ;;
        0)  echo "已退出。" && exit 0 ;;
        *)  echo -e "${RED}无效选项，请重试。${RESET}" ;;
    esac
}

while true; do
    clear
    show_menu
    echo
    read -p "输入选项编号: " choice
    echo
    run_test $choice
    echo
    read -p "按回车继续..." temp
done
