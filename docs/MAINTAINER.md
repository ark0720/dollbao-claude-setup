# MAINTAINER.md — `dollbao-claude-setup` 維護憲法

> 這份文件是給 **Claude AI** 讀的。當 ark0720 對 Claude 說「幫我加一個 X skill」「開部門包」「改 manifest」「同步 digest」之類的指令時，AI 必須先讀完本文件對應 SOP 章節再動手。

---

## 0. 總原則

1. **不破壞既有 AI 對話式安裝流程** — 任何改動都不能讓既有 bootstrap prompt 跑壞
2. **新增優於重構** — Phase 2 加部門包時，新增檔案而不改既有檔案結構
3. **schema 變動需同步更新 `manifest/schema.md`** — 否則未來 AI 會猜錯
4. **每次改動開 PR，不要直接 push main**
5. **改完務必更新 `docs/INSTALL.md` 對應段落**（若安裝順序受影響）
6. **動手前先列出將改動哪些檔案讓用戶確認**

---

## 1. Repo 各檔案職責

| 路徑 | 受眾 | 內容 | 動到時要小心什麼 |
|---|---|---|---|
| `README.md` | 人類（ark0720 / 同事） | repo 總覽 + 維護入口 | 改完要保證仍指向正確的 docs 連結 |
| `docs/INSTALL.md` | **AI**（新人 session） | 安裝劇本（每步指令、判準、fallback、對話模板）| 改順序前先想 idempotent 是否還成立 |
| `docs/MAINTAINER.md` | **AI**（維護 session） | 本文件 | 改本文件前先想是否會讓既有 SOP 失效 |
| `docs/ONBOARDING.md` | 人類（新人） | 完整入職流程（同步 Notion / 投影片） | 改完要同步 Notion |
| `docs/TROUBLESHOOTING.md` | **AI**（除錯 session） | 常見錯誤 + 解法 | 純累積式，新增無妨 |
| `manifest/common.json` | **AI**（安裝 session） | 全員必裝項目清單 | 要符合 `manifest/schema.md` 規格 |
| `manifest/dept-*.json` | **AI**（Phase 2 安裝 session） | 部門特定安裝清單 | Phase 2 才會有 |
| `manifest/skills-lock.json` | **AI**（安裝 session） | gws bundle 的 git commit + content hash | 重新生成需驗證 hash |
| `manifest/schema.md` | **AI**（維護 session） | manifest 結構規格 | 改 schema 後同步所有 *.json |
| `skills/dollbao-*/SKILL.md` | **Claude Code 載入** | 自製 skill 內容 | 改 frontmatter `name` / `description` 會影響 AI 觸發 |
| `scripts/verify-install.ps1` | **AI**（安裝 session 末段呼叫） | 自動檢查所有工具裝好 | 改完要在 CI 跑過 |
| `.github/workflows/verify.yml` | GitHub Actions | CI：跑 verify + schema 檢查 | 改 workflow 要在 PR 試跑 |

---

## 2. Skill 四種寫法判斷準則

新增 skill 前先判斷屬於哪一型，避免用錯模式：

### 2a. 流程型（procedural）
- **特徵：** AI 跟用戶對話、依序執行步驟、每步確認
- **例子：** `dollbao-onboarding`（安裝流程本身）
- **寫法：** frontmatter `description` 寫清楚觸發情境；body 列步驟、判準、對話模板；不嵌入大塊資料

### 2b. 兩層索引型（two-tier index）
- **特徵：** 資料源在 Google Sheet / Drive，skill body 內嵌 digest 幫 AI 路由
- **例子：** `dollbao-handbook`（規章查詢）
- **寫法：**
  - body 內含 digest 區塊（每項 2-3 句摘要 + 5-10 個關鍵詞 + 涵蓋情境 + Doc ID）
  - digest 由獨立 session 預先產生，定期同步（季度或內容大改時）
  - 若 digest 沒覆蓋 → fallback 去讀 spreadsheet 索引 → 再讀對應 Doc
