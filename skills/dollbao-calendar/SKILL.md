---
name: dollbao-calendar
description: 逗寶國際「報告歷」（RY/RQ/RM/RW）查詢與語義解釋。當使用者問到「今天是 RY 幾年第幾週」「本報告月何時結束」「RY26W41 是哪一天」「報告週 vs 西元週」「RY27 是不是 53 週年」「YoY 怎麼比較」「跨日訂單算哪天」「逗寶曆」「報告歷」「報告年/季/月/週」等公司內部時間軸相關問題時觸發。Source of truth 是 BigQuery table `data-for-all-496615.shared_all_views.reportYearMonthWeek`，語義規則同源於規章 A0031「報告週、報告月與報告年」(Doc ID `1sb58UHZQkXD2YsrqwJUafX2bZD6UL6G-NRr_79uHW0E`，v4 2026-05 修訂)。
---

# dollbao-calendar

本 skill 為「BQ 查詢型」（見 [`../../docs/MAINTAINER.md` §2c](../../docs/MAINTAINER.md)）。

- **資料 source of truth：** BigQuery table `data-for-all-496615.shared_all_views.reportYearMonthWeek`
- **語義規則 source of truth：** 規章 A0031「報告週、報告月與報告年」(v4 2026-05)，本 skill 已嵌入摘要。完整原文見最後一節連結。

---

## 1. 核心概念（必讀）

逗寶國際內部時間軸採「**報告歷**」（Report Calendar），與西元日曆並行。

### 1.1 命名與編碼

| 顆粒度 | 編碼 | 範例 | 說明 |
|---|---|---|---|
| 報告年 | **RY** + 西元後兩碼 | `RY26` | 西元後兩碼取「**結束於哪一年**」。RY26 = 2025-07 ~ 2026-06，結束於 2026 年。 |
| 報告季 | **RY{YY}RQ{1-4}** | `RY26RQ3` | 一律寫 `RQ`，**不要單獨用 Q1**（會被誤解成西元 Q1）。 |
| 報告月 | **RY{YY}M{MM}** | `RY26M03` | M01=1月、M07=7月（與傳統月份一致）。**M01 不是報告年第一月**（M07 才是）。 |
| 報告週 | **RY{YY}W{WW}** | `RY26W41` | W 編號在報告年內遞增（1~52 或 53）。W1 = M07 第 1 週。 |

### 1.2 報告年（RY）

- **起點：** 每年 7 月初（具體日期跟「週三起算」對齊）
- **長度：** 364 天（52 週）為標準；少數年份 371 天（53 週），如 **RY27 = 53 週年**（多出的週加在 M06 末尾）
- **記憶口訣：** RY+結束年的後兩碼。RY26 結束於 2026 年。
- **已驗證：**
  - RY25: 2024-07-03 ~ 2025-07-01（364 天）
  - RY26: 2025-07-02 ~ 2026-06-30（364 天）
  - RY27: 2026-07-01 ~ 2027-07-06（371 天 / 53 週）

### 1.3 報告週（RW）— 週三起算

- **每週**：**週三 (Wed) 起，隔週週二 (Tue) 止**（非 ISO 週一起算）
- 影響：日曆上某個日期屬於哪個 RW，要看「該日的週三起始日」落在哪。
- 舉例：2026-07-01 是週三 → RY27W1 從 2026-07-01 開始，到 2026-07-07 (Tue) 為止。

### 1.4 報告月（RM）— 4-4-5 結構

逗寶採國際零售業常見的 **4-4-5 結構**：每季前兩個月為 4 週小月（28 天），第三個月為 5 週大月（35 天）。

| 報告月 | 週數 | 天數 | 屬於 |
|---|---|---|---|
| M07 / M08 | 4 週 | 28 天 | RQ1 小月 |
| **M09** | **5 週** | **35 天** | **RQ1 大月** |
| M10 / M11 | 4 週 | 28 天 | RQ2 小月 |
| **M12** | **5 週** | **35 天** | **RQ2 大月** |
| M01 / M02 | 4 週 | 28 天 | RQ3 小月 |
| **M03** | **5 週** | **35 天** | **RQ3 大月** |
| M04 / M05 | 4 週 | 28 天 | RQ4 小月 |
| **M06** | **5 週** | **35 天** | **RQ4 大月**（53 週年再多 1 週） |

