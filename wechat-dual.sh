#!/bin/bash
# WeChat Dual-Open Manager for macOS
# Manages a second WeChat instance

set -euo pipefail

SRC_APP="/Applications/WeChat.app"
BUNDLE_ID_PREFIX="com.fring.wechat"
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
    local default_name="$1"
    local name
    read -rp "  为双开微信取个名字（直接回车使用默认名称 ${default_name}）: " name
    name="${name:-$default_name}"
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

# 扫描已安装的双开实例，返回下一个可用编号
find_next_number() {
    local max_num=1
    for app in /Applications/*.app; do
        [[ -d "$app" ]] || continue
        local plist_file="$app/Contents/Info.plist"
        [[ -f "$plist_file" ]] || continue
        local bid
        bid=$(plutil -extract CFBundleIdentifier raw "$plist_file" 2>/dev/null || echo "")
        # 匹配 com.fring.wechat（无后缀视为1）或 com.fring.wechatN
        if [[ "$bid" == "$BUNDLE_ID_PREFIX" ]]; then
            [[ 1 -gt $max_num ]] && max_num=1
        elif [[ "$bid" =~ ^${BUNDLE_ID_PREFIX}([0-9]+)$ ]]; then
            local n="${BASH_REMATCH[1]}"
            [[ $n -ge $max_num ]] && max_num=$((n + 1))
        fi
    done
    echo "$max_num"
}

# 根据编号生成 bundle ID
get_bundle_id_for_number() {
    local num=$1
    if [[ $num -eq 1 ]]; then
        echo "$BUNDLE_ID_PREFIX"
    else
        echo "${BUNDLE_ID_PREFIX}${num}"
    fi
}

# 根据 app name 推算 bundle ID（更新后 bundle ID 被覆盖时使用）
infer_bundle_id_from_name() {
    local name="$1"
    if [[ "$name" =~ ^wechat([0-9]+)$ ]]; then
        local num="${BASH_REMATCH[1]}"
        get_bundle_id_for_number "$num"
    else
        # 自定义名称，无法推算，使用配置文件中的记录
        echo ""
    fi
}

check_bundle_id() {
    local p
    p="$(plist)"
    if [[ ! -f "$p" ]]; then
        return 1
    fi
    local current
    current=$(plutil -extract CFBundleIdentifier raw "$p" 2>/dev/null || echo "")
    [[ "$current" == "${BUNDLE_ID_PREFIX}" || "$current" =~ ^${BUNDLE_ID_PREFIX}[0-9]+$ ]]
}

do_install() {
    echo ""
    if ! check_src; then
        return 1
    fi

    APP_NAME="wechat2"
    local bundle_id="$BUNDLE_ID_PREFIX"

    if check_dst; then
        warn "$(dst_app) 已存在，无需重复安装。"
        return 0
    fi

    echo ""
    step "[1/3] 复制 WeChat.app → ${APP_NAME}.app ..."
    sudo cp -R "$SRC_APP" "$(dst_app)"
    info "复制完成"

    step "[2/3] 修改 Bundle Identifier → $bundle_id ..."
    sudo /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$(plist)"
    info "标识符修改完成"

    step "[3/3] 重新签名应用..."
    sudo codesign --force --deep --sign - "$(dst_app)"
    info "签名完成"

    save_name "$APP_NAME"
    echo ""
    info "安装完成！你可以从 Launchpad 或 $(dst_app) 启动第二个微信。"
}

do_multi_install() {
    echo ""
    echo -e "  ${YELLOW}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "  ${YELLOW}║  免责声明                                     ║${NC}"
    echo -e "  ${YELLOW}║                                               ║${NC}"
    echo -e "  ${YELLOW}║  多开功能仅供学习调试使用。                    ║${NC}"
    echo -e "  ${YELLOW}║  使用本功能可能导致微信客户端数据变动、        ║${NC}"
    echo -e "  ${YELLOW}║  账号异常或本机环境变化，一切后果由用户        ║${NC}"
    echo -e "  ${YELLOW}║  自行承担。                                   ║${NC}"
    echo -e "  ${YELLOW}║                                               ║${NC}"
    echo -e "  ${YELLOW}║  继续即表示您已了解并接受上述风险。            ║${NC}"
    echo -e "  ${YELLOW}╚═══════════════════════════════════════════════╝${NC}"
    echo ""
    read -rp "  是否继续？(y/N): " ans
    [[ "$(echo "$ans" | tr '[:upper:]' '[:lower:]')" == "y" ]] || return 0

    echo ""
    if ! check_src; then
        return 1
    fi

    local next_num bundle_id
    next_num=$(find_next_number)
    bundle_id=$(get_bundle_id_for_number "$next_num")

    local default_name="wechat${next_num}"
    info "检测到下一个可用编号: $next_num"
    info "将使用应用名: ${default_name}，Bundle ID: $bundle_id"
    echo ""

    local name
    name=$(ask_name "$default_name")
    APP_NAME="$name"

    # 根据用户输入的名字推算 bundle ID
    if [[ "$name" =~ ^wechat([0-9]+)$ ]]; then
        local user_num="${BASH_REMATCH[1]}"
        bundle_id=$(get_bundle_id_for_number "$user_num")
    fi

    if check_dst; then
        warn "$(dst_app) 已存在。"
        read -rp "  是否覆盖？(y/N): " ans2
        [[ "$(echo "$ans2" | tr '[:upper:]' '[:lower:]')" == "y" ]] || return 0
        step "删除旧的 ${APP_NAME}.app..."
        sudo rm -rf "$(dst_app)"
    fi

    echo ""
    step "[1/3] 复制 WeChat.app → ${APP_NAME}.app ..."
    sudo cp -R "$SRC_APP" "$(dst_app)"
    info "复制完成"

    step "[2/3] 修改 Bundle Identifier → $bundle_id ..."
    sudo /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$(plist)"
    info "标识符修改完成"

    step "[3/3] 重新签名应用..."
    sudo codesign --force --deep --sign - "$(dst_app)"
    info "签名完成"

    save_name "$APP_NAME"
    echo ""
    info "安装完成！你可以从 Launchpad 或 $(dst_app) 启动双开微信。"
}

do_resign() {
    echo ""

    if ! check_dst; then
        error "${APP_NAME}.app 不存在，请先执行安装。"
        return 1
    fi

    local current_bid expected_bid
    current_bid=$(plutil -extract CFBundleIdentifier raw "$(plist)" 2>/dev/null || echo "")

    if [[ "$current_bid" == "${BUNDLE_ID_PREFIX}" || "$current_bid" =~ ^${BUNDLE_ID_PREFIX}[0-9]+$ ]]; then
        info "Bundle ID 正常: $current_bid"
    else
        # 更新后 bundle ID 被覆盖，根据 app name 推算并修复
        expected_bid=$(infer_bundle_id_from_name "$APP_NAME")
        if [[ -n "$expected_bid" ]]; then
            warn "Bundle ID 被覆盖为: $current_bid"
            step "恢复 Bundle Identifier → $expected_bid ..."
            sudo /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $expected_bid" "$(plist)"
            info "标识符已恢复"
        else
            warn "无法推算正确的 Bundle ID（应用名非默认格式），仅重新签名"
        fi
    fi

    step "重新签名应用..."
    sudo codesign --force --deep --sign - "$(dst_app)"
    info "签名完成"

    echo ""
    info "修复完成！${APP_NAME}.app 可以正常使用了。"
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

        local cur_id
        cur_id=$(plutil -extract CFBundleIdentifier raw "$(plist)" 2>/dev/null || echo "未知")
        if check_bundle_id; then
            info "Bundle ID: $cur_id (正确)"
        else
            warn "Bundle ID: $cur_id (需要修复)"
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
    echo -e "  ${CYAN}2)${NC} 修复双开     双开微信自行更新后，重新设置标识符并签名"
    echo -e "  ${CYAN}3)${NC} 查看状态     检查双开微信当前状态"
    echo -e "  ${CYAN}4)${NC} 卸载双开     删除双开微信"
    echo -e "  ${CYAN}5)${NC} 多开安装     进阶：安装多个双开实例（仅供学习调试）"
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
            2) do_resign ;;
            3) do_status ;;
            4) do_uninstall ;;
            5) do_multi_install ;;
            0) echo ""; info "再见！"; exit 0 ;;
            *) warn "无效选项" ;;
        esac
        echo ""
        read -rp "  按 Enter 返回主菜单..."
    done
}

main
