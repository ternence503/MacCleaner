# MacCleaner v1.0 - macOS 系統安全清理工具

一款安全、有感、小白也能上手的 macOS 系統清理工具。
清理完會告訴你釋放了多少空間，讓你真的感受到差異。

> **安全第一** — 絕對不碰個人檔案、對話紀錄、帳號設定。只清快取垃圾。

## 下載使用

1. 點右上角綠色 **Code** → **Download ZIP**
2. 解壓縮
3. 首次使用：開啟終端機，輸入 `chmod +x ` 後將 `啟動清理工具.command` 拖入視窗，按 Enter
4. 之後雙擊 `啟動清理工具.command` 即可執行
5. 選 `[1]` 一鍵全部清理

## 功能

- 使用者快取（`~/Library/Caches`）
- 使用者日誌（`~/Library/Logs`）
- 資源回收筒（確認後清空）
- 瀏覽器快取（Chrome / Safari / Firefox / Edge）
- **App 快取**（Discord / Slack / Zoom / Teams / Spotify / Homebrew）
- Xcode DerivedData（開發者用，偵測到才詢問）
- `.DS_Store` 隱藏檔
- 下載資料夾暫存檔（.tmp / .part / .crdownload）

## 支援系統

macOS 10.12 Sierra ～ macOS 15 Sequoia（所有版本）

## 安全說明

- **不需要管理員密碼** — 全部在使用者目錄操作
- 不會刪除個人檔案（文件、圖片、影片、音樂）
- 不會刪除 LINE 對話、Discord 設定、瀏覽器書籤密碼
- 不會碰系統核心目錄（SIP 保護區）
- 資源回收筒、Xcode 快取需手動確認才清除
- 所有操作有錯誤保護，檔案被占用時自動略過

## 更新日誌

### v1.0（2026-03-20）
- 初始發布
- 支援 8 項清理功能
- 雙語介面（中/英）
- 無需管理員密碼
