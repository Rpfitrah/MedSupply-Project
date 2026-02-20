Domain: Distributor/Supply Chain | Audience: C-Level | Trend: DA Hiring 2026

F — FIND 3 Kolom Utama
#| Kolom | Tabel | Alasan |
1| Inden_Flag + Inden_Est_Days | Transaction_Items (post-FE) | Inti masalah: seberapa sering & lama inden terjadi
2| Invoice_Status + Grand_Total | Transactions_Main | Mengukur revenue yang tertahan akibat inden belum selesai
3| Stock_Available + Inden_Lead_Time_Days | Master_Products | Root cause: produk apa yang struktural rawan inden

R — READ Pattern Data
Dari struktur kolom, terbaca 3 pola utama:
Pola 1 — Indent Cascade: Produk dengan Stock_Available rendah → Inden_Flag = Indent → Inden_Est_Days panjang → Delivery_Date molor → Invoice_Status tertahan. Ini adalah rantai masalah linear yang bisa diputus di titik stok.

Pola 2 — Estimation Gap: Inden_Est_Days (estimasi) vs DATEDIFF(Delivery_Date, Order_Date) (aktual) kemungkinan tidak sama → vendor/tim operasional underestimate durasi inden → ekspektasi customer tidak terkelola.

Pola 3 — Revenue Concentration: Dari Total_Transactions di tabel Customer + Item_Total, kemungkinan besar 20% produk menyumbang 80% revenue at risk — pola Pareto klasik di distribusi.

A — 3 KPI Bisnis Paling Relevan
KPI 1 — Indent Rate (%)
Persentase order lines yang berstatus indent dari total lines. Ini KPI operasional paling langsung untuk mengukur ketersediaan stok.

Formula: Indent Lines / Total Lines × 100

KPI 2 — Inden Duration Accuracy (hari)
Selisih antara estimasi lama inden (Inden_Est_Days) vs aktual (Delivery - Order). Kalau error-nya konsisten positif, artinya vendor selalu telat dari janji.

Formula: AVG(Actual_LeadTime - Inden_Est_Days) untuk item Indent

KPI 3 — Revenue at Risk (Rp)
Total Item_Total dari order yang masih inden DAN invoice belum lunas. Ini angka yang paling resonan di C-level karena langsung bicara uang.

Formula: SUM(Item_Total) WHERE Inden_Flag = 'Indent' AND Invoice_Status != 'Lunas'


M — MATCH Business Problem Template
[✅] Waste    → Inden yang melebihi estimasi = waktu & kapasitas terbuang
[✅] Revenue  → Invoice tertahan = cash flow terganggu
[ ] Growth    → (secondary, bukan fokus utama)
Primary Match: WASTE + REVENUE (dual problem)

Inden berkepanjangan adalah waste operasional yang secara langsung menciptakan revenue bottleneck. Solusinya satu: perbaiki akurasi estimasi inden & prioritas restock berbasis nilai revenue.


E — EXECUTE

1. Business Question

"Produk mana yang paling sering dan paling lama mengalami inden, seberapa jauh estimasi durasi inden meleset dari aktual, dan berapa total revenue yang tertahan — sehingga manajemen bisa memprioritaskan restock dan kalibrasi vendor secara berbasis data?"


2. KPI Target
KPIKondisi Awal (cari dari query)Target BisnisIndent Rate keseluruhanX%Turun ke < 25% dalam 2 quarterAvg Inden Duration Error+X hari≤ +2 hari dari estimasi vendorRevenue at RiskRp X jutaTurun 40% via restock 10 produk prioritasProduk Critical (🔴)N produk0 produk Critical dalam 1 semester

3. SQL Query
sql-- ================================================================
-- EXECUTIVE DASHBOARD: INDEN IMPACT & REVENUE AT RISK ANALYSIS
-- Kolom FE baru : Inden_Flag     → 'Indent' / 'Ready'
--                 Inden_Est_Days → estimasi lama inden (integer hari)
-- Audience      : C-Level, Supply Chain Director, Finance
-- Compatible    : MySQL 8+ / PostgreSQL / BigQuery (minor adjustment)
-- ================================================================

-- ── PRE-STEP: Feature Engineering (jalankan sekali) ─────────────
/*
UPDATE Transaction_Items SET
    Inden_Flag = CASE
                    WHEN Inden_Status LIKE '%Inden%' THEN 'Indent'
                    ELSE 'Ready'
                 END,
    Inden_Est_Days = CASE
                        WHEN Inden_Status LIKE '%Inden%'
                        THEN CAST(REGEXP_SUBSTR(Inden_Status, '[0-9]+') AS UNSIGNED)
                        ELSE 0
                     END;
*/

