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
7. **⚠️ 新增 skill 必須走 §4 嚴格三道閘：**
   - (a) **§4b 明確 trigger 句**才能走 §7（全員）/§8（部門）SOP；模糊一律先問
   - (b) **§4c double-check 位置**（哪些檔案 / 哪個 manifest / 路徑對不對）
   - (c) **§4d/§4e hard stop**（commit 前確認「影響範圍」）

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
- **digest 同步 SOP 見 §9**

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
- **gws bundle 更新 SOP 見 §10**

---

## 3. Manifest schema 摘要

完整規格見 [`../manifest/schema.md`](../manifest/schema.md)。要點：

- `manifest/common.json` — 全員必裝（Phase 1 範圍）
- `manifest/dept-{key}.json` — 部門包（Phase 2 預留，key 例：`marketing-sales`、`finance`、`hr`）
- `manifest/skills-lock.json` — gws bundle 鎖版資訊

任何 manifest 改動，須通過 `scripts/helpers/validate-manifest.ps1`（M2 補完）。

---

## 4. Skill 歸屬與三道閘流程

⚠️ **這是本 repo 最關鍵的章節。AI 接到任何「加 skill / 改 skill」請求時必須走完三道閘：**
- **閘 1（§4b）** 明確 trigger 句才走 §7/§8，模糊一律先問
- **閘 2（§4c）** 啟動 §7/§8 後動手前 double-check 位置
- **閘 3（§4d/§4e）** commit 前 hard stop 確認影響

### 4a. 四種歸屬

| 歸屬 | 寫到哪 | 誰會裝 | 進 manifest？ | 對應 SOP |
|---|---|---|---|---|
| **個人 / 臨時實驗** | `~/.claude/skills/X/`（user 本機，**不**進 repo）| 只有 user 自己 | ❌ 不進 | §5（不走 repo，AI 直接寫 user 本機） |
| **草稿**（先自用 / 想分享給其他知道 repo 的人，未來可能推全員） | repo `skills/X/`，**不**列進任何 manifest | 本 repo 看得到的人手動裝 | ❌ 不進 | §6 草稿 SOP |
| **全員 skill**（正式發給全公司新人） | repo `skills/X/` + 進 `manifest/common.json` | 所有新人 + 既有同事下次 pull | ✅ `common.json` | §7 全員 SOP |
| **部門 skill**（Phase 2） | repo `skills/X/` + 進 `manifest/dept-{key}.json` | 該部門新人 | ✅ `dept-*.json` | §8 部門 SOP |

### 4b. 閘 1 — 判斷流程（必須有明確 trigger 句才走 §7/§8）

⚠️ **明確意圖原則：** AI **只有在 user 用以下明確 trigger 句**時才能走 §7（全員）或 §8（部門）。**任何模糊、順口、或 trigger 詞只出現在 skill 名稱裡的情況，永遠不夠**，必須先問 (a)/(b)/(c)/(d)。

#### §7 全員 SOP 的明確 trigger 句

必須是**動詞短語、表達意圖**，例如：
- ✅ 「**推上全員**」「**加進全員必裝**」「**加進 common.json**」
- ✅ 「**全公司新人都要裝 X**」「**全員必裝 X**」「**X 給所有人**」
- ✅ 「把 X **推全員**」「X **進共用包**」

不夠明確的例子（必須先問）：
- ❌ 「加個叫 X 的 skill」「新增 X skill」 — 沒指明 scope
- ❌ 「做一個叫『測試用全員 skill』的 skill」 — "全員" 出現在 skill **名稱內**，不算意圖
- ❌ 「我想要一個 X skill」「幫我寫個 X」 — 偏個人語氣

明顯個人 / 草稿的例子（直接走 §5 或 §6）：
- ❌→§5「我自己想玩一個 X」「先做個 X 試試」「local 寫一個」
- ❌→§6「draft 一個 X」「先進 repo 不要進 manifest」

#### §8 部門 SOP 的明確 trigger 句

