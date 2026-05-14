---
name: dollbao-calendar
description: ⏸️ M3 placeholder。逗寶曆查詢（公司會計年度、本月第幾週、重要檔期、節氣特賣等）。當使用者問到「現在第幾週」「會計年度何時結束」「下個檔期是什麼」「逗寶曆」「公司年度」等公司內部時間軸 / 檔期相關問題時觸發。
---

# ⏸️ M3 placeholder — dollbao-calendar

本 skill 為「BQ 查詢型」（見 [`../../docs/MAINTAINER.md` §2c](../../docs/MAINTAINER.md)）。M3 階段填完以下章節。

## 觸發時機（M3 完稿）

公司內部時間軸 / 檔期 / 會計週期相關問題：
- 今天是逗寶曆第幾週？
- 本會計年度的起訖？
- 未來 30 天有什麼檔期？
- 上次某檔期是什麼時候？

## 資料來源（M2.5 確認後填）

⏸️ **待 ark0720 在 M2.5 提供：**
- **GCP Project：** `___待填___`
- **Dataset：** `___待填___`
- **Table：** `___待填___`
- **IAM：** 給「全員 Google 群組（email 待補）」`bigquery.dataViewer` 角色（限定該 table）

## Schema（M2.5 填）

⏸️ 待 ark0720 用 `bq show --schema --format=prettyjson {project}:{dataset}.{table}` 取得後填入：

| 欄位 | 型別 | 說明 |
|---|---|---|
| `date` | DATE | 日期 |
| `fiscal_year` | INT | 會計年度 |
| `fiscal_week` | INT | 該會計年度第幾週 |
| `campaign` | STRING | 該日所屬檔期 |
| ... | ... | ... |

## 範例查詢（M3 填，待 schema 確認）

```sql
-- 1. 今天是第幾週 + 屬於哪個檔期
SELECT fiscal_week, campaign
FROM `___待填___`
WHERE date = CURRENT_DATE();

-- 2. 未來 30 天內的檔期
SELECT date, campaign
FROM `___待填___`
WHERE date BETWEEN CURRENT_DATE() AND DATE_ADD(CURRENT_DATE(), INTERVAL 30 DAY)
  AND campaign IS NOT NULL;

-- 3. 本會計年度起訖（M3 補）
```

跑法：`bq query --use_legacy_sql=false '...'`

## 怎麼回答

1. 依問題類型選範例查詢，必要時自行組裝 SQL
2. 跑 `bq query` 拿結果
3. 用人話回答，附上查詢的日期範圍與資料來源

## 權限備註

若使用者執行 `bq` 失敗：
- 先確認跑過 `gcloud auth login`
- 若仍失敗 → 提示用戶聯絡 ark0720 確認群組成員資格（IAM 授權）

## 人類可讀備援

若需要視覺版逗寶曆，連結原 Doc：
https://docs.google.com/document/d/1sb58UHZQkXD2YsrqwJUafX2bZD6UL6G-NRr_79uHW0E/edit

（本 skill **不直接讀此 Doc**，避免與 BQ source of truth 不同步）
