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

## Bootstrap prompt（暫定，M2 確認後鎖定）

```
請幫我跑逗寶新人安裝流程。請依以下步驟，每一步做完都跟我確認再做下一步：

1. 確認/安裝以下工具（用 winget，若已存在就 skip）：
   Node.js LTS、Git、GitHub CLI、Google Cloud SDK
2. 引導我跑 `gh auth login`
3. 用 `gh repo clone ark0720/dollbao-claude-setup ~/.claude/dollbao-setup`
4. 把 ~/.claude/dollbao-setup/skills/ 底下所有 skill 複製到 ~/.claude/skills/
5. 把 ~/.claude/dollbao-setup/manifest/skills-lock.json 用來安裝完整 gws skill bundle
6. 引導我跑 `gws auth login`
7. 最後給我 5 題驗證題，確認所有工具都裝好了

完整安裝邏輯請參考 repo 內的 docs/INSTALL.md
```
