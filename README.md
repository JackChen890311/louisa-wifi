# Louisa Wi-Fi ☕

自動連上全台任何一家路易莎咖啡的 Wi-Fi。

每家路易莎的 Wi-Fi 名稱都是 `LouisaCoffee`，但密碼是各店自己的電話號碼。macOS 一個 Wi-Fi 名稱只能存一組密碼，所以換一家店就連不上。這個 app 會認出你在哪一家店，自動換上正確的密碼。

## 安裝

```sh
curl -fsSL https://raw.githubusercontent.com/madeyexz/louisa-wifi/main/install.sh | bash
```

或從 [Releases](https://github.com/madeyexz/louisa-wifi/releases) 下載 `LouisaWiFi.zip`，解壓縮後放進「應用程式」。

第一次打開時請**允許定位**。app 用位置找最近的門市，也需要定位權限才能辨認連上的是哪一台路由器。允許之後，如果「系統設定 → 隱私權與安全性 → 定位服務」裡的 LouisaWiFi 還是關著，請手動打開。

需要 macOS 13 以上。

## 使用

裝好就不用管它。到了路易莎，Wi-Fi 斷線或附近出現 `LouisaCoffee` 時，app 會：

1. 如果這台路由器以前連過，直接用上次成功的密碼。
2. 否則用你的位置找最近的 3 家店，依序試它們的電話密碼。
3. 都不對就跳通知，請你從 menu bar 的 ☕ 選門市。選過一次就會記住。

menu bar 的 ☕ 裡有附近門市（依距離排序）、依縣市分類的所有門市，以及「自動連線」「只顯示連過的門市」「登入時開啟」三個選項。

### 路易莎時光

連上路易莎的每一分鐘都會記錄下來。從 ☕ 選「統計…」，會看到一張像 GitHub 貢獻圖的熱力圖：

- 右邊選「過去一年」或某一年
- 點一下格子（或用方向鍵移動）看那天在哪一家、待了多久
- 上方是這段期間的總時數、去了幾天、去過幾家、最長連續幾天、平均每次多久
- 下方可以切換「門市／月份／年份」：依門市排名（點一下門市，整張圖只看那一家）、最近 12 個月每月時數、每年時數（點一下跳到那一年）

Mac 睡眠時不會計時。

### 更新

app 每 6 小時檢查一次 GitHub 上有沒有新版本。有的話 ☕ 最上面會出現「更新到 x.y.z」，點一下就會自動下載、替換並重新開啟。也可以隨時從 ☕ 選「檢查更新」。

門市資料每週自動從官網重新抓取一次，有新門市或電話變更時會自動發布新版本，所以只要更新 app 就會拿到最新的門市。

## Raycast

[`raycast/louisa-wifi.js`](raycast/louisa-wifi.js) 是一個 Raycast Script Command：

- 輸入門市名稱或地址關鍵字（例如 `延平`、`大安 復興`），有好幾家符合時會讓你選一家。
- 留空就連最近的一家（需要安裝 app）。
- 有安裝 app 時交給 app 連線；沒有安裝時用 `networksetup` 自己連，所以只裝 Raycast 也能用。

安裝方式：從 [Releases](https://github.com/madeyexz/louisa-wifi/releases/latest) 下載 `louisa-wifi.js`，放進一個資料夾，再到 Raycast → Settings → Extensions → Script Commands → Add Directories 加入那個資料夾。

## 密碼規則

密碼是門市電話號碼去掉開頭的 `0`；台北（`02`）的店則是去掉整個 `02`。例如：

| 電話 | 密碼 |
|---|---|
| 02-2361-0718 | `23610718` |
| 04-2326-2617 | `423262617` |
| 03-338-0980 | `33380980` |

少數店家例外，所以每家店都有好幾組候選密碼，app 會依序嘗試。這個規則和 [Watermelon-1234/LouisaInternetSwitch](https://github.com/Watermelon-1234/LouisaInternetSwitch) 整理的資料比對，在兩邊都有的 459 家裡有 452 家一致。

## 門市資料

[`data/stores.json`](data/stores.json) 由 [`scripts/fetch_stores.py`](scripts/fetch_stores.py) 從[路易莎官網的門市查詢](https://www.louisacoffee.co/visit)抓取，包含名稱、地址、電話、經緯度和候選密碼。更新資料：

```sh
python3 scripts/fetch_stores.py
```

官網上有幾家店沒有電話，所以不在資料裡；也有一些店沒有經緯度，只能用名稱搜尋。

## 自己編譯

只需要 Xcode Command Line Tools（`xcode-select --install`）：

```sh
./build.sh          # 產生 build/LouisaWiFi.app 和 build/LouisaWiFi.zip
open build/LouisaWiFi.app
```

推一個 `v*` tag 到 GitHub，GitHub Actions 就會編譯並發布 Release。

## 隱私

所有資料都留在你的 Mac 上：連過的路由器記在 `~/Library/Application Support/LouisaWiFi/learned.json`，時間紀錄在同一個資料夾的 `usage.json`。app 只會連到兩個地方：`captive.apple.com`（確認有沒有網路）和 GitHub（檢查更新）。

## 授權

MIT
