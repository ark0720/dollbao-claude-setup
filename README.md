# dollbao-claude-setup

逗寶國際新進職員 Claude Code 一鍵安裝包。新人裝完 Claude Code Desktop 並登入後，貼一段 bootstrap prompt，由 Claude Code 內的 AI 引導完成所有後續安裝（Node/Git/gh/gcloud + gws skill bundle + 公司自製 skill）。

> **設計理念：** 最大化利用 Claude Code 本身的 AI 能力做安裝引導，而非寫死 PowerShell 腳本。對非工程同事更友善、Day 1 即體驗 AI 工具力、維護門檻低。

---

## Phase 1 範圍（本 repo 涵蓋）

| 類別 | 內容 |
|---|---|
| 基礎工具 | Node.js LTS、Git、GitHub CLI、Google Cloud SDK（含 gcloud + bq CLI）|
| Skill bundle | gws-* 完整 bundle（~93 個，排除 persona-*，由 [`googleworkspace/cli`](https://github.com/googleworkspace/cli) mirror）|
| 自製 skill | `dollbao-handbook`（規章查詢，兩層索引型）、`dollbao-calendar`（逗寶曆 BQ 查詢型）|

⏸️ Phase 2 部門包（行銷業務單位 / 會計部）的擴充點已在骨架預留，未來新增**不需重構** repo 結構。

---

## Repo 結構

```
dollbao-claude-setup/
├── README.md                  # 本檔（給 ark0720 自己看）
├── docs/
│   ├── INSTALL.md             # 給 AI 讀：完整安裝劇本
│   ├── MAINTAINER.md          # 給 AI 讀：「如何修改本 repo」憲法
│   ├── ONBOARDING.md          # 給人讀：新人完整流程（同步 Notion / 投影片）
│   └── TROUBLESHOOTING.md     # 給 AI 讀：常見錯誤與解法
├── manifest/
│   ├── common.json            # 全員必裝清單
│   ├── skills-lock.json       # gws bundle 鎖版（commit + content hash）
│   └── schema.md              # manifest 結構規格
├── skills/
│   ├── dollbao-handbook/      # 兩層索引型
│   └── dollbao-calendar/      # BQ 查詢型
├── scripts/
│   ├── verify-install.ps1     # 安裝完整性檢查
│   └── helpers/               # 輔助工具
└── .github/workflows/
    └── verify.yml             # CI：跑 verify + schema 檢查
```

---

## 怎麼修改這個 repo

**不要直接手改檔案，請對 Claude 說話。**

| 想做什麼 | 對 Claude 說 |
|---|---|
| 新增全員 skill | 「幫我加一個叫『X』的全員 skill」 |
| 新增部門包（Phase 2） | 「開行銷業務部的安裝包，要包含 Windsor MCP、X、Y」 |
| 規章 digest 過期 | 「規章 Doc 有更新，幫我重新生成 dollbao-handbook 的 digest」 |
| 逗寶曆 BQ schema 變動 | 「逗寶曆 table 加了 holiday_type 欄位，幫我更新 skill」 |
| gws bundle 更新 | 「上游 googleworkspace/cli 有更新，幫我同步」 |

AI 會讀 [`docs/MAINTAINER.md`](docs/MAINTAINER.md) 後照流程做完並開 PR。

---

## 給新人

請見 [`docs/ONBOARDING.md`](docs/ONBOARDING.md) 或公司 Notion landing page。

---

## License / Scope

逗寶國際內部使用為主，repo 為 **public**（方便新人 Claude Code AI 無 auth 就能 clone）。

**為何 public 不算機密外洩：**
- repo 只含「安裝劇本 + skill 範本 + 指向公司資源的 ID 字串」
- 真正的資料（規章 spreadsheet、逗寶曆 BQ table、規章 Docs）由 **Google IAM 保護**：沒授權的人就算知道 ID 也讀不到內容
- 不存任何 API key / token / 密碼

**不要 commit 進來的：**
- 任何 OAuth refresh token、API key、Google service account JSON
- 真實員工個資、財務數字、商業機密
- `PLAN.md` / `CONTEXT.md`（已在 `.gitignore`，是 ark0720 工作文件）

如果未來真的需要藏東西，再拆出一個 private companion repo。