- **digest 同步 SOP 見 §6**

### 2c. BQ 查詢型（BigQuery-backed）
- **特徵：** Source of truth 在 BigQuery，skill 給 AI 看 schema + 範例 SQL，觸發時即時組 query
- **例子：** `dollbao-calendar`（逗寶曆）
- **寫法：**
  - body 列 project / dataset / table 路徑
  - 列完整 schema（欄位名 + 型別 + 說明）
  - 列 3-5 個範例 SQL（涵蓋常見問題型態）
  - 權限備註：失敗時提示 `gcloud auth login`

### 2d. 上游 mirror 型（upstream mirror）
- **特徵：** 從 GitHub 開源 repo mirror，含 lock file 確保版本可重現
- **例子：** gws-* 整個 bundle（mirror 自 `googleworkspace/cli`）
- **寫法：**
  - 不直接放 skill 內容，由 `manifest/skills-lock.json` 指向上游 commit
  - 安裝時由 AI 依 lock 拉內容
  - 要重新 mirror 時，跑 mirror 工具更新 lock，PR 內附 diff 說明
- **gws bundle 更新 SOP 見 §8**

---

## 3. Manifest schema 摘要

完整規格見 [`../manifest/schema.md`](../manifest/schema.md)。要點：

- `manifest/common.json` — 全員必裝（Phase 1 範圍）
- `manifest/dept-{key}.json` — 部門包（Phase 2 預留，key 例：`marketing-sales`、`finance`、`hr`）
- `manifest/skills-lock.json` — gws bundle 鎖版資訊

任何 manifest 改動，須通過 `scripts/helpers/validate-manifest.ps1`（M2 補完）。

---

## 4. SOP — 新增全員 skill

> 觸發句：「幫我加一個叫 X 的全員 skill」

1. **判斷型態** — 依 §2 判斷屬於哪型（流程 / 索引 / BQ / mirror）
2. **跟用戶確認名稱、description、資料源** — 不要憑空捏，特別是 description（影響 AI 觸發）
3. **scaffold** `skills/X/SKILL.md` — 按型態套對應 template（可參考 `dollbao-handbook` 或 `dollbao-calendar`）
4. **加進 `manifest/common.json`** 的 `skills` 陣列
5. **更新 `docs/INSTALL.md`** 的「全員 skill」清單區段
6. **更新 `README.md`** 的「Phase 1 範圍」表（若是 user-visible 的新 skill）
7. **本地測試** — 把 skill 複製到 `~/.claude/skills/X/`，重啟 Claude Code，問觸發句驗證能進
8. **開 PR** — PR 描述附觸發句 + 測試證據

⚠️ persona-* skill **不要** 加進 `common.json`，那是 role-specific，留給 Phase 2 部門包或用戶自選。

---

## 5. SOP — Phase 2 新增部門包

> 觸發句：「開 {部門} 安裝包，要包含 X、Y、Z」

部門 key 命名規則：`{dept-name-with-dashes}`（小寫、英文、用 `-` 連字）。例：`marketing-sales`、`finance`、`hr`。

1. **確認部門 Google 群組 email**（用來控管 IAM）
2. **新增 `manifest/dept-{key}.json`** — 按 [`schema.md §2`](../manifest/schema.md) 寫
3. **更新 `docs/INSTALL.md`** 啟用「部門判定 hook」段落：
   - 在 bootstrap 對話流程的「裝 common manifest 後」插入判定點
   - AI 問用戶：「你屬於哪個部門？」→ 對應到 `dept-*.json`
4. **若部門包含新 MCP server**（如 Windsor、GA4）：
   - 在 `docs/INSTALL.md` 補 MCP server 安裝 + auth 流程
5. **若部門包含新 BQ skill**：
   - 確認對應 IAM 設定文件已寫好（給 ark0720 在 GCP 操作的 checklist）