- ✅ 「**加進部門包**」「**進 dept-{key}**」「**{部門名}新人都要裝**」
- ✅ 「開 {部門} 安裝包」「{部門} 包加 X」
- ❌ 「{部門} 用的 skill」 — 沒明說 scope（user 可能只是想自己參考），要先問

#### 必問句（任何模糊狀況）

> 這個 skill 是要：
> - (a) 你個人本機用（不進 repo）
> - (b) 進 repo 但不擴散（草稿，未列入 manifest）
> - (c) 發給全公司新人（進 common.json）
> - (d) 給特定部門
>
> 請選 (a)/(b)/(c)/(d) 之一。

**⚠️ 不要預設選 (c)。** 模糊意圖優先解讀為 (a) 或 (b)，再讓 user 升級。

### 4c. 閘 2 — Double-check 更新位置（啟動 §7/§8 後必跑）

確認走 §7 或 §8 後，**在動任何檔案前**，AI 必須列出將動到的所有檔案位置，請 user 逐項 double-check。

#### §7 全員 skill 的位置 checklist 範例

> 確認走 §7 全員 SOP。我接下來會動以下檔案：
>
> 1. **新增** `skills/X/SKILL.md`（{型態：流程型/索引型/BQ 型} scaffold）
> 2. **編輯** `manifest/common.json` — 在 `skills[]` 陣列加：
>    ```json
>    { "id": "X", "path": "skills/X" }
>    ```
> 3. **編輯** `docs/INSTALL.md` §3 全員 skill 清單 — 加一列：
>    「X | {型態} | {觸發情境}」
> 4. **編輯** `README.md` Phase 1 範圍表 — 加一列（若 X 是 user-visible 的新 skill）
>
> 請逐項確認：
> - 路徑都對嗎？
> - 有沒有要加 / 拿掉 / 改名 / 改型態的？
> - 第 4 項要動嗎（user-visible）？

#### §8 部門 skill 的位置 checklist 範例

> 確認走 §8 部門 SOP（dept-{key}）。我接下來會動以下檔案：
>
> 1. **新增** `skills/X/SKILL.md`（{型態}）
> 2. **編輯** `manifest/dept-{key}.json` — `skills[]` 陣列加 `{ "id": "X", "path": "skills/X" }`
> 3. **編輯** `docs/INSTALL.md` 部門判定 hook 段
> 4.（若 X 帶新 MCP）**新增** `docs/INSTALL.md` MCP 設定章節
> 5. **編輯** `README.md` Phase 2 範圍表
>
> 請逐項確認位置是否正確。

#### 規則

- **等 user 明確確認位置後才動手。** 模糊回答（「應該對」「OK 吧」「都可以」）**視為不夠**，請 user 逐項打勾。
- 若 user 提出改動（如「不用動 README」「改名為 Y」「path 改成 skills/internal/X」），AI 必須**重新列一次** checklist 讓 user 再確認，**不可省略第二輪 confirm**。
- ⚠️ 這跟 §4d/§4e hard stop 不同：
  - **§4c** 確認 **WHERE**（檔案路徑、要動的位置）
  - **§4d/§4e** 確認 **WHETHER**（是否要承擔擴散影響）

### 4d. 閘 3a — 加進 common.json 前的 hard stop

§4c 位置確認後，**在執行「加進 `manifest/common.json` 並 commit」之前**，AI **必須**最後再問一次：

> 我要把 `X` 加進**全員必裝清單**（manifest/common.json），未來每個新人 bootstrap 都會自動裝到，現有同事下次 git pull 也會更新。確認嗎？

user 必須給**明確 yes**（「好」「確認」「OK」「sure」「yes」等）才動手。模糊回答（「嗯」「再看看」「先這樣」「應該可以」）視為「再等等」，AI 必須停下來再問清楚。

⚠️ **這條 hard stop 不可省略**，即使 user 一開始已說「加全員 skill」、§4c 也已 double-check 通過。從觸發到實際 commit 之間 user 可能改主意。

### 4e. 閘 3b — 加進 dept-*.json 前的 hard stop

加進任何 `dept-*.json` 前，同樣必須最後再確認：

> 我要把 `X` 加進 `dept-{key}.json`，該部門新人 bootstrap 都會裝到。確認嗎？

