# TROUBLESHOOTING.md

> 給 **AI** 讀，遇到錯誤時參考。M2-M4 過程持續累積。

---

## 索引

- [App-Access-Control — Gmail settings write 永遠 403](#app-access-control--gmail-settings-write-永遠-403)
- [gws `--full` 拿到的 scope 比想像中少很多](#gws---full-拿到的-scope-比想像中少很多)
- [OAuth flow `invalid_scope` — 某個 scope 對第三方 client 不開放](#oauth-flow-invalid_scope--某個-scope-對第三方-client-不開放)
- [OAuth flow 「Some requested scopes were invalid」— consent screen allowlist 不夠（不是 Trust 問題）](#oauth-flow-some-requested-scopes-were-invalid--consent-screen-allowlist-不夠不是-trust-問題)
- [Chat API 404 「Google Chat app not found」— scope 有也叫不動](#chat-api-404-google-chat-app-not-found--scope-有也叫不動)
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

**原因：** Google 對部分 Workspace API scope 有額外限制 — 即使 API 在 GCP project 已 enabled、OAuth consent 設 internal-only，scope 本身對第三方 OAuth client 仍不開放。

**2026-05-19 ark 機實測結果（在 dollbao-gws-cli OAuth client 上）：**
- ✅ **開放**：mail.google.com / drive / spreadsheets / calendar / documents / presentations / tasks / forms.body / forms.responses.readonly / chat.messages / chat.spaces / meetings.space.created / meetings.space.readonly / contacts / contacts.readonly / classroom.courses / script.projects / pubsub / admin.directory.group(.member) / admin.directory.user.readonly / admin.reports.audit.readonly / cloud-platform / openid / userinfo.* — 共 26 個
- ❌ **擋住**：`https://www.googleapis.com/auth/keep` — Google Keep API 只給 first-party app（gws-keep skill 不可用）
- ⚠️ **未測（謹慎觀察）**：`chat.app.spaces`（Workspace Events 用）、`admin.directory.user` 寫入版本、`vault` 系列

**重要：** 只要 OAuth request 帶**任一**這類 scope，**整個 OAuth flow 會 fail-fast 400**，使用者連同意畫面都看不到。所以**新增 scope 必須先在 maintainer 機驗證再加入 INSTALL.md**。

**解法：**
1. 從 `--scopes` 清單拿掉壞的那個 scope，重跑 `gws auth login`
2. 該 scope 對應的 skill（如 `gws-keep`）暫時無法使用 — 等 Google 開放或找替代路徑

**預防：** 新增 scope 時逐個加，不要一次塞 20+。一個壞的會擋全部。

**首次發現：** 2026-05-19（commit 待補）

---

## OAuth flow 「Some requested scopes were invalid」— consent screen allowlist 不夠（不是 Trust 問題）

**症狀：**
- 點 OAuth 同意 URL → 用戶帳號登入後 → Google 直接跳 **「已封鎖存取權：授權錯誤」**
- 錯誤詳情顯示一大段：`Some requested scopes were invalid. {valid=[...一串還在 allowlist 上的 scope...]}`
- 看 URL 是 `accounts.google.com/info/...` 之類的錯誤頁，不是 unknownerror

**重要：跟「invalid_scope 400」是不同症狀**
| 症狀 | 原因 | 解法 |
|---|---|---|
| `400: invalid_scope` + 「Some requested scopes cannot be shown: [scope]」 | scope 本身對第三方 OAuth client 整個不開放（如 keep） | 拿掉那個 scope，永遠不能加 |
| **「Some requested scopes were invalid」+ valid list** | scope 沒在這個 OAuth client 的「資料存取權」allowlist 上 | 在 GCP Console 補進去就好 |

**重要：跟 App-Access-Control「Trust 升級」也無關**
有些 AI 會誤判建議去 Workspace Admin Console 升 Trust——**不要做**。Trust 升級是給「已登入成功但 API 寫入子系統被擋（如 Gmail filter.create）」的，不影響 OAuth flow 本身能不能通過。如果連 consent 都過不去，問題在 OAuth client 的 consent screen，不在 Workspace Admin Console。

**根因：OAuth consent screen 的「資料存取權」是強制 allowlist**

GCP Console 「Google Auth Platform → 資料存取權」這個 scope 清單不是「顯示給用戶看的清單」而已，而是 **強制 allowlist**。
- Client request 的 scope 全部都要在這清單上，**只要有一個不在 allowlist，Google 直接擋掉整個 OAuth flow**（不像 silent drop 那樣容忍，而是顯式報「scopes were invalid」）。
- valid 清單就是 Google 告訴你「目前 allowlist 上有這些」，方便你比對缺什麼。

**診斷流程（30 秒判斷）：**

1. 先確認 client_id：跑 `gcloud secrets versions access latest --secret=gws-oauth-client --project=dollbao-gws-cli | python -c "import json,sys; print(json.load(sys.stdin)['installed']['client_id'])"` 看是不是 `813181648456-flanumqvc...`。如果不是 → client_secret.json 拉錯了，重做 INSTALL step 8.5。

2. 確認後：開 `https://console.cloud.google.com/auth/scopes?project=dollbao-gws-cli`，看「資料存取權」清單是否含 INSTALL.md step 9 `$scopes` 陣列的所有項目。

3. 缺哪個就在「新增或移除範圍」→「手動新增範圍」貼進去 → Save。

**解法：**
- 員工：**什麼都不用改**。等 maintainer 補完 allowlist 後 `gws auth logout && gws auth login --scopes ...` 重做一次就 OK。
- Maintainer：按診斷流程 step 2-3 補 allowlist。注意**絕對不要加 `https://www.googleapis.com/auth/directory.readonly`**（已知 culprit，加進 50+ scope 集合會讓 OAuth flow 跳 `unknownerror`，見 memory `oauth-scope-249-classification`）。

**首次發現：** 2026-05-21（rose@dollbao.com.tw 撞到，commit cfca835 後可用 44 scope 通過）

**為什麼會搞錯方向：** 之前另一個 AI session 看到「已封鎖存取權」直覺以為是 OAuth app 在 Testing mode 沒加測試者、或 Workspace Trust 沒升，浪費了一輪溝通。**辨識重點：右側錯誤詳情有沒有 `Some requested scopes were invalid` + `valid=[...]` 清單——有就是 allowlist 問題，跟 Trust / 測試者名單都無關。**

---

## Chat API 404 「Google Chat app not found」— scope 有也叫不動
**症狀：**
- OAuth 已成功拿到 `chat.messages` + `chat.spaces` scope，`gws auth status` 確認
- 跑 `gws chat spaces list` 或任何 chat API → 回傳 `404: Google Chat app not found. To create a Chat app, you must turn on the Chat API and configure the app in the Google Cloud console.`

**原因：** Google Chat API 不像其他 Workspace API（用個人 OAuth scope 就能呼叫），它要求**呼叫端必須是一個註冊過的「Chat app」**。註冊步驟在 Google Cloud Console → APIs & Services → Google Chat API → Configuration，需要：
- App name / Avatar URL / Description
- Functionality（messaging / bot / etc.）
- Trigger 設定（DMs / spaces / slash commands）
- Connection settings

純粹用 user OAuth scope 呼叫 chat.* API 不夠，永遠是 404。

**影響的 skill / recipe：**
- `gws-chat` / `gws-chat-send`
- `recipe-send-team-announcement`（同時用 Gmail + Chat）— Chat 那半會掛
- `recipe-post-mortem-setup` 的 Chat 通知部分

**解法（一次性後台作業）：**
1. 開 https://console.cloud.google.com/apis/library/chat.googleapis.com?project=dollbao-gws-cli
2. 確認 Chat API enabled（應該已 enabled）
3. 進 APIs & Services → 找到 Google Chat API → **Configuration** 分頁
4. 填寫 App name = `dollbao-gws-cli`、Avatar URL（任意 https）、Description
5. Functionality 勾「Receive 1:1 messages」+「Join spaces and group conversations」
6. Connection settings 選「App URL」（無 endpoint 也可，重點是註冊存在）
7. Permissions 選「Specific people and groups in your domain」加 `_HQ@dollbao.com.tw`
8. Save

**儲存後 chat.* API 應立即可用**（不像 App Access Control 有 24h 傳播延遲）。

**預防：** 新建 OAuth client 後，若 skill bundle 含 chat skill，maintainer 應立即跑這個 Chat app 註冊。

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