6. **更新 `README.md` 的「Phase 2 範圍」表**
7. **開 PR**

---

## 6. SOP — 規章 digest 同步

> 觸發句：「規章 Doc 有更新，幫我重新生成 dollbao-handbook 的 digest」

⚠️ **建議在獨立 session 跑**，因為要讀大量 Doc，會吃 context。

1. 用 `gws-sheets-read` 讀規章索引 spreadsheet `1zz19TNY_EfHxAbwEgTJqdJgJbGeH51K71RcBz-JVEMY`
2. 對每份規章 Doc：
   - 用 `gws-docs` 讀完整內容
   - 產生 2-3 句摘要 + 5-10 個關鍵詞 + 涵蓋情境 + Doc ID
3. 組裝 digest markdown 區塊
4. 取代 `skills/dollbao-handbook/SKILL.md` 內既有 digest 區段（標記 `<!-- digest-start -->` 與 `<!-- digest-end -->` 之間）
5. 跑 dry-run：問幾題規章問題，看 AI 是否從 digest 能正確路由
6. 開 PR，描述附「本次新增/異動的規章清單」

---

## 7. SOP — 逗寶曆 BQ schema 變動

> 觸發句：「逗寶曆 BQ table 加了新欄位 X」

1. 用 `bq show --schema --format=prettyjson {project}:{dataset}.{table}` 取最新 schema
2. 更新 `skills/dollbao-calendar/SKILL.md` 的 schema 區段
3. 若新欄位帶來新查詢情境，加 1-2 個範例 SQL
4. 本地測試（觸發 skill 問新欄位相關問題）
5. 開 PR

---

## 8. SOP — gws bundle 更新

> 觸發句：「上游 googleworkspace/cli 有更新，幫我同步」

1. 用 mirror 工具（M2 確認）重新拉上游 → 產生新 `skills-lock.json`
2. 對比新舊 lock：列出**新增 / 移除 / 改 hash** 的 skill
3. 若有 BREAKING（skill 移除 / frontmatter `name` 或 `description` 改動），在 PR 描述特別標註
4. 更新 `docs/INSTALL.md` 對應段落（若有版本依賴）
5. 開 PR

---

## 9. 不能改的禁區

以下動作會破壞既有運作，**改之前必須先跟 ark0720 確認**：

- ❌ 改 `skills/dollbao-*/SKILL.md` 的 frontmatter `name`（會讓既有觸發失效）
- ❌ 刪除 `manifest/common.json` 既有條目（會讓新人少裝東西）
- ❌ 改 `docs/INSTALL.md` 的「bootstrap prompt 對應步驟順序」（會讓新人 session 跑亂）
- ❌ 把 `PLAN.md` / `CONTEXT.md` 推進 repo（這兩份是 `Div7_新人CC安裝包/` 的工作文件，不屬於 repo；已在 `.gitignore`）
- ❌ 加 persona-* 進 `common.json`（role-specific，違反 Phase 1 範圍）
- ❌ 把規章原文 hard-code 進 skill（違反「L2 規章原文留在 Google Drive」原則）
- ❌ 加 macOS / Linux 安裝指令（公司只用 Windows，加了反而誤導）
- ❌ 把 BQ 查詢類 skill 加進 common（Phase 2 行銷業務單位部門包範圍）

---

## 10. 給 AI 的最後提醒

修改本 repo 時的標準作業：

1. **先讀 `PLAN.md`**（在 `Div7_新人CC安裝包/` 工作目錄）確認需求屬於 Phase 1 / Phase 2 / 不做
2. **再讀本文件對應 SOP 章節**
3. **動手前先列出將改動哪些檔案** 讓用戶確認
4. **每次改動開 PR**，commit 訊息中文簡述變更
5. **改完跑 `scripts/verify-install.ps1`**（M2 補完後）

若用戶要求做 §9 禁區內的事，必須先說明風險並請用戶明確確認再做。
