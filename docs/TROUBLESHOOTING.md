# TROUBLESHOOTING.md

> 給 **AI** 讀，遇到錯誤時參考。M2-M4 過程持續累積。

---

## 索引（M2-M4 補）

⏸️ 此檔目前為空白。M2 安裝環境後遇到的第一個錯誤就填進來。

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
