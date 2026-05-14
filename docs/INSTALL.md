# INSTALL.md — 逗寶新人 Claude Code 安裝劇本

> 這份文件是給 **Claude AI** 讀的。當新人貼完 bootstrap prompt 後，AI 會依本劇本一步步引導。
>
> ⏸️ **M2 階段：** Steps 8 / 10 / 11 已填完實際邏輯。Steps 1-7 / 12-13 在 M2.3 補完。

---

## 0. 對話原則

1. **繁體中文** — 所有訊息用繁體中文，工具名稱保留原文（winget、gh、gws、bq、npm...）
2. **每步驟先確認再動手** — 跑 `winget install` 前先說「我接下來要裝 Node.js LTS，約需 1 分鐘，可以嗎？」等用戶 OK 再跑
3. **失敗給明確中文錯誤** — 不要只貼英文 stack trace；先用人話說「網路抓不到 package」再附原始錯誤
4. **Idempotent** — 已裝的工具用 `Get-Command` 偵測到就 skip 並告知用戶「Node.js 已裝（v20.x），跳過此步驟」
5. **避免假設工程背景** — 對非工程同事用「桌面、檔案總管」等日常詞彙，不用「shell、stdout、env var」
6. **完成一個 milestone 後給進度條** — 「目前進度 3/13」

---

## 1. 安裝步驟總覽

| # | 步驟 | 工具 / 動作 | 預計時間 |
|---|---|---|---|
| 1 | 環境檢查 | PowerShell 偵測 Windows / winget / 網路 | 30 秒 |
| 2 | 裝 Node.js LTS | `winget install OpenJS.NodeJS.LTS` | 2 分鐘 |
| 3 | 裝 Git | `winget install Git.Git` | 1 分鐘 |
| 4 | 裝 GitHub CLI（可選） | `winget install GitHub.cli` | 1 分鐘 |
| 5 | 裝 Google Cloud SDK (含 gcloud + bq CLI) | `winget install Google.CloudSDK` | 3 分鐘 |
| **5.5** | **`gcloud auth login`** | 引導瀏覽器授權（用公司 dollbao.com.tw 帳號）| 1 分鐘 |
| ~~6~~ | ~~`gh auth login`~~ | **跳過** — repo 已 public，clone 不需 auth | — |
| 7 | Clone setup repo | `git clone https://github.com/ark0720/dollbao-claude-setup.git $env:USERPROFILE\.claude\dollbao-setup` | 30 秒 |
| **8** | **裝 gws CLI** | `npm install -g @googleworkspace/cli` | 1 分鐘 |
| **8.5** | **取 gws OAuth client** | `gcloud secrets versions access latest --secret=gws-oauth-client --project=dollbao-gws-cli` → `~/.config/gws/client_secret.json` | 5 秒 |
| 9 | `gws auth login` | 引導瀏覽器授權 | 1 分鐘 |
| 10 | 裝 gws skill bundle | 跑 `~/.claude/dollbao-setup/scripts/helpers/install-gws-bundle.ps1`（依 `manifest/skills-lock.json` 拉 ~85 個非 persona-* skill 到 `~/.claude/skills/`） | 2 分鐘 |
| 11 | 裝自製 skill | 跑 `~/.claude/dollbao-setup/scripts/helpers/install-dollbao-skills.ps1`（依 `manifest/common.json` 的 `skills[]` 複製到 `~/.claude/skills/`） | 30 秒 |
| 12 | `verify-install.ps1` | 自動檢查所有工具 / skill 都裝好 | 30 秒 |
| 13 | 5 題驗證 | AI 出題、用戶答 | 5 分鐘 |

**總計：約 20 分鐘。**（含 step 5.5 gcloud auth login 1 分鐘 + step 8.5 從 Secret Manager 拉 credentials 5 秒）

---

## 2. 各步驟細節

### 步驟 1：環境檢查
- **意圖：** 確認 Windows 版本、winget 可用、有網路
- **指令：** ⏸️ M2.3 填
- **成功判準：** ⏸️ M2.3 填
- **失敗 fallback：** ⏸️ M2.3 填
- **對話模板：** ⏸️ M2.3 填

### 步驟 2-5：裝基礎工具（Node / Git / gh / gcloud）
- **意圖：** 後續工具的前置依賴
- **共用模式：**
  1. `Get-Command {cmd}` 偵測 — 已有 → skip + 告知 user「已裝 (v...)」
  2. 否則跑 `winget install {id} --silent --accept-source-agreements --accept-package-agreements`
  3. 跑 `verify_cmd`（見 `manifest/common.json`）確認
  4. winget 失敗 → 提示 `fallback_url`（也在 common.json）讓 user 手動下載
