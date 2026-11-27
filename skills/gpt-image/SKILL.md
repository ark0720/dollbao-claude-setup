---
name: gpt-image
description: 用使用者的 ChatGPT 訂閱帳號（透過本機 Codex CLI，非 API key）呼叫 GPT Image 生圖 / 改圖。當使用者說「用 GPT 生圖」「叫 GPT 畫」「gpt image」「GPT Image 2」「用我的 ChatGPT 帳號生圖」「幫我生一張圖」「把這張產品圖做成情境圖」「用 GPT 改這張圖」，或其他 skill（dollbao-banner、dollbao-product-page 等）產出 prompt 後使用者要求直接出圖時觸發。不觸發：ad-gpt-ai MCP 批次廣告生圖（→ bulk-image-dollbao）、Canva 設計、只要 prompt 不要出圖。
---

# gpt-image — 用 ChatGPT 訂閱生圖

原理：本機 Codex 桌面版內含 `codex.exe`，已用 ChatGPT 帳號登入。`codex exec` 內建 image generation 工具，額度算在 ChatGPT / Codex 訂閱內，不走 API 計費。

## 呼叫方式（Bash tool）

```bash
bash ~/.claude/skills/gpt-image/gpt-image.sh -o "<輸出路徑.png>" -f "<prompt 檔>"
# 或短 prompt：
bash ~/.claude/skills/gpt-image/gpt-image.sh -o "out.png" -p "a watercolor bunny, 1:1"
# 帶參考圖（產品圖、風格圖，可多張）：
bash ~/.claude/skills/gpt-image/gpt-image.sh -o "out.png" -r "product.jpg" -r "style.png" -f prompt.txt
```

- Bash `timeout` 設 420000（單張約 1–3 分鐘）。
- 成功時 stdout 印出輸出路徑；之後用 Read 看圖確認品質再回報使用者。
- 長 prompt 或含中文 / 引號 → 先用 Write 把 prompt 寫到 scratchpad 的 `.txt`，再用 `-f`。
- 多張圖：每張各跑一次；可用多個 Bash 平行呼叫，但一次別超過 3 張，避免撞訂閱限速。
- 輸出預設放專案資料夾內（使用者才開得到），不要只放 scratchpad。

## Prompt 要點

- 在 prompt 裡寫明比例（1:1 / 4:5 / 9:16 / 16:9）與用途；畫面上的文字要逐字給，並註明語言（繁體中文）。
- 有產品參考圖時，註明「產品外觀、顏色、logo 必須與參考圖一致，不要重新設計」。
- 改圖：把原圖當 `-r`，prompt 寫清楚「只改 X，其餘保持不變」。

## 故障排除

| 症狀 | 處理 |
|---|---|
| exit 2 找不到 codex | Codex 桌面版被移除；請使用者重裝，或 `npm i -g @openai/codex` |
| exit 3 未登入 | 請使用者開 Codex 桌面版用 ChatGPT 帳號登入 |
| `model is not supported when using Codex with a ChatGPT account` | 模型下架。看 `~/.codex/models_cache.json` 的 slug，改用 `-m <新模型>`，並更新腳本裡的預設值 |
| exit 4 沒產出圖片 | 看 stderr 的 log 尾段：多半是額度用完（等重置）或內容政策拒絕（調整 prompt） |

## 限制

- 額度與 ChatGPT / Codex 訂閱共用，大量批次會吃掉 Codex 的使用額度。
- 不要讀取或輸出 `~/.codex/auth.json` 的內容。
