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
  5) 进阶更多
  0) 退出
```

### 1) 安装双开

首次使用，执行完整的三步配置：

1. 复制 `WeChat.app` 为 `wechat2.app`
2. 修改 `CFBundleIdentifier` 为 `com.fring.wechat` 避免进程冲突
3. 重新签名应用绕过系统验证

### 5) 进阶更多

> **免责声明：** 多开功能仅供学习调试使用。双开（2个实例）的稳定性已经过验证，更多数量可能存在无法预知的风险，包括客户端数据异常、账号风险等，请自行验证并承担后果。

在已有一个双开的基础上，支持安装更多实例，自动递增编号避免冲突：

| 实例 | 应用名 | Bundle ID |
|------|--------|-----------|
| 第1个 | wechat2 | com.fring.wechat |
| 第2个 | wechat3 | com.fring.wechat2 |
| 第3个 | wechat4 | com.fring.wechat3 |

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

双开实例信息保存在 `~/.wechat-dual.conf` 中，每行格式为 `应用名:BundleID`：

```
wechat2:com.fring.wechat
wechat3:com.fring.wechat2
```

修复双开和卸载时会自动读取配置，无需重复输入。

## 注意事项

- 需要 `sudo` 权限（复制和签名系统应用目录）
- 微信更新后需要执行「修复双开」重新设置标识符并签名，否则双开图标会指向主微信
- 双开应用与原版微信共享相同的沙盒数据目录

## 推荐工具

[PasteHub](https://pastehub.yayalu.top/) — macOS 好用的剪贴板管理工具

## 友情链接

[Linux DO](https://linux.do) — 技术爱好者社区
