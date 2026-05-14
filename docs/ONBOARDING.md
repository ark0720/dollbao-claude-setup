# ONBOARDING.md — 逗寶新人 Claude Code 安裝完整流程

> 給人讀（新進職員）。內容會同步到公司 Notion landing page。
>
> ⏸️ **M4 階段填完**。本檔目前為結構大綱。

---

## 預計章節（M4 補完）

1. **歡迎與整體流程**（5 行內說明你要做什麼、需要多久、會裝到什麼）
2. **Phase 0：裝 Claude Code Desktop**（連結投影片）
3. **Phase 1：貼 bootstrap prompt**（提供完整 prompt 文字 + 截圖）
4. **預計時間：約 30 分鐘**
5. **裝完後的 5 題驗證題**（讓你立刻感受 AI 的好用程度）
6. **卡住時怎麼辦**（連結 [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)）
7. **聯絡誰**（ark0720 或 IT）

---

## Bootstrap prompt（M2.8 — Secret Manager + Claude defaults）

```
請幫我跑逗寶新人安裝流程。我沒有 GitHub 帳號也不需要，setup repo 已公開。
請依以下步驟，每一步做完都跟我確認再做下一步：

1. 確認/安裝以下工具（用 winget，若已存在就 skip）：
   Node.js LTS、Git、GitHub CLI（可選）、Google Cloud SDK (含 gcloud + bq CLI)
2. 引導我跑 `gcloud auth login`（請務必用我的公司 dollbao.com.tw 帳號，
   不是個人 gmail，否則後續無法從 GCP 拉取共用設定）
3. 用 git clone 把 setup repo 拉到我家目錄：
   git clone https://github.com/ark0720/dollbao-claude-setup.git ~/.claude/dollbao-setup
4. 用 npm 裝 gws CLI：npm install -g @googleworkspace/cli
5. 從 Secret Manager 拉 gws OAuth credentials 寫到 ~/.config/gws/client_secret.json：
     gcloud secrets versions access latest --secret=gws-oauth-client --project=dollbao-gws-cli
   （若拿到 PERMISSION_DENIED → 我是不是登錯帳號；若 NOT_FOUND → 請聯絡 ark0720）
6. 引導我跑 `gws auth login`（再次確認用 dollbao.com.tw 公司帳號）
7. 跑 ~/.claude/dollbao-setup/scripts/helpers/install-gws-bundle.ps1
   裝完整 gws skill bundle（約 85 個 skill，排除 persona-*）
8. 跑 ~/.claude/dollbao-setup/scripts/helpers/install-dollbao-skills.ps1
   裝逗寶自製 skill（dollbao-handbook、dollbao-calendar）
9. 跑 ~/.claude/dollbao-setup/scripts/helpers/install-claude-defaults.ps1
   裝逗寶共用 Claude defaults（~/.claude/CLAUDE.md，所有 Claude Code session
   自動載入：繁中預設、有 tool 就直接跑、引用對應 skill、不 leak secret）
10. 跑 ~/.claude/dollbao-setup/scripts/verify-install.ps1 自動檢查
11. 最後給我 5 題驗證題，確認所有工具都裝好了

完整安裝邏輯請參考 repo 內的 docs/INSTALL.md（在 ~/.claude/dollbao-setup/docs/INSTALL.md）
```
