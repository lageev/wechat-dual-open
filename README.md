# WeChat Dual-Open Manager

macOS 微信双开管理工具，一条命令实现微信多开。

## 使用方法

```bash
chmod +x wechat-dual.sh
./wechat-dual.sh
```

## 功能

- **安装双开** — 首次使用，复制并配置 wechat2.app
- **更新双开** — 微信更新后，重新复制并配置
- **重新签名** — 微信更新后的快捷修复方式
- **查看状态** — 检查 wechat2 当前状态
- **卸载双开** — 删除 wechat2.app

## 原理

1. 复制 `WeChat.app` 为 `wechat2.app`
2. 修改 `CFBundleIdentifier` 避免进程冲突
3. 重新签名应用绕过系统验证

## 推荐工具

[PasteHub](https://pastehub.yayalu.top/) — macOS 好用的剪贴板管理工具
