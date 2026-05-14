# config/ — 公司層級設定檔

這個資料夾放 **ark0720 一次性設定** 後給全公司新人共用的設定（OAuth client、未來其他共用 config）。
新人安裝劇本（`docs/INSTALL.md`）會把這裡的檔案複製到新人本機對應位置。

---

## `gws-client-secret.json`

**用途：** gws CLI 跟 Google Workspace API 對話用的 OAuth 2.0 client credentials。
**新人安裝時複製到：** `~/.config/gws/client_secret.json`
**對應 INSTALL.md 步驟：** step 8.5

### ark0720 首次設定流程（一次性，~15 分鐘）

1. **登入 [Google Cloud Console](https://console.cloud.google.com/)**（用 ark0720@dollbao 帳號或 admin 帳號）

2. **建專案** `dollbao-internal-tools`（或你喜歡的名字）

3. **OAuth consent screen**（左側 APIs & Services → OAuth consent screen）
   - User Type: **Internal**（限定 @<你的 Workspace domain>）
   - App name: `逗寶內部工具` 或 `DollBao Internal Tools`
   - User support email: 你的公司 email
   - Developer contact: 你的公司 email
   - Scopes: 加上 gws CLI 需要的（建議直接 `.../auth/userinfo.email` + `.../auth/gmail.modify` + `.../auth/calendar` + `.../auth/drive` + `.../auth/documents` + `.../auth/spreadsheets` 等；查 gws CLI 官方說明確認完整清單）

4. **啟用 API**（APIs & Services → Enabled APIs → Enable APIS AND SERVICES）逐個啟用：
   - Gmail API
   - Google Calendar API
   - Google Drive API
   - Google Docs API
   - Google Sheets API
   - Google Chat API
   - Google Tasks API
   - Google Forms API
   - Google Slides API
   - People API
   - Google Keep API
   - Google Meet API
   - Google Classroom API
   - Apps Script API

5. **建立 OAuth Client ID**（APIs & Services → Credentials → Create Credentials → OAuth Client ID）
   - Application type: **Desktop app**
   - Name: `dollbao-claude-setup gws CLI`
   - Create 後會跳出 client_id + client_secret 視窗

6. **下載 JSON**（建好後在 Credentials 列表那一列右側「↓」按鈕）
   - 檔名長得像 `client_secret_xxxx.apps.googleusercontent.com.json`

7. **取代本資料夾 placeholder**：
   - 用步驟 6 下載的 JSON **完整內容** 覆蓋 `config/gws-client-secret.json`（保留檔名）
   - 跑 `git diff config/gws-client-secret.json` 確認 placeholder 已被替換
   - commit & push

8. **驗證：** 在 ark0720 本機跑 `scripts/verify-install.ps1`，應該不再警告 placeholder

### 為何此檔放 public repo 可以接受

Google 官方文件對 Desktop app OAuth client 的說法：

> "The process of granting access does not require that you keep the client secret confidential since installable applications are distributed to users in unencrypted form."

也就是說：
- ✅ Desktop app 的 client_secret 不算傳統意義的「密」
- ✅ 任何拿到 client_id + secret 的人，仍然要走 OAuth 用戶授權流程，不能直接讀資料
- ✅ OAuth consent screen 設成 Internal 後，外人連 consent 畫面都看不到

但仍應**避免在公開場合（Twitter、Stack Overflow）貼出 client_secret**，雖然不致命但不必要。

### 未來想加強

如果 ark0720 後來覺得 public repo 放 client_secret 還是不舒服，可以改用：
- 環境變數：`GOOGLE_WORKSPACE_CLI_CLIENT_ID` / `_CLIENT_SECRET`（新人本機設定）
- 公司 Drive 共享連結（@dollbao.com 限定），AI 在 install session 引導新人手動下載

需要時再開 issue / PR 改架構。
