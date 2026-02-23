Domain: Distributor/Supply Chain | Audience: C-Level | Trend: DA Hiring 2026

F. FIND — 3 Kolom Utama
# AI:
grand_total (transactions_main) + invoice_status (transactions_main) + inden_flag (transactions_item)
Ketiganya langsung menyentuh cash flow dan fulfillment risk — bahasa C-level.

# Saya
**Setuju** - AI suggestion sudah tepat
**Alasan**: ketiganya adalah inti dari cash flow distributor. invoice_status menentukan uang sudah kembali atau belum, inden_flag menentukan kenapa delivery tertahan, grand_total mengkuantifikasi dampak finansialnya.

R. READ — Pattern Data
# AI
inden_flag menandai order yang tidak bisa langsung dipenuhi dari stok. Kombinasi dengan invoice_status yang punya 5% missing kemungkinan besar adalah transaksi yang belum selesai/dispute. grand_total memungkinkan segmentasi revenue per customer/facility_type. Pattern yang terbaca: ada potensi revenue tertahan akibat inden yang belum terselesaikan.

# Saya
**Setuju, Tapi ada sedikit Tambahan**
**Penjelasan Tambahan**
Dari 350 total transaksi:
79.71% transaksi tidak melibatkan inden sama sekali — artinya mayoritas bisnis ini adalah transaksi reguler. Hanya 20.29% (±71 transaksi) yang melibatkan inden.
Tapi yang menarik: delivery_date kosong 54% — lebih dari separuh transaksi belum selesai dikirim. Ini tidak proporsional dengan jumlah inden yang hanya 20.29%. Artinya ada transaksi non-inden yang juga belum terkirim — kemungkinan menunggu konfirmasi customer atau terkena dampak cancelled.
invoice_status dengan 5% null + pattern cancelled + waiting DN menunjukkan ada kebocoran di pipeline collection — uang yang seharusnya sudah masuk tapi tertahan di berbagai tahap.
Pattern yang terbaca: Revenue collection bottleneck — bukan masalah penjualan, tapi masalah penagihan dan fulfillment.

A. ASK — 3 KPI Bisnis
# AI
Collection Rate — % invoice lunas vs total tagihan (langsung ke kas)
Inden Fulfillment Rate — % inden yang selesai tepat waktu vs estimasi
Revenue at Risk — total grand_total dari invoice yang statusnya pending/belum lunas

# Saya
**Kurang setuju, ada tambahan, dan sedikit revisi**
**Tambahan dan Penjelasan**
Berdasarkan data aktual 350 transaksi dengan konteks distributor alat kesehatan:
KPI 1 — Invoice Collection Rate
% transaksi complete dari total. Dari persentase sebelumnya, complete 56.22% — artinya 43.78% belum collected.
KPI 2 — Inden Fulfillment Accuracy
% transaksi inden yang actual time-nya sesuai atau lebih cepat dari estimasi. Basis: 71 transaksi inden.
KPI 3 — Revenue at Risk
Total grand_total dari semua transaksi yang berstatus bukan complete — dipecah per status invoice.
KPI 4 — Delivery Fulfillment Rate
% transaksi yang sudah punya delivery_date dari total — karena 54% kosong, ini langsung jadi indikator operasional kritis.
KPI 5 — Cancellation Impact Rate
% dan nilai revenue dari transaksi cancelled, dengan breakdown apakah dipicu inden atau bukan.


M. MATCH — Business Problem Template
# AI
✅ Revenue — spesifiknya: revenue tertahan akibat inden + invoice belum lunas

# Saya
 **Alasan**: revenue collection bottleneck akibat inden delay dan pipeline invoice yang tidak berjalan smooth


E. EXECUTE

1. Business Question
# AI
Berapa total revenue yang sedang tertahan akibat kombinasi order inden yang belum terpenuhi dan invoice yang belum lunas — dan siapa customer dengan exposure terbesar?

# Saya
**Setuju**
**Alasan dan Penjelasan Tambahan**
Berapa total revenue yang tertahan di pipeline — dipecah per status invoice dan penyebabnya — dan mana yang paling urgent untuk di-recover dalam 30 hari ke depan?


2. KPI Target
# AI
Revenue at Risk (Rp) = Grand total dari transaksi dengan inden_flag = 1 AND invoice_status != 'paid'

# Saya
**Tidak Setuju**
**Alasan**
Lebih baik fokus pada Revenue Recovery Priority Index — ranking status invoice berdasarkan nilai revenue tertahan + estimasi kemungkinan recover


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
# AI
Contoh hasil yang realistis untuk distributor mid-size:
"Dari total revenue 12 bulan terakhir, estimasi Rp 1,2M–2,8M (15–22%) dalam status at-risk. Top 3 customer menyumbang 60% dari angka tersebut. Rata-rata estimasi inden 14–21 hari — jika melebihi ini tanpa update invoice, kemungkinan dispute atau churn tinggi."
Angka ini yang dibawa ke C-level: bukan chart inden, tapi "ada Rp X yang belum kembali ke kas kita."

# Saya
**Tidak Setuju**
**Alasan**
Dari 350 transaksi dengan total revenue estimasi, output query ini akan menunjukkan ranking seperti:
"Status NULL (3 transaksi) dan customer confirmation adalah prioritas tertinggi untuk investigasi minggu ini. Waiting DN menyimpan revenue terbesar kedua yang bisa di-collect paling cepat hanya dengan follow up PIC rumah sakit. Total revenue yang actionable dalam 30 hari: estimasi 25-35% dari total grand_total."

5. Portfolio Title
Uncollected Revenue Tracker: Identifying Cash Flow Risk from Indent Orders in B2B Distribution
Sub-judul GitHub: "SQL-based analysis to quantify revenue at risk from unfulfilled indent orders and unpaid invoices — built for C-level decision making."