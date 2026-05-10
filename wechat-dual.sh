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

# 读取最后一条记录的应用名（向后兼容旧格式）
load_name() {
    if [[ -f "$CONF" ]]; then
        local last_line
        last_line=$(tail -1 "$CONF")
        APP_NAME="${last_line%%:*}"
    else
        APP_NAME="wechat2"
    fi
}

# 保存实例记录（追加 name:bundleID）
save_instance() {
    echo "${1}:${2}" >> "$CONF"
}

# 删除实例记录
remove_instance() {
    local name="$1"
    if [[ -f "$CONF" ]]; then
        local tmp="${CONF}.tmp"
        grep -v "^${name}:" "$CONF" > "$tmp" 2>/dev/null && mv "$tmp" "$CONF"
    fi
}

# 检查名称是否已存在于配置中
name_exists() {
    local name="$1"
    if [[ -f "$CONF" ]]; then
        grep -q "^${name}:" "$CONF"
    else
        return 1
    fi
}

# 根据名称获取 bundle ID
get_bundle_id() {
    local name="$1"
    if [[ -f "$CONF" ]]; then
        local line
        line=$(grep "^${name}:" "$CONF" | head -1)
        echo "${line#*:}"
    fi
}

# 从配置记录中获取下一个可用编号
find_next_number() {
    local max_num=1
    if [[ -f "$CONF" ]]; then
        while IFS= read -r line; do
            local name="${line%%:*}"
            if [[ "$name" =~ ^wechat([0-9]+)$ ]]; then
                local n="${BASH_REMATCH[1]}"
                [[ $n -ge $max_num ]] && max_num=$((n + 1))
            fi
        done < "$CONF"
    fi
    echo "$max_num"
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

# 根据编号生成 bundle ID
gen_bundle_id() {
    local num=$1
    if [[ $num -eq 1 ]]; then
        echo "$BUNDLE_ID_PREFIX"
    else
        echo "${BUNDLE_ID_PREFIX}${num}"
    fi
}

check_bundle_id() {
    local p
    p="$(plist)"
    if [[ ! -f "$p" ]]; then
        return 1
    fi
    local current expected
    current=$(plutil -extract CFBundleIdentifier raw "$p" 2>/dev/null || echo "")
    expected=$(get_bundle_id "$APP_NAME")
    [[ "$current" == "$expected" ]]
}

do_install() {
    echo ""
    if ! check_src; then
        return 1
    fi

    APP_NAME="wechat2"
    local bundle_id="$BUNDLE_ID_PREFIX"

    if name_exists "$APP_NAME"; then
        warn "${APP_NAME} 已存在于安装记录中，无需重复安装。"
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

    save_instance "$APP_NAME" "$bundle_id"
    echo ""
    info "安装完成！你可以从 Launchpad 或 $(dst_app) 启动第二个微信。"
}

do_multi_install() {
    echo ""
    info "安装多个双开实例（仅供学习调试）"
    echo ""
    echo -e "  ${YELLOW}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "  ${YELLOW}║  免责声明                                     ║${NC}"
    echo -e "  ${YELLOW}║                                               ║${NC}"
    echo -e "  ${YELLOW}║  多开功能仅供学习调试使用。                    ║${NC}"
    echo -e "  ${YELLOW}║  双开（2个实例）的稳定性已经过验证，           ║${NC}"
    echo -e "  ${YELLOW}║  更多数量可能存在无法预知的风险，              ║${NC}"
    echo -e "  ${YELLOW}║  包括客户端数据异常、账号风险等，              ║${NC}"
    echo -e "  ${YELLOW}║  请自行验证并承担后果。                        ║${NC}"
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
    bundle_id=$(gen_bundle_id "$next_num")

    local default_name="wechat${next_num}"
    info "检测到下一个可用编号: $next_num"
    info "将使用应用名: ${default_name}，Bundle ID: $bundle_id"
    echo ""

    local name
    name=$(ask_name "$default_name")
    APP_NAME="$name"

    # 用户自定义名称时，需要分配一个 bundle ID
    if [[ ! "$name" =~ ^wechat([0-9]+)$ ]]; then
        bundle_id="${BUNDLE_ID_PREFIX}.${name}"
    elif [[ "$name" != "$default_name" ]]; then
        local user_num="${BASH_REMATCH[1]}"
        bundle_id=$(gen_bundle_id "$user_num")
    fi

    if name_exists "$name"; then
        warn "名称 '$name' 已存在于安装记录中。"
        read -rp "  是否覆盖？(y/N): " ans2
        [[ "$(echo "$ans2" | tr '[:upper:]' '[:lower:]')" == "y" ]] || return 0
        step "删除旧的 ${APP_NAME}.app..."
        sudo rm -rf "$(dst_app)"
        remove_instance "$name"
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

    save_instance "$APP_NAME" "$bundle_id"
    echo ""
    info "安装完成！你可以从 Launchpad 或 $(dst_app) 启动双开微信。"
}

do_resign() {
    echo ""

    if ! check_dst; then
        error "${APP_NAME}.app 不存在，请先执行安装。"
        return 1
    fi

    local expected_bid current_bid
    expected_bid=$(get_bundle_id "$APP_NAME")
    current_bid=$(plutil -extract CFBundleIdentifier raw "$(plist)" 2>/dev/null || echo "")

    if [[ -z "$expected_bid" ]]; then
        warn "配置中未找到 ${APP_NAME} 的记录，仅重新签名"
    elif [[ "$current_bid" == "$expected_bid" ]]; then
        info "Bundle ID 正常: $current_bid"
    else
        warn "Bundle ID 不匹配: 当前 $current_bid，应为 $expected_bid"
        step "恢复 Bundle Identifier → $expected_bid ..."
        sudo /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $expected_bid" "$(plist)"
        info "标识符已恢复"
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

        local cur_id expected_id
        cur_id=$(plutil -extract CFBundleIdentifier raw "$(plist)" 2>/dev/null || echo "未知")
        expected_id=$(get_bundle_id "$APP_NAME")
        if [[ -n "$expected_id" && "$cur_id" == "$expected_id" ]]; then
            info "Bundle ID: $cur_id (正确)"
        elif [[ -n "$expected_id" ]]; then
            warn "Bundle ID: $cur_id (应为 $expected_id，需修复)"
        else
            warn "Bundle ID: $cur_id (配置中无记录)"
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
    remove_instance "$APP_NAME"
    info "${APP_NAME}.app 已卸载，配置记录已清除。"
}

show_menu() {
    echo -e "  ${BOLD}请选择操作:${NC}"
    echo ""
    echo -e "  ${CYAN}1)${NC} 安装双开     首次使用，复制并配置双开微信"
    echo -e "  ${CYAN}2)${NC} 修复双开     双开微信自行更新后，重新设置标识符并签名"
    echo -e "  ${CYAN}3)${NC} 查看状态     检查双开微信当前状态"
    echo -e "  ${CYAN}4)${NC} 卸载双开     删除双开微信"
    echo -e "  ${CYAN}5)${NC} 进阶更多"
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