規則同 §4d。

---

## 5. SOP — 個人 skill（不走 repo）

> 觸發句範例：「幫我加一個叫 X 的 skill，只給我自己用」「我想 local 寫一個 X skill」「先做個 X 試試」

1. **跟 user 確認名稱、description、用途** — 不要憑空捏
2. **跟 user 確認型態**（§2 四種）
3. **直接寫到 `~/.claude/skills/X/SKILL.md`** —**不要**進本 repo
4. **不要動 manifest，不要動 INSTALL.md，不要動 README.md**
5. **不開 PR**（不在 repo 範圍內）
6. **告知 user：** 「skill 已建立在你本機 `~/.claude/skills/X/`。其他人不會拿到。要推全員或部門時跟我說『推上全員』或『加進 dept-{key}』，我再走對應 SOP。」

---

## 6. SOP — 草稿 skill（進 repo 但不擴散）

> 觸發句範例：「幫我加一個叫 X 的 skill，先進 repo 不要列進 manifest」「draft 一個 X skill」

1. **判斷型態** — 依 §2
2. **跟 user 確認名稱、description、資料源**
3. **跑 §4c double-check 位置**（僅 `skills/X/SKILL.md` 一個，不動 manifest / INSTALL.md / README.md）
4. **scaffold `skills/X/SKILL.md`** — 按型態套對應模板
5. **本地測試** — 把 skill 複製到 `~/.claude/skills/X/`，重啟 Claude Code，問觸發句驗證能進
6. **開 PR**，標題 prefix `[draft]`，描述註明「未列入 manifest，新人不會自動裝」
7. **告知 user：** 「草稿 skill 已進 repo 但未列入 manifest。新人不會自動裝。未來想推全員時跟我說『把 X 推上全員』，我會走 §7。」

---

## 7. SOP — 新增全員 skill

> ⚠️ **進入條件：** §4b 明確 trigger 句 OR user 在必問 (a)/(b)/(c)/(d) 中明確選 (c)。

> 觸發句範例：「推上全員」「加進 common.json」「全公司新人都要裝 X」「把草稿 X 推上全員」

1. **判斷型態** — 依 §2
2. **跟 user 確認名稱、description、資料源** — 不要憑空捏，特別是 description（影響 AI 觸發）
3. **跑 §4c double-check 位置** ⚠️ — 列 4 個檔案 checklist 讓 user 逐項確認
4. **scaffold** `skills/X/SKILL.md` — 按型態套對應 template（可參考 `dollbao-handbook` 或 `dollbao-calendar`）；若是從草稿升級則跳過此步
5. **跑 §4d hard stop 確認** ⚠️
6. **加進 `manifest/common.json`** 的 `skills` 陣列
7. **更新 `docs/INSTALL.md`** 的「全員 skill」清單區段（§3）
8. **更新 `README.md`** 的「Phase 1 範圍」表（§4c 已確認要動才動）
9. **本地測試** — 把 skill 複製到 `~/.claude/skills/X/`，重啟 Claude Code，問觸發句驗證能進
10. **開 PR** — PR 描述附觸發句 + 測試證據

⚠️ persona-* skill **不要** 加進 `common.json`，那是 role-specific，留給 Phase 2 部門包或用戶自選。

---

## 8. SOP — Phase 2 新增部門包

> ⚠️ **進入條件：** §4b 明確 trigger 句 OR user 在必問 (a)/(b)/(c)/(d) 中明確選 (d)。

> 觸發句範例：「加進部門包」「開行銷業務部安裝包，要包含 X、Y、Z」「進 dept-marketing-sales」

部門 key 命名規則：`{dept-name-with-dashes}`（小寫、英文、用 `-` 連字）。例：`marketing-sales`、`finance`、`hr`。

1. **確認部門 Google 群組 email**（用來控管 IAM）
2. **跑 §4c double-check 位置** ⚠️
3. **新增 `manifest/dept-{key}.json`** — 按 [`schema.md §2`](../manifest/schema.md) 寫
4. **跑 §4e hard stop 確認** ⚠️
5. **更新 `docs/INSTALL.md`** 啟用「部門判定 hook」段落：
   - 在 bootstrap 對話流程的「裝 common manifest 後」插入判定點
   - AI 問用戶：「你屬於哪個部門？」→ 對應到 `dept-*.json`