- **指令細節：** ⏸️ M2.3 填（每步驟確認 winget id / silent flag / 驗證輸出格式）
- **對話模板：** ⏸️ M2.3 填

### 步驟 5.5：`gcloud auth login`
- **意圖：** 員工本人用公司 Google 帳號登入 gcloud，後續：(a) 步驟 8.5 從 Secret Manager 拉 OAuth credentials；(b) 未來 `dollbao-calendar` skill 查 BigQuery 用
- **前置：** Google Cloud SDK 已裝（步驟 5）
- **指令：** `gcloud auth login`
- **成功判準：** `gcloud auth list --filter=status:ACTIVE --format="value(account)"` 回傳 `xxx@dollbao.com.tw`
- **失敗 fallback：**
  - 用個人 gmail 登入 → 提醒 user 切換帳號（Secret Manager IAM 限定 `domain:dollbao.com.tw`）
  - 瀏覽器沒跳出 → 提示複製終端機印出的 URL 手動開
- **對話模板：** 「我接下來引導你登入 gcloud。請務必用你的 dollbao.com.tw 公司帳號（不是個人 gmail），否則後續取不到公司共用的設定。」

### 步驟 6：~~`gh auth login`~~（已跳過）
- **本步驟跳過。** `dollbao-claude-setup` repo 已設為 public，clone 不需要 GitHub 帳號或 auth
- gh CLI 本身仍裝（步驟 4），但只有 ark0720 自己日後維護 repo 時才用得到
- 如果 user 主動問起或希望也順便 auth（例如他自己也想用 gh CLI 做別的事），AI 才需引導 `gh auth login`

### 步驟 7：Clone setup repo
- **意圖：** 把本 repo 拉到 `~/.claude/dollbao-setup/`
- **指令：** `git clone https://github.com/ark0720/dollbao-claude-setup.git "$env:USERPROFILE\.claude\dollbao-setup"`
- **成功判準：** `Test-Path "$env:USERPROFILE\.claude\dollbao-setup\manifest\common.json"`
- **失敗 fallback：**
  - clone 失敗 → 多半是網路擋 github.com，提示 user 聯絡 IT
  - 目標資料夾已存在 → AI 改跑 `git -C "$env:USERPROFILE\.claude\dollbao-setup" pull` 更新

### 步驟 8：裝 gws CLI
- **意圖：** gws CLI 是所有 gws-* / recipe-* skill 的執行引擎（skill 內呼叫 `gws gmail +triage` 之類）
- **前置：** Node.js 已裝（步驟 2）
- **指令：**
  ```powershell
  npm install -g @googleworkspace/cli
  ```
- **成功判準：**
  ```powershell
  gws --version  # 應回傳 0.22.x 或更新
  ```
- **失敗 fallback：**
  - npm 失敗 → 從 https://github.com/googleworkspace/cli/releases 下載 binary 手動裝
  - PATH 找不到 `gws` → 提示重啟 PowerShell（npm global bin 需要 PATH 重載）
- **對話模板：** 「我接下來裝 Google Workspace CLI（gws），所有 gws-* skill 都靠它運作。約需 1 分鐘。可以嗎？」

### 步驟 8.5：從 Secret Manager 取 gws OAuth client
- **意圖：** gws CLI 跟 Google API 對話需要一組 OAuth client credentials。逗寶把這份 credentials 存在 GCP Secret Manager (`projects/dollbao-gws-cli/secrets/gws-oauth-client`)，IAM 限定 `domain:dollbao.com.tw`，新人本機透過 gcloud 拉取。
- **前置：** gcloud 已 auth 為 dollbao.com.tw 帳號（步驟 5.5）+ gws CLI 已裝（步驟 8）
- **指令：**
  ```powershell
  $gwsCfg = Join-Path $env:USERPROFILE ".config\gws"
  New-Item -ItemType Directory -Force -Path $gwsCfg | Out-Null
  $secretJson = gcloud secrets versions access latest `
    --secret=gws-oauth-client `
    --project=dollbao-gws-cli 2>&1
  if ($LASTEXITCODE -ne 0) {
      Write-Error "拉取 secret 失敗：$secretJson"
      throw "請確認步驟 5.5 用 dollbao.com.tw 帳號登入，或聯絡 ark0720 確認 secret 已上傳"
  }
  $secretJson | Set-Content -Path (Join-Path $gwsCfg "client_secret.json") -Encoding utf8 -NoNewline
  ```
- **成功判準：**
  - `Test-Path "$env:USERPROFILE\.config\gws\client_secret.json"` ✅
  - 檔案不為空且含合法 JSON（用 `Get-Content ... | ConvertFrom-Json | Select -ExpandProperty installed` 驗證有 `client_id` / `client_secret` 欄位）