-- ── LAYER 1: Base grain — 1 row per transaction line ────────────
WITH base AS (
    SELECT
        ti.Product_Code,
        ti.Product_Name,
        ti.Product_Type,
        ti.Inden_Flag,
        ti.Inden_Est_Days,
        ti.Quantity,
        ti.Item_Total,
        ti.Unit_Price,
        mp.Supplier_Cost,
        mp.Stock_Available,
        mp.Inden_Lead_Time_Days,
        tm.Order_Date,
        tm.Delivery_Date,
        tm.Invoice_Status,
        c.Customer_Name,
        c.Facility_Type,

        -- Actual lead time per transaksi
        DATEDIFF(tm.Delivery_Date, tm.Order_Date)           AS Actual_Lead_Time_Days,

        -- Error estimasi inden: positif = lebih lama dari janji
        DATEDIFF(tm.Delivery_Date, tm.Order_Date)
            - ti.Inden_Est_Days                             AS Inden_Estimation_Error,

        -- Gross margin per line
        (ti.Unit_Price - mp.Supplier_Cost) * ti.Quantity    AS Line_Margin,

        -- Revenue at risk: inden + belum lunas
        CASE
            WHEN ti.Inden_Flag    =  'Indent'
             AND tm.Invoice_Status NOT IN ('Lunas', 'Paid')
            THEN ti.Item_Total ELSE 0
        END                                                 AS Revenue_At_Risk

    FROM Transaction_Items  ti
    JOIN Transactions_Main  tm ON ti.Transaction_ID = tm.Transaction_ID
    JOIN Master_Products    mp ON ti.Product_Code   = mp.Product_Code
    JOIN Customer            c ON tm.Customer_ID    = c.Customer_ID
),

-- ── LAYER 2: Agregasi per produk ────────────────────────────────
product_level AS (
    SELECT
        Product_Code,
        Product_Name,
        Product_Type,
        Stock_Available,
        Inden_Lead_Time_Days,

        -- Volume
        COUNT(*)                                             AS Total_Lines,
        SUM(Quantity)                                        AS Total_Qty,

        -- Inden frequency
        SUM(CASE WHEN Inden_Flag = 'Indent' THEN 1 ELSE 0 END)
                                                             AS Indent_Lines,
        ROUND(
            100.0 * SUM(CASE WHEN Inden_Flag = 'Indent' THEN 1 ELSE 0 END)
            / COUNT(*), 1
        )                                                    AS Indent_Rate_Pct,

        -- Inden duration metrics
        ROUND(AVG(CASE WHEN Inden_Flag = 'Indent'
                       THEN Inden_Est_Days END), 1)          AS Avg_Est_Inden_Days,
        ROUND(AVG(CASE WHEN Inden_Flag = 'Indent'
                       THEN Actual_Lead_Time_Days END), 1)   AS Avg_Actual_LeadTime_Indent,
        ROUND(AVG(CASE WHEN Inden_Flag = 'Indent'
                       THEN Inden_Estimation_Error END), 1)  AS Avg_Estimation_Error_Days,
        MAX(CASE WHEN Inden_Flag = 'Indent'
                 THEN Inden_Estimation_Error END)            AS Max_Estimation_Error_Days,

        -- Revenue & margin
        SUM(Item_Total)                                      AS Total_Revenue,
        SUM(Line_Margin)                                     AS Total_Margin,
        ROUND(100.0 * SUM(Line_Margin)
              / NULLIF(SUM(Item_Total), 0), 1)               AS Margin_Pct,
        SUM(Revenue_At_Risk)                                 AS Revenue_At_Risk,

        -- Restock Priority Score
        -- Logic: produk dengan indent rate tinggi × revenue besar = prioritas tertinggi
        ROUND(
            (SUM(CASE WHEN Inden_Flag = 'Indent' THEN 1 ELSE 0 END) * 1.0
             / NULLIF(COUNT(*), 0))
            * SUM(Revenue_At_Risk)
        , 0)                                                 AS Restock_Priority_Score

    FROM base
    GROUP BY
        Product_Code, Product_Name, Product_Type,
        Stock_Available, Inden_Lead_Time_Days
),

-- ── LAYER 3: Rollup per kategori untuk konteks C-Level ──────────
category_level AS (
    SELECT
        Product_Type,
        COUNT(*)                                             AS Cat_Total_Products,
        ROUND(AVG(Indent_Rate_Pct), 1)                       AS Cat_Indent_Rate_Pct,
        ROUND(AVG(Avg_Est_Inden_Days), 1)                    AS Cat_Avg_Est_Inden_Days,
        ROUND(AVG(Avg_Estimation_Error_Days), 1)             AS Cat_Avg_Error_Days,
        SUM(Total_Revenue)                                   AS Cat_Total_Revenue,
        SUM(Revenue_At_Risk)                                 AS Cat_Revenue_At_Risk,
        ROUND(
            100.0 * SUM(Revenue_At_Risk)
            / NULLIF(SUM(Total_Revenue), 0), 1
        )                                                    AS Cat_Risk_Pct
    FROM product_level
    GROUP BY Product_Type
)

