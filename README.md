# Louisa Wi-Fi ☕

自動連上全台任何一家路易莎咖啡的 Wi-Fi。

路易莎各門市的 Wi-Fi 名稱都是 `LouisaCoffee`，但密碼依各門市的電話號碼而定。macOS 對同一個 Wi-Fi 名稱只能儲存一組密碼，所以換一家門市就可能連不上。這個 app 會辨識門市，自動使用對應的密碼。

## 安裝

```sh
curl -fsSL https://raw.githubusercontent.com/madeyexz/louisa-wifi/main/install.sh | bash
```

或從 [Releases](https://github.com/madeyexz/louisa-wifi/releases) 下載 `LouisaWiFi.zip`，解壓縮後放進「應用程式」。

第一次開啟時，請**允許使用定位服務**。app 會根據你的位置尋找最近的門市，也需要定位權限才能辨識目前連線的路由器。如果允許後仍未啟用，請到「系統設定 → 隱私權與安全性 → 定位服務」，手動開啟 LouisaWiFi 的定位權限。

需要 macOS 13 以上。

## 使用

安裝後，app 會在背景自動連線。到了路易莎，Wi-Fi 斷線或附近出現 `LouisaCoffee` 時，app 會：

1. 如果這台路由器以前連過，直接用上次成功的密碼。
2. 否則根據你的位置找最近的 3 家門市，依序嘗試用電話號碼組成的密碼。
3. 如果都連不上，就會發送通知，請你從選單列的 ☕ 選擇門市。成功連線後，app 會記住密碼。

選單列的 ☕ 選單中有附近門市（依距離排序）、依縣市分類的所有門市，以及「自動連線」、「只顯示連過的門市」和「登入時開啟」三個選項。

### 連線統計

app 會記錄連上路易莎 Wi-Fi 的時間。從 ☕ 選「連線統計…」，會看到一張類似 GitHub 貢獻圖的熱度圖：

- 在右側選擇「過去一年」或指定年份。
- 點選格子，查看當天的門市和連線時間。macOS 14 以上也可以用方向鍵移動。
- 上方顯示這段期間的總時數、到訪天數、門市數、最長連續天數，以及平均每天的連線時間（只計算有紀錄的日子）。
- 下方可以切換「門市／月份／年份」，查看各門市、各月或各年的連線時數。月份圖顯示最近 12 個月，或所選年份的 12 個月。點選門市可篩選該門市的紀錄；點選年份可切換到該年。

Mac 睡眠時不會計時。

### 更新

app 每 6 小時檢查一次 GitHub 上是否有新版本。有新版本時，☕ 選單最上方會出現「更新到 x.y.z」，點選後就會自動下載、安裝並重新開啟。也可以隨時從 ☕ 選擇「檢查更新」。

門市資料每週會自動從官網更新一次。有新門市或電話變更時，會自動發布新版本，更新 app 即可取得最新的門市資料。

## Raycast

[`raycast/louisa-wifi.js`](raycast/louisa-wifi.js) 是一個 Raycast Script Command：

- 輸入門市名稱或地址關鍵字（例如 `延平`、`大安 復興`）。如果有多家符合，會顯示清單供你選擇。
- 留空即可連線到最近的門市（需安裝 app）。
- 已安裝 app 時，會透過 app 連線；未安裝時，則使用 `networksetup` 連線，所以只裝 Raycast 也能用。

安裝方式：從 [Releases](https://github.com/madeyexz/louisa-wifi/releases/latest) 下載 `louisa-wifi.js`，放進一個資料夾，再到 Raycast → Settings → Extensions → Script Commands → Add Directories 加入那個資料夾。

## 密碼規則

密碼通常是門市電話號碼去掉開頭的 `0`；區碼為 `02` 的門市則去掉整個 `02`。例如：

| 電話 | 密碼 |
|---|---|
| 02-2361-0718 | `23610718` |
| 04-2326-2617 | `423262617` |
| 03-338-0980 | `33380980` |

少數門市使用不同的規則，因此 app 為每家門市準備了多組可能的密碼，並依序嘗試。與 [Watermelon-1234/LouisaInternetSwitch](https://github.com/Watermelon-1234/LouisaInternetSwitch) 整理的資料比對後，雙方都有收錄的 459 家門市中，有 452 家的密碼符合上述規則。

## 門市資料

[`data/stores.json`](data/stores.json) 由 [`scripts/fetch_stores.py`](scripts/fetch_stores.py) 從[路易莎官網的門市查詢](https://www.louisacoffee.co/visit)抓取，包含名稱、地址、電話、經緯度和候選密碼。更新資料：

```sh
python3 scripts/fetch_stores.py
```

部分門市在官網上未提供電話，因此未收錄；另有部分門市缺少經緯度，需手動選擇，或在 Raycast 中用名稱或地址搜尋。

## 自己編譯

只需要 Xcode Command Line Tools（`xcode-select --install`）：

```sh
./build.sh          # 產生 build/LouisaWiFi.app 和 build/LouisaWiFi.zip
open build/LouisaWiFi.app
```

將 `v*` 標籤推送到 GitHub 後，GitHub Actions 就會編譯並發布 Release。

## 隱私

連線與使用紀錄都儲存在你的 Mac 上：連過的路由器與密碼存放在 `~/Library/Application Support/LouisaWiFi/learned.json`，時間紀錄則存放在同一個資料夾的 `usage.json`。app 會連到 `captive.apple.com` 確認網路是否可用，並連到 GitHub 檢查及下載更新。

## 授權

MIT
