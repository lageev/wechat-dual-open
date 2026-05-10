# WeChat Dual-Open Manager

macOS 微信双开管理工具，一条命令实现微信多开。

## 快速开始

```bash
# 1. 克隆仓库（SSH 或 HTTPS 均可）
git clone git@github.com:lageev/wechat-dual-open.git
# git clone https://github.com/lageev/wechat-dual-open.git

# 2. 进入项目目录
cd wechat-dual-open

# 3. 添加执行权限
chmod +x wechat-dual.sh

# 4. 运行
./wechat-dual.sh
```

## 全局命令（可选）

将脚本链接到 `/usr/local/bin`，即可在任意目录直接调用 `wechat-dual`：

```bash
sudo ln -sf /path/to/wechat-dual.sh /usr/local/bin/wechat-dual
```

之后在终端输入 `wechat-dual` 即可启动。由于使用软链接，`git pull` 更新脚本后命令自动生效。

> **注意：** 需要在真实的终端中执行（如 Terminal.app、iTerm2），在 IDE 内置终端中可能因无法输入 sudo 密码而失败。

## 功能说明

脚本启动后会显示交互菜单：

```
  请选择操作:

  1) 安装双开     首次使用，复制并配置双开微信
  2) 修复双开     双开微信自行更新后，重新设置标识符并签名
  3) 查看状态     检查双开微信当前状态
  4) 卸载双开     删除双开微信
  0) 退出
```

### 1) 安装双开

首次使用，执行完整的三步配置：

1. 复制 `WeChat.app` 为双开应用
2. 修改 `CFBundleIdentifier` 避免进程冲突
3. 重新签名应用绕过系统验证

支持安装多个双开实例，脚本会自动检测已有的双开应用并递增编号，避免相互覆盖：

| 实例 | 应用名 | Bundle ID |
|------|--------|-----------|
| 第1个 | wechat2 | com.fring.wechat |
| 第2个 | wechat3 | com.fring.wechat2 |
| 第3个 | wechat4 | com.fring.wechat3 |

安装时可以自定义名称，直接回车则使用自动递增的默认名称：

```
检测到下一个可用编号: 2
将使用应用名: wechat2，Bundle ID: com.fring.wechat

为双开微信取个名字（直接回车使用默认名称 wechat2）:
```

### 2) 修复双开

双开微信内置了更新功能，可以直接在设置中检查更新。但更新后应用会被替换为原版微信，导致 `CFBundleIdentifier` 被覆盖回默认值（`com.tencent.xinWeChat`），此时点击双开图标会打开主微信。选择此项会重新设置标识符并签名，恢复双开功能。

**推荐的工作流程：**

1. 在双开微信中 → 设置 → 检查更新 → 完成更新
2. 运行本工具，选择 `2) 修复双开`
3. 重新打开双开微信，即可使用新版本

### 3) 查看状态

显示原版微信和双开微信的版本号、Bundle ID、代码签名状态，方便排查问题。

### 4) 卸载双开

删除双开应用，会二次确认后才执行。

## 实现原理

macOS 通过 `CFBundleIdentifier` 识别应用，同一个标识符只能运行一个实例。本工具通过以下方式实现双开：

1. **复制应用** — 将 `WeChat.app` 完整复制一份
2. **修改标识符** — 将副本的 `CFBundleIdentifier` 改为不同的值（如 `com.fring.wechat`、`com.fring.wechat2`...），自动递增避免冲突
3. **重新签名** — 修改后的应用签名失效，需要重新签名才能正常运行

## 配置文件

双开应用名称保存在 `~/.wechat-dual.conf` 中，后续操作（修复签名、卸载）会自动读取，无需重复输入。

## 注意事项

- 需要 `sudo` 权限（复制和签名系统应用目录）
- 微信更新后需要执行「修复双开」重新设置标识符并签名，否则双开图标会指向主微信
- 双开应用与原版微信共享相同的沙盒数据目录

## 推荐工具

[PasteHub](https://pastehub.yayalu.top/) — macOS 好用的剪贴板管理工具

## 友情链接

[Linux DO](https://linux.do) — 技术爱好者社区