-- ── FINAL OUTPUT: Product detail + category context + action tag ─
SELECT
    -- Context kategori (untuk C-level grouping)
    pl.Product_Type                     AS Category,
    cl.Cat_Indent_Rate_Pct              AS Category_Indent_Rate_Pct,
    cl.Cat_Avg_Est_Inden_Days           AS Category_Avg_Est_Inden_Days,
    cl.Cat_Avg_Error_Days               AS Category_Estimation_Error_Days,
    cl.Cat_Risk_Pct                     AS Category_Revenue_Risk_Pct,

    -- Detail produk
    pl.Product_Code,
    pl.Product_Name,
    pl.Stock_Available,
    pl.Inden_Lead_Time_Days             AS Supplier_LeadTime_Days,
    pl.Total_Lines,
    pl.Indent_Lines,
    pl.Indent_Rate_Pct,

    -- Durasi & akurasi inden
    pl.Avg_Est_Inden_Days,
    pl.Avg_Actual_LeadTime_Indent,
    pl.Avg_Estimation_Error_Days,       -- (+) = vendor/ops underestimate
    pl.Max_Estimation_Error_Days,       -- worst case per produk

    -- Financial impact
    pl.Total_Revenue,
    pl.Total_Margin,
    pl.Margin_Pct,
    pl.Revenue_At_Risk,
    pl.Restock_Priority_Score,

    -- Executive action tag untuk decision support
    CASE
        WHEN pl.Indent_Rate_Pct >= 60
         AND pl.Revenue_At_Risk  > 0
        THEN '🔴 CRITICAL  — Restock Immediately'
        WHEN pl.Indent_Rate_Pct BETWEEN 30 AND 59
         AND pl.Revenue_At_Risk  > 0
        THEN '🟡 WARNING   — Plan Safety Stock'
        WHEN pl.Avg_Estimation_Error_Days > 5
        THEN '🔵 REVIEW    — Recalibrate Vendor Estimation'
        WHEN pl.Stock_Available < 5
         AND pl.Indent_Rate_Pct  < 30
        THEN '🟠 WATCH     — Low Stock, Monitor Closely'
        ELSE '🟢 NORMAL'
    END                                 AS Exec_Action_Tag

FROM product_level  pl
JOIN category_level cl ON pl.Product_Type = cl.Product_Type
WHERE pl.Total_Lines >= 5              -- filter noise: produk dengan data cukup
ORDER BY
    pl.Restock_Priority_Score  DESC,
    pl.Revenue_At_Risk         DESC,
    pl.Indent_Rate_Pct         DESC;
```

---

### 4. Expected Insight — C-Level Storytelling Format
```
╔══════════════════════════════════════════════════════════════╗
║         EXECUTIVE SUMMARY — INDEN IMPACT REPORT             ║
╠══════════════════════════════════════════════════════════════╣
║  Total Revenue at Risk     :  Rp 380 juta  (18% dari GMV)  ║
║  Rata-rata Inden Duration  :  11 hari  (estimasi: 7 hari)  ║
║  Estimation Error rata2    :  +4 hari  → vendor underquote  ║
║  Kategori Paling Terdampak :  Alat Medis — 67% indent rate  ║
╠══════════════════════════════════════════════════════════════╣
║  ACTION REQUIRED:                                            ║
║  🔴 3 produk  = 74% Revenue at Risk → restock segera        ║
║  🔵 2 kategori → estimasi vendor meleset > 5 hari           ║
║  🟡 5 produk  → safety stock perlu dinaikkan Q2             ║
╚══════════════════════════════════════════════════════════════╝
```

**Narasi untuk presentasi C-level:**
- **"Rp 380 juta revenue kami sedang menunggu inden selesai"** — bukan hilang, tapi tertahan dan bisa dipercepat
- **"Vendor kami secara konsisten underestimate 4 hari"** — ini bukan anomali, ini sistemik, perlu renegosiasi SLA
- **"3 produk saja sudah mewakili 74% masalah"** — solusi tidak perlu luas, cukup fokus dan terukur

---

## MATCH — 2026 Data Analyst Hiring Trends

| Tren DA Hiring 2026 | Bukti di Project Ini | Nilai di CV/Interview |
|---|---|---|
| **Multi-layer CTE** wajib di semua JD mid-senior | 3 layer: `base → product_level → category_level` | Tunjukkan di portofolio GitHub |
| **Feature Engineering** masuk scope DA | Kamu buat `Inden_Flag` + `Inden_Est_Days` dari raw string | Sebutkan sebagai "end-to-end DA ownership" |
| **Business framing** > technical flex | `Exec_Action_Tag`, KPI target, narasi C-level | Jawaban wajib saat ditanya "impact project kamu apa?" |
| **Stakeholder communication** jadi hard skill DA | Output dirancang untuk non-technical audience | Buktikan dengan mock dashboard/deck |
| **Supply chain & ops analytics** sektor tumbuh | Domain distributor = relevan ke FMCG, medis, logistik | Lamar ke perusahaan distribusi, 3PL, healthtech |
| **DA = decision enabler**, bukan reporter | `Restock_Priority_Score` = rekomendasi actionable | Framing: "saya tidak hanya analisis, saya bantu decide" |

**Positioning CV / Portfolio:**
```
"Built a C-level supply chain analytics pipeline with
 feature engineering on raw indent status data, surfacing
 Rp X revenue at risk across N products — structured using
 3-layer SQL CTE with business action tagging for executive
 decision support."