每季 = 13 週 = 91 天；每年 = 52 週 = 364 天（53 週年 = 371 天）。

**跨日曆月份歸屬：** 以行事曆公告為準。一旦該週的「週三起始日」落入某報告月，整週都歸該報告月。例：2022/8/2 (Tue) 仍歸 RY23M07（因該週的週三起始日 2022/7/27 屬於 M07）。

### 1.5 西元日期 vs 報告歷 — 使用場景

| 用報告歷 (RY/RQ/RM/RW) | 用西元日期 |
|---|---|
| 內部 KPI 管理（營收、業績） | 法規申報、政府公文（會計、稅務、年報） |
| 部門目標達成率追蹤 | 職員勞工權益、薪資結算、人事行政 |
| 統計曲線分析 | 對外溝通（客戶、經銷商、供應商） |
| 戰術 / 戰略計畫 | |
| 諮詢議會、職員會議報表 | |

### 1.6 YoY 比較規則

**跨年度比較一律用相同 RY 顆粒度**，**不可**用 calendar date 比較：

- 週級 YoY：`RY26W41 vs RY25W41`
- 月級 YoY：`RY26M03 vs RY25M03`
- 季級 YoY：`RY26RQ3 vs RY25RQ3`
- 累計 YoY (YTD)：`RY26 累計到 W41 vs RY25 累計到 W41`（累計天數一致 = 41 × 7 = 287 天）

這是 4-4-5 設計能保證「累計天數一致」的核心優勢。

### 1.7 跨日訂單認列

- 所有交易認列以 **UTC+8（台北時間）**為準
- 線上跨日訂單（如 23:50 下單、隔日 00:10 結帳 / 出貨）以「**出貨時間**」歸屬報告週/月
- 例外：政府報稅相關交易依政府核發日期規定

### 1.8 促銷檔期

- 檔期屬「**專案分析顆粒度**」，獨立於 RW/RM
- 檔期績效仍累計到該檔期實際發生的 RW/RM。跨報告週的檔期，按實際日歸屬到對應 RW/RM
- **檔期排程不在本 BQ table。** 如使用者問「下個檔期」「雙11」「週年慶」等，提示讀人類可讀備援 Doc 或行銷部資源。

---

## 2. 資料來源

| 項目 | 值 |
|---|---|
| GCP Project (資料) | `data-for-all-496615`（全員可讀的「公開 view」專案） |
| Dataset | `shared_all_views` |
| Table / View | `reportYearMonthWeek`（view，底層為 `dollbao-data-center.Ref.reportYearMonthWeek`，本身對全員不開） |
| Billing project (跑 query) | `dollbao-gws-cli` |
| 涵蓋範圍 | RY19 ~ RY29（6573 列，~18 年） |
| 授權 | view-level `roles/bigquery.dataViewer` on `data-for-all-496615.shared_all_views.reportYearMonthWeek` → `domain:dollbao.com.tw`；project-level `roles/bigquery.jobUser` on `dollbao-gws-cli` → `domain:dollbao.com.tw`。**底層 `dollbao-data-center.Ref` dataset 不對全員開**，請一律走 `data-for-all-496615.shared_all_views` 這個 view。 |
| 維護權責 | 書面溝通科（同步董事會核可的行事曆） |

### Schema（實際 5 欄）

| 欄位 | 型別 | 意義 | 命名對應 |
|---|---|---|---|
| `date` | DATE | 日曆日期 | calendar date |
| `reportYear` | INTEGER | 2 位數報告年 (19~29) | **RY** |
| `reportMonth` | INTEGER | 日曆月 (1-12) | M{MM}（與西元月一致） |
| `reportMonthSort` | INTEGER | 報告年內月份順序 (1-12，M07=1, M08=2 … M06=12) | — |
| `reportWeek` | INTEGER | 報告年內第幾週 (1-52 或 1-53) | **W** |

⚠️ **與規章 Doc 的 schema 差異：**
- Doc 提到的欄位 `calendarDate` 實際為 `date`
- Doc 提到的欄位 `reportQuarter` **不存在** — 需在 SQL 用 derived 欄位計算
- Doc SQL JOIN 範例的欄名待修正（可用此 skill 為準）