- **失敗 fallback：**
  - `PERMISSION_DENIED` → 使用者不是 dollbao.com.tw 帳號，或 IAM 沒給好；要求 user 跑 `gcloud auth list` 確認帳號
  - `NOT_FOUND` → ark0720 還沒上傳 secret，請 user 聯絡 ark0720
  - 其他 → 把錯誤訊息原文貼回，請 user 找 ark0720
- **對話模板：** 「我接下來從公司 GCP 的 Secret Manager 拉 gws CLI 要用的 OAuth credentials。這只會發生一次，下一步 `gws auth login` 才是綁定你的個人 Workspace 帳號。」

### 步驟 9：`gws auth login`
- **意圖：** 把新人的 Google Workspace 帳號 OAuth 授權給 gws CLI
- **前置：** gws CLI 已裝（步驟 8）+ OAuth client 已配置（步驟 8.5）
- **指令：**
  ```powershell
  gws auth login
  ```
- **成功判準：** `gws auth status` 顯示 logged in + 用戶 email
- **常見坑：**
  - 用戶用個人 gmail 登入而非公司帳號 → skill 跑起來會權限不足。確認用 `@dollbao.com` 帳號（或公司實際 domain）
  - 瀏覽器沒跳出 → 提示複製終端機印出的 URL 手動開
- **對話模板：** ⏸️ M2.3 填

### 步驟 10：裝 gws skill bundle ⭐
- **意圖：** 把 ~85 個 gws-* / recipe-* skill 安裝到 `~/.claude/skills/`（排除 10 個 persona-*）
- **前置：** Git 已裝（步驟 3）、repo 已 clone（步驟 7）
- **指令：**
  ```powershell
  & "$env:USERPROFILE\.claude\dollbao-setup\scripts\helpers\install-gws-bundle.ps1"
  ```
- **背後做什麼：**
  1. 讀 `manifest/skills-lock.json` 拿 pinned commit + 95 個 skill blob_sha1
  2. 讀 `manifest/common.json` 的 `exclude_patterns: ["persona-*"]` 過濾
  3. `git clone googleworkspace/cli` 到 `$env:TEMP\dollbao-gws-mirror`
  4. `git checkout <pinned_commit>`
  5. 逐個 skill：`git hash-object` 驗 blob SHA1 vs lock → 通過則複製到 `~/.claude/skills/{name}/SKILL.md`
  6. 已存在且 hash 一致 → skip（idempotent）
- **支援的 flag：**
  - `-DryRun` 只看會做什麼不動檔
  - `-Force` 即使 hash 已對也覆蓋
- **成功判準：** 腳本最後輸出「✨ gws skill bundle 安裝完成」+ `Test-Path "$env:USERPROFILE\.claude\skills\gws-gmail-triage\SKILL.md"`
- **失敗 fallback：**
  - Hash mismatch → 跑 `scripts/helpers/generate-skills-lock.ps1` 重新生 lock（表示上游動了但本 repo 沒同步）
  - 上游 clone 失敗 → 檢查網路；若公司 firewall 擋 github.com，提示用戶聯絡 IT
- **對話模板：** 「我接下來把約 85 個 Google Workspace skill 裝到 Claude Code。會從上游 googleworkspace/cli 用我們鎖定的 commit 抓，逐個驗 hash 才寫入。約需 2 分鐘。」

### 步驟 11：裝自製 skill
- **意圖：** 把本 repo 的 `skills/dollbao-handbook` 與 `skills/dollbao-calendar`（以及未來新增的全員 skill）複製到 `~/.claude/skills/`
- **前置：** Repo 已 clone（步驟 7）
- **指令：**
  ```powershell
  & "$env:USERPROFILE\.claude\dollbao-setup\scripts\helpers\install-dollbao-skills.ps1"
  ```
- **背後做什麼：**
  1. 讀 `manifest/common.json` 的 `skills[]` 陣列
  2. 對每個 entry：`Copy-Item` 整個 skill 資料夾到 `~/.claude/skills/{id}/`
  3. 已存在且 SHA256 一致 → skip
- **成功判準：** 腳本輸出 + `Test-Path "$env:USERPROFILE\.claude\skills\dollbao-handbook\SKILL.md"`
- **失敗 fallback：** repo 缺檔 → 多半是 clone 不完整，重跑步驟 7
- **對話模板：** 「裝逗寶自製 skill（規章查詢、逗寶曆查詢），複製 2 個檔案。30 秒。」

### 步驟 12：跑 `verify-install.ps1`
- **意圖：** 自動檢查所有工具 + skill + auth 都到位
- **指令：**
  ```powershell
  & "$env:USERPROFILE\.claude\dollbao-setup\scripts\verify-install.ps1"
  ```
