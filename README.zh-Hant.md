# EdgeClip ✿

[English](README.md) | **繁體中文** | [简体中文](README.zh-Hans.md)

**一個收在 Mac 螢幕邊緣的剪貼簿紀錄。**

十分鐘前複製過的東西，現在已經不見了？EdgeClip 會記住你複製過的所有內容，收在螢幕左邊一條細細的面板裡。滑鼠移過去（或按 ⌥⌘V），面板就會滑出來，點一下就能再次複製。

<!-- 可在這裡加入示範 GIF：![demo](docs/demo.gif) -->

## 功能

- 🫧 **滑過即看**：平時收在螢幕邊緣，滑鼠移過去就會彈出
- ⌨️ **鍵盤操作**：按 ⌥⌘V 打開，直接打字搜尋，用 ↑↓ 選擇，按 Return 複製，⌘1–9 選前九項
- ⚡ **直接貼上**（可選）：選好之後自動貼到你正在用的 App
- ★ **星號收藏**：常用的電郵範本、地址、連結。加星號的項目會固定在最上方，可以命名，而且永遠不會被清除
- 🧹 **自動刪除**：可設定沒有加星號的項目在 1 小時、1 日、7 日或 30 日後自動刪除
- 🔍 **搜尋與篩選**：All / Text / Links / Images / Colors
- 🖼 **自動辨識內容**：圖片有縮圖、色碼會顯示色塊（例如 `#AF52DE`）、連結會標示出來、檔案會顯示檔名，每一項都會顯示來自哪個 App
- 🔒 **預設保護私隱**：密碼管理工具標記為私密的密碼一律不會儲存，可以封鎖整個 App，隨時暫停記錄，所有資料只會留在你的 Mac 上
- 📌 **釘選常駐**：釘選後面板會變成液態玻璃（需要 macOS 26 或以上）
- 🎨 **全面自訂**：字型（可使用 Mac 上任何字型）、粗細、大小、文字顏色、強調色、背景色調、透明度、尺寸、圓角，以及放在左邊或右邊、上中下哪個位置
- 🪶 **輕巧原生**：只有一個 Swift 檔案，不需要任何套件、帳號或雲端

可以和 [EdgeTodo](https://github.com/tllct122/edge-todo-for-mac) 一起用：EdgeClip 在左邊，EdgeTodo 在右邊，兩者不會重疊。

## 安裝

需要 macOS 12 或以上（液態玻璃需要 macOS 26 或以上）。

1. 下載這個 repo（**Code → Download ZIP**），然後解壓縮
2. 打開「**終端機**」，輸入 `bash `（後面有一個空格），把 `build.sh` 拖進視窗，再按 Enter
3. 如果 macOS 要求安裝 **Command Line Tools**，安裝完成後再執行一次第 2 步

腳本會自動編譯 App、安裝到 `/Applications`，然後開啟它。

## 使用方法

| 動作 | 方法 |
|---|---|
| 打開面板 | 將滑鼠移到螢幕最左邊（上半部），或按 **⌥⌘V** |
| 再次複製 | 點擊該項目 |
| 用鍵盤操作 | **↑ ↓** 移動、**Return** 複製、**⌘1–9** 選前九項、**Esc** 關閉、**⌘⌫** 刪除 |
| 搜尋 | 在最上方的搜尋欄輸入 |
| 加星號 | 滑鼠移到項目上，點擊 ☆ |
| 為星號項目命名 | 右鍵 → **Name…** |
| 開啟連結／顯示檔案 | 右鍵 → **Open Link**／**Show in Finder** |
| 暫停記錄 | 點擊面板最上方的「clipboard」，或選單列 📋 圖示 → **Pause Recording** |
| 清除紀錄 | 點擊最底部的 **clear**（星號項目會保留） |
| 自動刪除舊紀錄 | **Settings → Clipboard → Delete unstarred clips after** 選 1 小時／1 日／7 日／30 日（星號項目會保留） |
| 保持面板開啟 | 點擊 📌 |
| 設定 | 點擊面板上的 ⚙︎，或選單列 📋 圖示 → **Settings…**（⌘,） |
| 開機自動啟動 | 選單列 📋 圖示 → **Open at Login** |

### 直接貼上

在 **Settings → Clipboard** 開啟 **Paste right away when I pick a clip**。macOS 會要求你在 **系統設定 → 私隱與安全性 → 輔助使用** 允許 EdgeClip，這樣它才能幫你按 ⌘V。如果不允許，項目仍然會被複製，你自己按 ⌘V 就可以。

> 更新 App 之後，可能需要在「輔助使用」列表中把 EdgeClip 關掉再重新打開。

## 私隱

- 紀錄只會儲存在 `~/EdgeClip/history.json`（圖片在 `~/EdgeClip/images/`），不會傳送到任何地方。
- 密碼管理工具標記為私密的內容（1Password、Bitwarden 等遵循 [nspasteboard.org](http://nspasteboard.org) 標準的工具）會自動略過。
- 預設會忽略 1Password、Bitwarden、Keychain Access、Passwords、Dashlane 和 LastPass 的複製內容，可以在 **Settings → Clipboard** 修改。
- 隨時點擊面板最上方的「clipboard」即可暫停記錄。

## 手動編譯

```bash
swiftc -O -parse-as-library EdgeClip.swift -o EdgeClip
```

使用 macOS 26 或以上的 SDK 編譯時，加上 `-D GLASS` 即可啟用液態玻璃。`build.sh` 會自動處理這一步，也會自動解決 SDK 與編譯器版本不相符的問題。請用 `build.sh` 編譯成 App，快捷鍵和輔助使用功能才能正常運作。

## 支持

如果 EdgeClip 每天幫你省下幾次重新複製的時間，歡迎在這裡支持：

- ☕ Buy Me a Coffee：https://buymeacoffee.com/sirene122

## 授權

[MIT](LICENSE)