### 報告季 derived 計算

```sql
-- 從 reportMonthSort 推報告季：
CASE
  WHEN reportMonthSort BETWEEN 1 AND 3 THEN 1
  WHEN reportMonthSort BETWEEN 4 AND 6 THEN 2
  WHEN reportMonthSort BETWEEN 7 AND 9 THEN 3
  WHEN reportMonthSort BETWEEN 10 AND 12 THEN 4
END AS reportQuarter
```

---

## 3. 範例查詢

跑法（PowerShell + here-string，避免 escape 問題）：

```powershell
$sql = @'
<SQL>
'@
bq query --use_legacy_sql=false --format=prettyjson $sql
```

### 3.1 今天的 RY 對照

```sql
SELECT
  date,
  CONCAT('RY', LPAD(CAST(reportYear AS STRING), 2, '0')) AS RY,
  CONCAT('M', LPAD(CAST(reportMonth AS STRING), 2, '0')) AS RM,
  CONCAT('W', LPAD(CAST(reportWeek AS STRING), 2, '0')) AS RW,
  CASE
    WHEN reportMonthSort BETWEEN 1 AND 3 THEN 'RQ1'
    WHEN reportMonthSort BETWEEN 4 AND 6 THEN 'RQ2'
    WHEN reportMonthSort BETWEEN 7 AND 9 THEN 'RQ3'
    ELSE 'RQ4'
  END AS RQ
FROM `data-for-all-496615.shared_all_views.reportYearMonthWeek`
WHERE date = CURRENT_DATE('Asia/Taipei');
```

⚠️ **時區提醒：** BQ `CURRENT_DATE()` 預設 UTC，台灣早上會比實際日早一天。**一律帶 `'Asia/Taipei'` 參數**。

### 3.2 本 RY 起訖與長度

```sql
WITH this_ry AS (
  SELECT reportYear FROM `data-for-all-496615.shared_all_views.reportYearMonthWeek`
  WHERE date = CURRENT_DATE('Asia/Taipei')
)
SELECT
  CONCAT('RY', LPAD(CAST(reportYear AS STRING), 2, '0')) AS RY,
  MIN(date) AS ry_start,
  MAX(date) AS ry_end,
  COUNT(*) AS days,
  MAX(reportWeek) AS total_weeks,
  IF(MAX(reportWeek) = 53, '53週年', '52週年') AS year_type
FROM `data-for-all-496615.shared_all_views.reportYearMonthWeek`
WHERE reportYear = (SELECT reportYear FROM this_ry)
GROUP BY reportYear;
```

### 3.3 RY{YY}W{WW} → 日期 (反查週起訖)

```sql
-- 替換 26 與 41 為目標 RY / W
SELECT
  MIN(date) AS week_start_wed,
  MAX(date) AS week_end_tue
FROM `data-for-all-496615.shared_all_views.reportYearMonthWeek`
WHERE reportYear = 26 AND reportWeek = 41;
```

### 3.4 RY{YY}M{MM} → 日期 (反查月起訖)

```sql
SELECT
  MIN(date) AS month_start,
  MAX(date) AS month_end,
  COUNT(*) AS days,
  COUNT(DISTINCT reportWeek) AS weeks,
  IF(COUNT(*) = 35, '大月 (5週)', '小月 (4週)') AS month_type
FROM `data-for-all-496615.shared_all_views.reportYearMonthWeek`
WHERE reportYear = 26 AND reportMonth = 3;
```

### 3.5 YoY 比較：RY26W41 vs RY25W41 (同週次)

```sql
-- 取出兩個對照週的日期區間，業務資料表用此區間 JOIN
SELECT
  reportYear,
  reportWeek,
  MIN(date) AS week_start,
  MAX(date) AS week_end
FROM `data-for-all-496615.shared_all_views.reportYearMonthWeek`
WHERE (reportYear = 26 AND reportWeek = 41)
   OR (reportYear = 25 AND reportWeek = 41)
GROUP BY reportYear, reportWeek
ORDER BY reportYear;
```

### 3.6 JOIN 模板（給跨表分析用）

```sql
SELECT
  s.*,
  r.reportYear,
  r.reportMonth,
  r.reportWeek
FROM `<your_business_table>` s
LEFT JOIN `data-for-all-496615.shared_all_views.reportYearMonthWeek` r
  ON DATE(s.<your_date_column>) = r.date;
```

