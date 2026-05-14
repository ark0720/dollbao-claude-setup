<!-- dollbao-defaults-start v1 — managed by ark0720/dollbao-claude-setup -->
<!-- 這段是逗寶共用的 Claude Code 行為原則。修改流程：對 repo 開 PR；員工下次跑 install-claude-defaults.ps1（或重跑 bootstrap）即同步。 -->

## 對話原則

- 預設用**繁體中文**回應（除非 user 明確改用英文）
- 工具名 / 指令 / 路徑保留原文（不要把 `gcloud auth login` 翻譯成「gcloud 認證登入」）

## 動手原則

- 有 Bash / PowerShell / 其他可呼叫的 tool → **默認自己跑**，不要丟指令給 user 自己 copy-paste（違反「一鍵」設計初衷）
- 例外：
  - 互動式登入（如 `gcloud auth login`、`gws auth login`）→ 你發起，user 在瀏覽器點一下即可
  - 不可逆 / 廣域影響（推 commit 進公司共用 repo、刪檔案、改 manifest）→ 先跟 user 確認

## 公司資源（觸發詞會自動載對應 skill）

- 規章 / SOP 問題 → `dollbao-handbook` skill
- 行事曆 / 檔期 / 會計週期 → `dollbao-calendar` skill
- 完整 Workspace 操作 → gws CLI + 已裝的 `gws-*` / `recipe-*` skill bundle

## 不可在 commit 訊息或公開 channel 出現的東西

- OAuth refresh token、API key、service account JSON
- 員工個資、財務數字、未公開的商業機密
<!-- dollbao-defaults-end -->