- **成功判準：** ⏸️ M2.4 補完（依 verify-install.ps1 的最終形式）

### 步驟 13：5 題驗證（見 §4）
- **意圖：** 真實對話驗證新人能用工具
- **流程：** AI 出題 → 用戶答 → AI 評分（見 §4）

---

## 3. 全員 skill 清單（步驟 11 安裝）

| Skill | 型態 | 觸發情境 |
|---|---|---|
| `dollbao-handbook` | 兩層索引型 | 公司規章查詢（請假、考核、Drive 規則、共用圖檔規則…） |
| `dollbao-calendar` | BQ 查詢型 | 逗寶曆（會計年度、第幾週、檔期、節氣特賣…） |

新增條目時，記得**先讀 MAINTAINER.md §4 判斷歸屬**（個人 / 草稿 / 全員 / 部門），確認是全員 skill 才走 §7 SOP 同步 `manifest/common.json`。

---

## 4. 驗證題（步驟 13）

裝完後 AI 出以下 5 題，看用戶能不能用：

1. **「我要上傳新的共用圖檔，命名規則和放置位置是？」**
   - 期待觸發：`dollbao-handbook`
   - 期待路徑：digest → 定位「共用圖檔建立規則」Doc → 讀完給出具體規則
   - 評分：能引用 Doc 具體章節 +1 / 給出位置 +1

2. **「今天是逗寶曆第幾週？下個檔期什麼時候？」**
   - 期待觸發：`dollbao-calendar`
   - 期待路徑：BQ query → 結果 → 人話回答
   - 評分：跑了 bq query +1 / 結果合理 +1

3. **「請幫我看今天 Google Calendar 行程」**
   - 期待觸發：`gws-calendar-agenda`
   - 評分：跑了 gws 指令拿到結果 +1

4. **「列出我未讀的 email 摘要」**
   - 期待觸發：`gws-gmail-triage`
   - 評分：跑了 gws 指令拿到結果 +1

5. **「list 我的 GCP project」**
   - 期待跑：`gcloud projects list`
   - 評分：能跑 gcloud（可能還沒 auth，AI 應提示 `gcloud auth login`）+1

---

## 5. Idempotent 原則

- **偵測已裝：** 用 `Get-Command {tool}` 或 `winget list --id {id}`，**不要** 重複跑安裝
- **skill 比 hash：** `install-gws-bundle.ps1` / `install-dollbao-skills.ps1` 內建 hash 比對，已對齊則 skip
- **auth 不重做：** `gh auth status` / `gws auth status` 顯示 OK 就 skip
- **對話可中斷重來：** 用戶 Ctrl+C 後重貼 bootstrap prompt，AI 應從中斷點繼續而非從頭

---

## 6. 失敗處理通則

| 錯誤類型 | 處理 |
|---|---|
| 網路 timeout | 重試 1 次，仍失敗 → 提示用戶檢查網路後重貼 prompt |
| winget 抓不到 package | fallback 到 `fallback_url`（在 `manifest/common.json`） |
| 權限不足 | 提示用系統管理員身分開新 PowerShell |
| `git clone` 失敗（步驟 7） | 多半是公司 firewall 擋 github.com，提示聯絡 IT |
| `gws auth login` 失敗 | (a) 檢查 step 8.5 是否成功拉到 client_secret.json；(b) 檢查是否為公司 Google 帳號（非個人 gmail） |
| step 8.5 `PERMISSION_DENIED` | user 不是 dollbao.com.tw 帳號（用個人 gmail 跑了 step 5.5）— 跑 `gcloud auth login` 換正確帳號 |
| step 8.5 `NOT_FOUND` | ark0720 還沒在 GCP 建 Secret `gws-oauth-client`，請聯絡他完成 `config/README.md` 內的設定 |
| step 5.5 `gcloud auth login` 用錯帳號 | 跑 `gcloud auth revoke --all` 後重做 step 5.5 |
| `npm install -g @googleworkspace/cli` 失敗 | 提示用 admin PowerShell 重跑；若 npm proxy 問題 → 設 `npm config set registry https://registry.npmjs.org/` |
| 步驟 10 hash mismatch | lock 與上游不一致；先跑 `generate-skills-lock.ps1` 更新 lock 再重試 |
| `bq query` 失敗（IAM） | 提示用戶聯絡 ark0720 確認群組成員資格 |

詳細案例見 [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)（M2-M4 累積）。

---

## 7. 部門判定 hook（Phase 2 預留）

⏸️ Phase 1 **跳過此步驟**。

Phase 2 上線時，本節會啟用：在步驟 11 後，AI 問用戶「你屬於哪個部門？」對應到 `manifest/dept-*.json` 並補裝該部門包。