---

## 4. 怎麼回答

1. **判斷顆粒度** — 使用者問的是 RY / RQ / RM / RW 哪一層？
2. **挑或組裝範例 SQL** — 用 §3 的模板
3. **跑 `bq query`** — 用 here-string 包 SQL
4. **回答時明確標示：**
   - 用「**RY26**」不要寫「FY26」或「2026 年度」
   - 用「**RY26M03**」不要寫「2026 年 3 月（會計月）」
   - 提到日期區間時加註「（報告週 = 週三起 ~ 週二）」
   - YoY 比較時明說「用同 RY 週次/月份比，非 calendar date」
5. **若問題涉及檔期 / 雙11 / 週年慶 / 節氣特賣** — 提示資料不在本 table，建議讀備援 Doc 或聯絡行銷部
6. **若問題涉及法規/薪資/對外** — 提示這類場景一律用西元日期，不要用報告歷

---

## 5. FAQ（規章 A0031 v4 摘錄）

**Q1：為什麼 RY26W41 不是 calendar week 41？**
A：報告週從**週三**起算（不是 ISO 週一），且報告年從每年 **7 月**開始（不是 1 月）。RY26W41 對應 calendar 約落在 2026 年 4 月初，與 ISO week 41（10 月）完全不同。

**Q2：跨日曆月份該歸哪個 M？**
A：以行事曆公告為準。一旦該週的「**週三起始日**」落入某報告月，整週都歸該報告月。例如 2022/8/2 (Tue) 仍歸在 RY23M07（因該週的週三起始日 2022/7/27 屬於 7 月）。

**Q3：M01 是 1 月還是 7 月？**
A：M01 是 **1 月**，不是 7 月。報告月編號採傳統月份（M03=3月、M07=7月、M11=11月），保留與西元月份相同的叫法，唯獨天數與起訖日不同。

**Q4：53 週年的多出那一週怎麼處理？**
A：經董事會核可之行事曆，**RY27 為 53 週年**，多出來的那一週統一加到當年度最後一週（即 M06 末尾）。其他 RY 年份遵循 4-4-5 結構，共 364 天 / 52 週。

**Q5：跨日訂單算哪一天？**
A：以「**出貨時間**」歸屬到對應的 RW/RM（不是下單時間，也不是結帳完成時間）。

**Q6：跨報告週的促銷檔期績效怎麼算？**
A：檔期屬於專案分析顆粒度（獨立看），但檔期績效仍累計到該檔期實際發生的 RW/RM。例如某檔期跨 RY26W40~W42，則該檔期業績會分別累計到 W40、W41、W42。

---

## 6. 權限備註

如果 `bq query` 失敗：

- **`Access Denied: Table` / `User does not have ... permission`**：
  - 確認跑過 `gcloud auth login`（用 @dollbao.com.tw 帳號）
  - 確認當前 active account：`gcloud auth list`
  - 若帳號正確但仍 deny：聯絡 ark0720 確認 Workspace 帳號 / IAM 狀態

- **`User does not have bigquery.jobs.create permission in project ...`**：
  - 設 default billing project：`gcloud config set project dollbao-gws-cli`
  - 或在 query 帶 `--project_id=dollbao-gws-cli`

---

## 7. 人類可讀備援

- **規章 A0031「報告週、報告月與報告年」(v4)** — 完整語義原文、編碼規則、版本紀錄、董事長批示：
  https://docs.google.com/document/d/1sb58UHZQkXD2YsrqwJUafX2bZD6UL6G-NRr_79uHW0E/edit
- **行事曆 PDF / Excel 對照表（含 VLOOKUP）** — 由書面溝通科維護，位於全公司共用雲端硬碟。檔名格式：「逗寶國際 報告週與月行事曆_RY{YY}~RY{YY}.xlsx」
- **RY23~RY27 PDF：** https://drive.google.com/file/d/19gqLDwOHhRbfiWEFhMKo26gV7uCfUzQ7/view

本 skill **以 BQ 為資料 source of truth、以規章 Doc 為語義 source of truth**。若 BQ 結果與規章解讀衝突，**以規章為準**（資料可能滯後 schema 更新）。
