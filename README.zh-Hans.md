# EdgeClip ✿

[English](README.md) | [繁體中文](README.zh-Hant.md) | **简体中文**

**一个收在 Mac 屏幕边缘的剪贴板历史。**

十分钟前复制过的东西，现在已经找不到了？EdgeClip 会记住你复制过的所有内容，收在屏幕左边一条细细的面板里。鼠标移过去（或按 ⌥⌘V），面板就会滑出来，点一下就能再次复制。

<!-- 可在这里加入演示 GIF：![demo](docs/demo.gif) -->

## 功能

- 🫧 **划过即看**：平时收在屏幕边缘，鼠标移过去就会弹出
- ⌨️ **键盘操作**：按 ⌥⌘V 打开，直接打字搜索，用 ↑↓ 选择，按回车复制，⌘1–9 选前九项
- ⚡ **直接粘贴**（可选）：选好之后自动粘贴到你正在用的应用
- ★ **星标收藏**：常用的邮件模板、地址、链接。加星标的项目会固定在最上方，可以命名，而且永远不会被清除
- 🧹 **自动删除**：可设置没有加星标的项目在 1 小时、1 天、7 天或 30 天后自动删除
- 🔍 **搜索与筛选**：All / Text / Links / Images / Colors
- 🖼 **自动识别内容**：图片有缩略图、色值会显示色块（例如 `#AF52DE`）、链接会高亮显示、文件会显示文件名，每一项都会显示来自哪个应用
- 🔒 **默认保护隐私**：密码管理器标记为私密的密码一律不会保存，可以屏蔽整个应用，随时暂停记录，所有数据只保存在你的 Mac 上
- 📌 **固定常驻**：固定后面板会变成液态玻璃（需要 macOS 26 或以上）
- 🎨 **全面自定义**：字体（可使用 Mac 上的任何字体）、粗细、大小、文字颜色、强调色、背景色调、透明度、尺寸、圆角，以及放在左边或右边、上中下哪个位置
- 🪶 **轻巧原生**：只有一个 Swift 文件，不需要任何依赖、账号或云服务

可以和 [EdgeTodo](https://github.com/tllct122/edge-todo-for-mac) 一起用：EdgeClip 在左边，EdgeTodo 在右边，两者不会重叠。

## 安装

需要 macOS 12 或以上（液态玻璃需要 macOS 26 或以上）。

1. 下载这个仓库（**Code → Download ZIP**），然后解压
2. 打开“**终端**”，输入 `bash `（后面有一个空格），把 `build.sh` 拖进窗口，再按回车
3. 如果 macOS 提示安装 **Command Line Tools**，安装完成后再执行一次第 2 步

脚本会自动编译应用、安装到 `/Applications`，然后启动它。

## 使用方法

| 操作 | 方法 |
|---|---|
| 打开面板 | 把鼠标移到屏幕最左边（上半部分），或按 **⌥⌘V** |
| 再次复制 | 点击该项目 |
| 用键盘操作 | **↑ ↓** 移动、**回车** 复制、**⌘1–9** 选前九项、**Esc** 关闭、**⌘⌫** 删除 |
| 搜索 | 在最上方的搜索框输入 |
| 加星标 | 鼠标移到项目上，点击 ☆ |
| 为星标项目命名 | 右键 → **Name…** |
| 打开链接／显示文件 | 右键 → **Open Link**／**Show in Finder** |
| 暂停记录 | 点击面板最上方的“clipboard”，或菜单栏 📋 图标 → **Pause Recording** |
| 清除历史 | 点击最底部的 **clear**（星标项目会保留） |
| 自动删除旧记录 | **Settings → Clipboard → Delete unstarred clips after** 选 1 小时／1 天／7 天／30 天（星标项目会保留） |
| 保持面板打开 | 点击 📌 |
| 设置 | 点击面板上的 ⚙︎，或菜单栏 📋 图标 → **Settings…**（⌘,） |
| 开机自动启动 | 菜单栏 📋 图标 → **Open at Login** |

### 直接粘贴

在 **Settings → Clipboard** 打开 **Paste right away when I pick a clip**。macOS 会要求你在 **系统设置 → 隐私与安全性 → 辅助功能** 允许 EdgeClip，这样它才能帮你按 ⌘V。如果不允许，项目仍然会被复制，你自己按 ⌘V 就可以。

> 更新应用之后，可能需要在“辅助功能”列表中把 EdgeClip 关掉再重新打开。

## 隐私

- 历史记录只保存在 `~/EdgeClip/history.json`（图片在 `~/EdgeClip/images/`），不会发送到任何地方。
- 密码管理器标记为私密的内容（1Password、Bitwarden 等遵循 [nspasteboard.org](http://nspasteboard.org) 标准的工具）会自动跳过。
- 默认会忽略 1Password、Bitwarden、Keychain Access、Passwords、Dashlane 和 LastPass 的复制内容，可以在 **Settings → Clipboard** 修改。
- 随时点击面板最上方的“clipboard”即可暂停记录。

## 手动编译

```bash
swiftc -O -parse-as-library EdgeClip.swift -o EdgeClip
```

使用 macOS 26 或以上的 SDK 编译时，加上 `-D GLASS` 即可启用液态玻璃。`build.sh` 会自动处理这一步，也会自动解决 SDK 与编译器版本不匹配的问题。请用 `build.sh` 编译成应用，快捷键和辅助功能才能正常工作。

## 支持

如果 EdgeClip 每天帮你省下几次重新复制的时间，欢迎在这里支持：

- ☕ Buy Me a Coffee：https://buymeacoffee.com/sirene122

## 许可证

[MIT](LICENSE)
