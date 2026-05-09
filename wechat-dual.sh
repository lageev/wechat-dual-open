#!/bin/bash
# WeChat Dual-Open Manager for macOS
# Manages a second WeChat instance

set -euo pipefail

SRC_APP="/Applications/WeChat.app"
BUNDLE_ID="com.fring.wechat"
CONF="$HOME/.wechat-dual.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
    clear
    echo -e "${CYAN}"
    echo "  ╔═════════════════════════════════"
    echo "  ║  WeChat Dual-Open Manager"
    echo "  ║  macOS WeChat 双开管理工具"
    echo "  ║  macOS剪贴板: https://pastehub.yayalu.top/"
    echo "  ╚═════════════════════════════════"
    echo -e "${NC}"
}

info()    { echo -e "  ${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "  ${YELLOW}[!]${NC} $1"; }
error()   { echo -e "  ${RED}[✗]${NC} $1"; }
step()    { echo -e "  ${CYAN}[→]${NC} $1"; }

# 读取已保存的应用名
load_name() {
    if [[ -f "$CONF" ]]; then
        APP_NAME=$(cat "$CONF")
    else
        APP_NAME="wechat2"
    fi
}

# 保存应用名到配置文件
save_name() {
    echo "$1" > "$CONF"
}

dst_app() {
    echo "/Applications/${APP_NAME}.app"
}

plist() {
    echo "$(dst_app)/Contents/Info.plist"
}

ask_name() {
    local name
    read -rp "  为双开微信取个名字（直接回车使用默认名称 wechat2）: " name
    name="${name:-wechat2}"
    # 移除 .app 后缀（如果用户误加了）
    name="${name%.app}"
    echo "$name"
}

check_src() {
    if [[ ! -d "$SRC_APP" ]]; then
        error "未找到微信: $SRC_APP"
        echo "         请先安装微信应用。"
        return 1
    fi
    return 0
}

check_dst() {
    [[ -d "$(dst_app)" ]]
}

check_bundle_id() {
    local p
    p="$(plist)"
    if [[ ! -f "$p" ]]; then
        return 1
    fi
    local current
    current=$(plutil -extract CFBundleIdentifier raw "$p" 2>/dev/null || echo "")
    [[ "$current" == "$BUNDLE_ID" ]]
}

do_install() {
    echo ""
    if ! check_src; then
        return 1
    fi

    local name
    name=$(ask_name)
    APP_NAME="$name"

    if check_dst; then
        warn "$(dst_app) 已存在。"
        read -rp "  是否覆盖？(y/N): " ans
        [[ "$(echo "$ans" | tr '[:upper:]' '[:lower:]')" == "y" ]] || return 0
        step "删除旧的 ${APP_NAME}.app..."
        sudo rm -rf "$(dst_app)"
    fi

    echo ""
    step "[1/3] 复制 WeChat.app → ${APP_NAME}.app ..."
    sudo cp -R "$SRC_APP" "$(dst_app)"
    info "复制完成"

    step "[2/3] 修改 Bundle Identifier → $BUNDLE_ID ..."
    sudo /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$(plist)"
    info "标识符修改完成"

    step "[3/3] 重新签名应用..."
    sudo codesign --force --deep --sign - "$(dst_app)"
    info "签名完成"

    save_name "$APP_NAME"
    echo ""
    info "安装完成！你可以从 Launchpad 或 $(dst_app) 启动第二个微信。"
}

do_update() {
    echo ""

    if ! check_dst; then
        error "${APP_NAME}.app 不存在，请先执行安装。"
        return 1
    fi

    echo ""
    step "[1/4] 删除旧的 ${APP_NAME}.app..."
    sudo rm -rf "$(dst_app)"
    info "已删除"

    if ! check_src; then
        return 1
    fi

    step "[2/4] 重新复制 WeChat.app..."
    sudo cp -R "$SRC_APP" "$(dst_app)"
    info "复制完成"

    step "[3/4] 修改 Bundle Identifier..."
    sudo /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$(plist)"
    info "标识符修改完成"

    step "[4/4] 重新签名应用..."
    sudo codesign --force --deep --sign - "$(dst_app)"
    info "签名完成"

    echo ""
    info "更新完成！${APP_NAME}.app 已刷新到最新版本。"
}

do_resign() {
    echo ""

    if ! check_dst; then
        error "${APP_NAME}.app 不存在，请先执行安装。"
        return 1
    fi

    step "[1/2] 修改 Bundle Identifier..."
    sudo /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$(plist)"
    info "标识符修改完成"

    step "[2/2] 重新签名应用..."
    sudo codesign --force --deep --sign - "$(dst_app)"
    info "签名完成"

    echo ""
    info "重新签名完成！${APP_NAME}.app 可以正常使用了。"
}

do_status() {
    echo ""

    # Check source app
    if check_src; then
        local src_ver
        src_ver=$(plutil -extract CFBundleShortVersionString raw "/Applications/WeChat.app/Contents/Info.plist" 2>/dev/null || echo "未知")
        info "WeChat.app  版本: $src_ver"
    else
        error "WeChat.app 未安装"
    fi

    # Check dual app
    if check_dst; then
        local dst_ver
        dst_ver=$(plutil -extract CFBundleShortVersionString raw "$(plist)" 2>/dev/null || echo "未知")
        info "${APP_NAME}.app 版本: $dst_ver"

        if check_bundle_id; then
            info "Bundle ID: $BUNDLE_ID (正确)"
        else
            local cur_id
            cur_id=$(plutil -extract CFBundleIdentifier raw "$(plist)" 2>/dev/null || echo "未知")
            warn "Bundle ID: $cur_id (需要修改为 $BUNDLE_ID)"
        fi

        # Check code signature
        if codesign -v "$(dst_app)" 2>/dev/null; then
            info "代码签名: 有效"
        else
            warn "代码签名: 无效或已损坏 (需要重新签名)"
        fi
    else
        warn "${APP_NAME}.app 未安装"
    fi
}

do_uninstall() {
    echo ""

    if ! check_dst; then
        warn "${APP_NAME}.app 不存在，无需卸载。"
        return 0
    fi

    read -rp "  确认卸载 ${APP_NAME}.app？(y/N): " ans
    [[ "$(echo "$ans" | tr '[:upper:]' '[:lower:]')" == "y" ]] || return 0

    sudo rm -rf "$(dst_app)"
    info "${APP_NAME}.app 已卸载。"
}

show_menu() {
    echo -e "  ${BOLD}请选择操作:${NC}"
    echo ""
    echo -e "  ${CYAN}1)${NC} 安装双开     首次使用，复制并配置双开微信"
    echo -e "  ${CYAN}2)${NC} 更新双开     微信更新后，重新复制并配置"
    echo -e "  ${CYAN}3)${NC} 重新签名     仅重新签名（微信更新后的快捷方式）"
    echo -e "  ${CYAN}4)${NC} 查看状态     检查双开微信当前状态"
    echo -e "  ${CYAN}5)${NC} 卸载双开     删除双开微信"
    echo -e "  ${CYAN}0)${NC} 退出"
    echo ""
}

main() {
    load_name
    while true; do
        banner
        do_status
        echo ""
        show_menu
        read -rp "  输入选项 [0-5]: " choice
        case "${choice}" in
            1) do_install ;;
            2) do_update ;;
            3) do_resign ;;
            4) do_status ;;
            5) do_uninstall ;;
            0) echo ""; info "再见！"; exit 0 ;;
            *) warn "无效选项" ;;
        esac
        echo ""
        read -rp "  按 Enter 返回主菜单..."
    done
}

main
