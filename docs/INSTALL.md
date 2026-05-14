# INSTALL.md — 逗寶新人 Claude Code 安裝劇本

> 這份文件是給 **Claude AI** 讀的。當新人貼完 bootstrap prompt 後，AI 會依本劇本一步步引導。
>
> ⏸️ **M1 階段為骨架**，每步驟的「指令 / 判準 / fallback / 對話模板」詳細內容於 M2 補完。

---

## 0. 對話原則

1. **繁體中文** — 所有訊息用繁體中文，工具名稱保留原文（winget、gh、gws、bq...）
2. **每步驟先確認再動手** — 跑 `winget install` 前先說「我接下來要裝 Node.js LTS，約需 1 分鐘，可以嗎？」等用戶 OK 再跑
3. **失敗給明確中文錯誤** — 不要只貼英文 stack trace；先用人話說「網路抓不到 package」再附原始錯誤
4. **Idempotent** — 已裝的工具用 `Get-Command` 偵測到就 skip 並告知用戶「Node.js 已裝（v20.x），跳過此步驟」
5. **避免假設工程背景** — 對非工程同事用「桌面、檔案總管」等日常詞彙，不用「shell、stdout、env var」
6. **完成一個 milestone 後給進度條** — 「目前進度 3/12」

---

## 1. 安裝步驟總覽

| # | 步驟 | 工具 | 預計時間 |
|---|---|---|---|
| 1 | 環境檢查 | PowerShell 偵測 | 30 秒 |
| 2 | 裝 Node.js LTS | `winget OpenJS.NodeJS.LTS` | 2 分鐘 |
| 3 | 裝 Git | `winget Git.Git` | 1 分鐘 |
| 4 | 裝 GitHub CLI | `winget GitHub.cli` | 1 分鐘 |
| 5 | 裝 Google Cloud SDK | `winget Google.CloudSDK` | 3 分鐘 |
| 6 | `gh auth login` | 引導瀏覽器授權 | 1 分鐘 |
| 7 | Clone repo | `gh repo clone ark0720/dollbao-claude-setup ~/.claude/dollbao-setup` | 30 秒 |
| 8 | `gws auth login` | 引導瀏覽器授權 | 1 分鐘 |
| 9 | 裝 gws skill bundle | 依 `manifest/skills-lock.json` 安裝 ~93 個 gws-* / recipe-* skill（排除 persona-*） | 2 分鐘 |
| 10 | 裝自製 skill | 把 `~/.claude/dollbao-setup/skills/*` 複製到 `~/.claude/skills/` | 30 秒 |
| 11 | `scripts/verify-install.ps1` | 自動檢查 | 30 秒 |
| 12 | 5 題驗證 | AI 出題、用戶答 | 5 分鐘 |

**總計：約 20 分鐘。**

---

## 2. 各步驟細節（M2 補完）

### 步驟 1：環境檢查
- **意圖：** 確認 Windows 版本、winget 可用、有網路
- **指令：** ⏸️ M2 填
- **成功判準：** ⏸️ M2 填
- **失敗 fallback：** ⏸️ M2 填
- **對話模板：** ⏸️ M2 填

### 步驟 2：裝 Node.js LTS
- **意圖：** 部分 MCP / 工具跑在 Node
- **指令：** `winget install OpenJS.NodeJS.LTS --silent`（M2 確認）
- **成功判準：** `node --version` 回傳 v20+
- **失敗 fallback：** 從 https://nodejs.org/ 手動下載 LTS
- **對話模板：** ⏸️ M2 填

### 步驟 3-12
⏸️ M2 補完。

---

## 3. 全員 skill 清單（步驟 10 安裝）

| Skill | 型態 | 觸發情境 |
|---|---|---|
| `dollbao-handbook` | 兩層索引型 | 公司規章查詢（請假、考核、Drive 規則、共用圖檔規則…） |
| `dollbao-calendar` | BQ 查詢型 | 逗寶曆（會計年度、第幾週、檔期、節氣特賣…） |

新增條目時，記得同步 `manifest/common.json` 的 `skills` 陣列（見 MAINTAINER.md §4）。

---

## 4. 驗證題（步驟 12）

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
- **skill 比 hash：** 對 `~/.claude/skills/{name}/SKILL.md` 算 SHA256，比對 `manifest/skills-lock.json`，相同則 skip
- **auth 不重做：** `gh auth status` / `gws auth status` 顯示 OK 就 skip
- **對話可中斷重來：** 用戶 Ctrl+C 後重貼 bootstrap prompt，AI 應從中斷點繼續而非從頭

---

## 6. 失敗處理通則

| 錯誤類型 | 處理 |
|---|---|
| 網路 timeout | 重試 1 次，仍失敗 → 提示用戶檢查網路後重貼 prompt |
| winget 抓不到 package | fallback 到官方 installer URL |
| 權限不足 | 提示用系統管理員身分開新 PowerShell |
| `gh auth login` 沒走完 | 引導重跑，並提示用 HTTPS protocol（非 SSH） |
| `gws auth login` 失敗 | 檢查是否為公司 Google 帳號（非個人 gmail） |
| `bq query` 失敗（IAM） | 提示用戶聯絡 ark0720 確認群組成員資格 |

詳細案例見 [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)（M2-M4 累積）。

---

## 7. 部門判定 hook（Phase 2 預留）

⏸️ Phase 1 **跳過此步驟**。

Phase 2 上線時，本節會啟用：在步驟 10 後，AI 問用戶「你屬於哪個部門？」對應到 `manifest/dept-*.json` 並補裝該部門包。
