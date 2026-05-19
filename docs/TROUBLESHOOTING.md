# TROUBLESHOOTING.md

> 給 **AI** 讀，遇到錯誤時參考。M2-M4 過程持續累積。

---

## 索引

- [App-Access-Control — Gmail settings write 永遠 403](#app-access-control--gmail-settings-write-永遠-403)
- [gws `--full` 拿到的 scope 比想像中少很多](#gws---full-拿到的-scope-比想像中少很多)
- [OAuth flow `invalid_scope` — 某個 scope 對第三方 client 不開放](#oauth-flow-invalid_scope--某個-scope-對第三方-client-不開放)
- [瀏覽器沒跳出 OAuth 同意畫面](#瀏覽器沒跳出-oauth-同意畫面)

---

## App-Access-Control — Gmail settings write 永遠 403
**症狀：**
- `gws gmail users settings filters create` / `setVacation` / 任何 `users.settings.*` 寫入 → `403 ACCESS_TOKEN_SCOPE_INSUFFICIENT`
- 同帳號同 token 的下列操作 **都正常**：
  - `gws gmail users messages modify`（訊息 label 寫入）
  - `gws gmail users settings filters list` / `getVacation`（settings 讀）
  - `gws gmail users messages list / get`
- `gws auth status` 確認 token 含 `https://mail.google.com/`（Gmail 最大 scope）
- Google `tokeninfo` 也確認 access token 帶這個 scope

**原因：** Workspace Admin Console 的「**App access control**」把這個 OAuth client 預設為 **Limited**（即使是內部 app）。Limited 允許讀，禁止 Gmail settings 寫入（filter / vacation / forwarding），但仍允許訊息 label 寫入。Google 回的 `ACCESS_TOKEN_SCOPE_INSUFFICIENT` 是誤導 — 不是 scope 不夠。

**解法（一次性，需 Workspace Super Admin）：**
1. 開 https://admin.google.com，用 dollbao.com.tw Super Admin 登入
2. **安全性 → API 控制項**（不是「設定」子頁，是 API 控制項主頁）
3. 「應用程式存取控管」區塊 → 點 **「管理應用程式存取權」**（在「173 個已存取的應用程式」下方）
4. 進「已設定的應用程式」清單 → 點 **「設定新的應用程式」**
5. 選 **「OAuth 應用程式名稱或用戶端 ID」**
6. 貼 client ID：`813181648456-h6lhgvdug2hjkncgjqg8hbb972o59q4j.apps.googleusercontent.com`
7. 找到 `gws-cli` → 勾選 → 下一步
8. Access type 選 **「已信任：可存取所有 Google 服務」**
9. 套用對象：**dollbao.com.tw**（整個 domain，不是某個 OU）
10. 儲存

**預防：** maintainer onboard 新 OAuth client 時必須走完這 10 步並驗證 filter.create 可用。**這在原本 INSTALL.md 沒寫**（2026-05 才發現），新建 OAuth client 後 Trust 切換是必要前置作業。

**已知傳播延遲：**
- Gmail message 寫入：Trust 切換後幾秒到幾分鐘生效
- **Gmail settings 寫入子系統（caribou backend）：傳播可達 1–24 小時**
- admin-reports activities.list：同樣慢
- Drive / Sheets / Calendar 等寫入：不受 App Access Control 影響（不過這層閘門）

**首次發現：** 2026-05-19（commit 待補）

---

## gws `--full` 拿到的 scope 比想像中少很多
**症狀：**
- 跑 `gws auth login --full`，`gws auth status` 只顯示 12 個 scope
- skill 如 `gws-forms` / `gws-keep` / `gws-chat*` / `gws-meet` / 任何需要 `gmail.settings.basic` 的操作（filter / vacation / forwarding 寫入）都 403

**原因：** `gws auth login --full` 的 `--help` 描述是「Request all scopes incl. pubsub + cloud-platform」，**實測「all」只是預設集合 + pubsub + cloud-platform**，固定 12 個 scope：
```
drive, spreadsheets, gmail.modify (← 注意是 modify 不是 mail.google.com/),
calendar, documents, presentations, tasks,
pubsub, cloud-platform,
openid, userinfo.email, userinfo.profile
```
**根本沒有** `gmail.settings.basic` / `forms` / `keep` / `chat` / `meet` / `contacts` / `classroom` / `script` / `admin.reports`。

**解法：** 用 `--scopes` 明確列出需要的 scope（見 INSTALL.md step 9 的 14-scope 範例）。

**預防：** 不要相信 gws CLI `--full` 的描述。需要什麼 scope 就明列什麼。

**首次發現：** 2026-05-19（commit 待補）

---

## OAuth flow `invalid_scope` — 某個 scope 對第三方 client 不開放
**症狀：**
- 點 OAuth 同意 URL → Google 顯示 **「禁止访问：发生了授权错误」**
- 錯誤詳情：`Some requested scopes cannot be shown: [https://www.googleapis.com/auth/keep]`
- 錯誤代碼：`400: invalid_scope`

**原因：** Google 對部分 Workspace API scope 有額外限制 — 即使 API 在 GCP project 已 enabled、OAuth consent 設 internal-only，scope 本身對第三方 OAuth client 仍不開放。**已知**會擋的：
- `https://www.googleapis.com/auth/keep` — Google Keep API 只給 first-party app
- 未來可能遇到：`chat.app.spaces`（workspace events）、某些 admin reports 細分 scope

**重要：** 只要 OAuth request 帶**任一**這類 scope，**整個 OAuth flow 會 fail-fast 400**，使用者連同意畫面都看不到。

**解法：**
1. 從 `--scopes` 清單拿掉壞的那個 scope，重跑 `gws auth login`
2. 該 scope 對應的 skill（如 `gws-keep`）暫時無法使用 — 等 Google 開放或找替代路徑

**預防：** 新增 scope 時逐個加，不要一次塞 20+。一個壞的會擋全部。

**首次發現：** 2026-05-19（commit 待補）

---

## 瀏覽器沒跳出 OAuth 同意畫面
**症狀：** 跑 `gws auth login`（任何形式）終端機 hang 住，但瀏覽器沒自動開新分頁。

**原因：** PowerShell 子程序無法呼叫預設瀏覽器（沙箱 / 環境變數缺失 / 預設瀏覽器設定壞）

**解法：**
1. 在跑 `gws auth login` 前設 `$env:BROWSER='echo'` —強制 gws 把 URL 印到 stdout 而非試圖開瀏覽器
2. 從終端機複製整段 URL（以 `prompt=select_account+consent` 結尾才是完整）
3. 貼到瀏覽器手動開
4. 點同意後瀏覽器會跳到 `http://localhost:<port>`，看到「Authentication successful」即可關閉
5. 終端機端的 gws 會接到 callback 自動完成

**預防：** Windows 環境變數 `BROWSER` 預先設 `echo`（避開 Windows shell 開瀏覽器的多重失敗點）

**首次發現：** 2026-05-19（commit 待補）

---

## 條目格式

每個條目按以下格式寫：

```markdown
### {錯誤標題}
**症狀：** 用戶 / 工具看到什麼  
**原因：** 為什麼會這樣  
**解法：** 怎麼修（步驟化）  
**預防：** 下次怎麼避免（可選）  
**首次發現：** YYYY-MM-DD（commit hash）
```

---

## 範例（佔位，M2 會被真實案例取代）

### winget 抓不到 OpenJS.NodeJS.LTS
**症狀：** `winget install OpenJS.NodeJS.LTS` 回 `No package found matching input criteria.`  
**原因：** winget source 沒更新，或 package id 已改名  
**解法：**
1. 跑 `winget source update`
2. 若仍失敗，跑 `winget search "node"` 找正確 id
3. 仍失敗 → 從 https://nodejs.org/ 手動下載 LTS 版本
**預防：** `manifest/common.json` 的 `fallback_url` 必須填寫
**首次發現：** ⏸️ M2
