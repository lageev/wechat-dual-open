#!/bin/bash
# WeChat Dual-Open Manager for macOS
# Manages a second WeChat instance (wechat2.app)

set -euo pipefail

SRC_APP="/Applications/WeChat.app"
DST_APP="/Applications/wechat2.app"
BUNDLE_ID="com.fring.wechat"
PLIST="$DST_APP/Contents/Info.plist"

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

check_src() {
    if [[ ! -d "$SRC_APP" ]]; then
        error "未找到微信: $SRC_APP"
        echo "         请先安装微信应用。"
        return 1
    fi
    return 0
}

check_dst() {
    if [[ ! -d "$DST_APP" ]]; then
        return 1
    fi
    return 0
}

check_bundle_id() {
    if [[ ! -f "$PLIST" ]]; then
        return 1
    fi
    local current
    current=$(plutil -extract CFBundleIdentifier raw "$PLIST" 2>/dev/null || echo "")
    [[ "$current" == "$BUNDLE_ID" ]]
}

do_install() {
    echo ""
    if ! check_src; then
        return 1
    fi

    if check_dst; then
        warn "wechat2.app 已存在。"
        read -rp "  是否覆盖？(y/N): " ans
        [[ "${ans,,}" == "y" ]] || return 0
        step "删除旧的 wechat2.app..."
        sudo rm -rf "$DST_APP"
    fi

    echo ""
    step "[1/3] 复制 WeChat.app → wechat2.app ..."
    sudo cp -R "$SRC_APP" "$DST_APP"
    info "复制完成"

    step "[2/3] 修改 Bundle Identifier → $BUNDLE_ID ..."
    sudo /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST"
    info "标识符修改完成"

    step "[3/3] 重新签名应用..."
    sudo codesign --force --deep --sign - "$DST_APP"
    info "签名完成"

    echo ""
    info "安装完成！你可以从 Launchpad 或 /Applications/wechat2.app 启动第二个微信。"
}

do_update() {
    echo ""

    if ! check_dst; then
        error "wechat2.app 不存在，请先执行安装。"
        return 1
    fi

    echo ""
    step "[1/3] 删除旧的 wechat2.app..."
    sudo rm -rf "$DST_APP"
    info "已删除"

    if ! check_src; then
        return 1
    fi

    step "[2/3] 重新复制 WeChat.app..."
    sudo cp -R "$SRC_APP" "$DST_APP"
    info "复制完成"

    step "[3/3] 修改 Bundle Identifier..."
    sudo /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST"
    info "标识符修改完成"

    step "[4/4] 重新签名应用..."
    sudo codesign --force --deep --sign - "$DST_APP"
    info "签名完成"

    echo ""
    info "更新完成！wechat2.app 已刷新到最新版本。"
}

do_resign() {
    echo ""

    if ! check_dst; then
        error "wechat2.app 不存在，请先执行安装。"
        return 1
    fi

    step "[1/2] 修改 Bundle Identifier..."
    sudo /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST"
    info "标识符修改完成"

    step "[2/2] 重新签名应用..."
    sudo codesign --force --deep --sign - "$DST_APP"
    info "签名完成"

    echo ""
    info "重新签名完成！wechat2.app 可以正常使用了。"
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
        dst_ver=$(plutil -extract CFBundleShortVersionString raw "$PLIST" 2>/dev/null || echo "未知")
        info "wechat2.app 版本: $dst_ver"

        if check_bundle_id; then
            info "Bundle ID: $BUNDLE_ID (正确)"
        else
            local cur_id
            cur_id=$(plutil -extract CFBundleIdentifier raw "$PLIST" 2>/dev/null || echo "未知")
            warn "Bundle ID: $cur_id (需要修改为 $BUNDLE_ID)"
        fi

        # Check code signature
        if codesign -v "$DST_APP" 2>/dev/null; then
            info "代码签名: 有效"
        else
            warn "代码签名: 无效或已损坏 (需要重新签名)"
        fi
    else
        warn "wechat2.app 未安装"
    fi
}

do_uninstall() {
    echo ""

    if ! check_dst; then
        warn "wechat2.app 不存在，无需卸载。"
        return 0
    fi

    read -rp "  确认卸载 wechat2.app？(y/N): " ans
    [[ "${ans,,}" == "y" ]] || return 0

    sudo rm -rf "$DST_APP"
    info "wechat2.app 已卸载。"
}

show_menu() {
    echo -e "  ${BOLD}请选择操作:${NC}"
    echo ""
    echo -e "  ${CYAN}1)${NC} 安装双开     首次使用，复制并配置 wechat2"
    echo -e "  ${CYAN}2)${NC} 更新双开     微信更新后，重新复制并配置"
    echo -e "  ${CYAN}3)${NC} 重新签名     仅重新签名（微信更新后的快捷方式）"
    echo -e "  ${CYAN}4)${NC} 查看状态     检查 wechat2 当前状态"
    echo -e "  ${CYAN}5)${NC} 卸载双开     删除 wechat2.app"
    echo -e "  ${CYAN}0)${NC} 退出"
    echo ""
}

main() {
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
