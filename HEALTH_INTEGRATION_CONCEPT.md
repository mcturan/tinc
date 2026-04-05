# HEALTH DATA INTEGRATION — CONCEPT

**Durum:** CONCEPT ONLY — hiçbir kod yazılmadı

## Planlanan Veri Kaynakları
- Apple HealthKit (iOS)
- Google Health Connect (Android)

## Planlanan Veri Alanları
- Uyku süresi (saat)
- Uyku kalitesi (derin/yüzeysel/REM)
- Kalp atış hızı
- Adım sayısı / aktivite seviyesi

## Maskot Davranış Örnekleri
Tetikleyici: uyku < 6 saat
→ RF: "Dün gece az uyudun. Bu gece erken yat, yarın sabah 40m bandı harika olacak."

Tetikleyici: uyku > 8 saat + K-index < 2
→ RF: "Hem dinlendin hem prop mükemmel. Bu gece DMR çevrimine katılmak ister misin?"

Tetikleyici: adım sayısı < 2000 (hareketsiz gün)
→ ANT: "Bugün fazla hareket etmedin. Kısa bir SOTA aktivasyonu seni hem dışarı çıkarır hem log doldurur."

## Gizlilik Modeli
[NOT DESIGNED] — İzin modeli, veri saklama, kullanıcı onayı henüz tasarlanmadı

## Uygulama Zamanlaması
FAZ 3+ — QRVEE stabilizasyonundan sonra ele alınacak