6. **若部門包含新 MCP server**（如 Windsor、GA4）：
   - 在 `docs/INSTALL.md` 補 MCP server 安裝 + auth 流程
7. **若部門包含新 BQ skill**：
   - 確認對應 IAM 設定文件已寫好（給 ark0720 在 GCP 操作的 checklist）
8. **更新 `README.md` 的「Phase 2 範圍」表**
9. **開 PR**

---

## 9. SOP — 規章 digest 同步

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

## 10. SOP — gws bundle 更新

> 觸發句：「上游 googleworkspace/cli 有更新，幫我同步」

1. 用 mirror 工具（M2 確認）重新拉上游 → 產生新 `skills-lock.json`
2. 對比新舊 lock：列出**新增 / 移除 / 改 hash** 的 skill
3. 若有 BREAKING（skill 移除 / frontmatter `name` 或 `description` 改動），在 PR 描述特別標註
4. 更新 `docs/INSTALL.md` 對應段落（若有版本依賴）
5. 開 PR

---

## 11. SOP — 逗寶曆 BQ schema 變動

> 觸發句：「逗寶曆 BQ table 加了新欄位 X」

1. 用 `bq show --schema --format=prettyjson {project}:{dataset}.{table}` 取最新 schema
2. 更新 `skills/dollbao-calendar/SKILL.md` 的 schema 區段
3. 若新欄位帶來新查詢情境，加 1-2 個範例 SQL
4. 本地測試（觸發 skill 問新欄位相關問題）
5. 開 PR

---

## 12. 不能改的禁區

以下動作會破壞既有運作，**改之前必須先跟 ark0720 確認**：

- ❌ 改 `skills/dollbao-*/SKILL.md` 的 frontmatter `name`（會讓既有觸發失效）
- ❌ 刪除 `manifest/common.json` 既有條目（會讓新人少裝東西）
- ❌ 改 `docs/INSTALL.md` 的「bootstrap prompt 對應步驟順序」（會讓新人 session 跑亂）
- ❌ 把 `PLAN.md` / `CONTEXT.md` 推進 repo（這兩份是 `Div7_新人CC安裝包/` 的工作文件，不屬於 repo；已在 `.gitignore`）
- ❌ 加 persona-* 進 `common.json`（role-specific，違反 Phase 1 範圍）
- ❌ 把規章原文 hard-code 進 skill（違反「L2 規章原文留在 Google Drive」原則）
- ❌ 加 macOS / Linux 安裝指令（公司只用 Windows，加了反而誤導）
- ❌ 把 BQ 查詢類 skill 加進 common（Phase 2 行銷業務單位部門包範圍）
- ❌ **省略 §4 三道閘任何一道**：
  - 沒有明確 trigger 句就走 §7/§8
  - 跳過 §4c double-check 位置
  - 跳過 §4d/§4e hard stop

---

## 13. 給 AI 的最後提醒

修改本 repo 時的標準作業：

1. **先讀 `PLAN.md`**（在 `Div7_新人CC安裝包/` 工作目錄）確認需求屬於 Phase 1 / Phase 2 / 不做
2. **新增 skill 時走 §4 三道閘：**
   - 閘 1（§4b）：模糊 trigger 句一律先問 (a)/(b)/(c)/(d)，**不要預設全員**
   - 閘 2（§4c）：走 §7/§8 後動手前必列檔案 checklist 讓 user 確認位置
   - 閘 3（§4d/§4e）：commit 進 manifest 前最後一次確認影響範圍
3. **再讀對應 SOP 章節**
4. **動手前先列出將改動哪些檔案** 讓用戶確認（即使非 §7/§8 也建議跑）
5. **每次改動開 PR**，commit 訊息中文簡述變更
6. **改完跑 `scripts/verify-install.ps1`**（M2 補完後）

若用戶要求做 §12 禁區內的事，必須先說明風險並請用戶明確確認再做。
