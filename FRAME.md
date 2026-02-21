Domain: Distributor/Supply Chain | Audience: C-Level | Trend: DA Hiring 2026

F. FIND — 3 Kolom Utama
# AI:
grand_total (transactions_main) + invoice_status (transactions_main) + inden_flag (transactions_item)
Ketiganya langsung menyentuh cash flow dan fulfillment risk — bahasa C-level.

# Saya
**Setuju** - AI suggestion sudah tepat
**Alasan**:
1. grand_total + invoice_status ← 

R. READ — Pattern Data
inden_flag menandai order yang tidak bisa langsung dipenuhi dari stok. Kombinasi dengan invoice_status yang punya 5% missing kemungkinan besar adalah transaksi yang belum selesai/dispute. grand_total memungkinkan segmentasi revenue per customer/facility_type. Pattern yang terbaca: ada potensi revenue tertahan akibat inden yang belum terselesaikan.

A. ASK — 3 KPI Bisnis

Collection Rate — % invoice lunas vs total tagihan (langsung ke kas)
Inden Fulfillment Rate — % inden yang selesai tepat waktu vs estimasi
Revenue at Risk — total grand_total dari invoice yang statusnya pending/belum lunas


M. MATCH — Business Problem Template
✅ Revenue — spesifiknya: revenue tertahan akibat inden + invoice belum lunas

E. EXECUTE

1. Business Question
Berapa total revenue yang sedang tertahan akibat kombinasi order inden yang belum terpenuhi dan invoice yang belum lunas — dan siapa customer dengan exposure terbesar?

2. KPI Target
Revenue at Risk (Rp) = Grand total dari transaksi dengan inden_flag = 1 AND invoice_status != 'paid'

3. SQL Query
sqlSELECT
    c.customer_id,
    c.customer_name,
    c.facility_type,
    COUNT(DISTINCT tm.transaction_id)        AS total_transaksi_berisiko,
    SUM(tm.grand_total)                      AS revenue_at_risk,
    ROUND(
        SUM(tm.grand_total) * 100.0 /
        SUM(SUM(tm.grand_total)) OVER ()
    , 2)                                     AS pct_dari_total_revenue,
    AVG(ti.inden_est_time_days)              AS rata_rata_estimasi_inden_hari,
    COUNT(CASE WHEN tm.invoice_status IS NULL 
               THEN 1 END)                   AS invoice_status_missing

FROM transactions_main tm
JOIN customers c 
    ON tm.customer_id = c.customer_id
JOIN transactions_item ti 
    ON tm.transaction_id = ti.transaction_id

WHERE 
    ti.inden_flag = 1
    AND (
        tm.invoice_status != 'paid'
        OR tm.invoice_status IS NULL
    )
    AND tm.order_date >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH)

GROUP BY 
    c.customer_id,
    c.customer_name,
    c.facility_type

ORDER BY 
    revenue_at_risk DESC

LIMIT 20;

Catatan handling missing values: invoice_status IS NULL sudah di-capture eksplisit di WHERE clause — tidak di-drop, justru dihitung sebagai bagian dari risiko.


4. Expected Insight
Contoh hasil yang realistis untuk distributor mid-size:
"Dari total revenue 12 bulan terakhir, estimasi Rp 1,2M–2,8M (15–22%) dalam status at-risk. Top 3 customer menyumbang 60% dari angka tersebut. Rata-rata estimasi inden 14–21 hari — jika melebihi ini tanpa update invoice, kemungkinan dispute atau churn tinggi."
Angka ini yang dibawa ke C-level: bukan chart inden, tapi "ada Rp X yang belum kembali ke kas kita."

5. Portfolio Title
Uncollected Revenue Tracker: Identifying Cash Flow Risk from Indent Orders in B2B Distribution
Sub-judul GitHub: "SQL-based analysis to quantify revenue at risk from unfulfilled indent orders and unpaid invoices — built for C-level decision making."