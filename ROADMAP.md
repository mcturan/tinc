# WAVL + TINC PLATFORM YOL HARİTASI
**Son güncelleme:** 2026-04-15

## WAVL (QRVEE) — MEVCUT DURUM

### ✅ Tamamlanan (FAZ-01 → FAZ-20)
- Workspace + altyapı + 21 kanun
- QRVEE → WAVL display rename
- Landing page (canvas waterfall, orbital hero, dashboard mock, açık tema)
- DALL-E görseller (13 adet, production'da)
- Stripe webhook + checkout CF (Codex)
- Firebase Auth + callsign doğrulama (Codex)
- Dashboard CF'leri: getLiveOperators, getSpaceWeather, getDashboardData, setOperatorStatus
- Onboarding page
- Vercel deploy: qrvee.vercel.app ✅ CANLI

### ⏳ WAVL Bekleyen (Beklemeye Alındı)
| Görev | Öncelik | Not |
|-------|---------|-----|
| wavl.ee domain + DNS | Yüksek | Domain alınmadı |
| Stripe price ID'leri | Yüksek | stripe.com'dan alınacak |
| Firebase Functions deploy | Yüksek | cd firebase/functions && npm run deploy |
| Vercel env: Stripe keys | Yüksek | Stripe dashboard sonrası |
| Mapbox token | Orta | Harita için |
| hamdb.org API test | Orta | curl ile test |
| WAVLEE logo (harici) | Düşük | Müteahhit yaptıracak |
| 3D WAVLEE maskot | Düşük | Platform oturduğunda |
| PWA manifest | Düşük | |
| RF + ANT oyunları | Düşük | FAZ-20+ |
| PNOT UI | Düşük | CF'ler hazır |
| MINWIN frontend | Düşük | MVP hazır |

---

## OPS — SIRADAKI PLATFORM

### Karar (2026-04-15)
OPS bağımsız çalışacak şekilde önce hızlıca bitirilecek.
TINC entegrasyonu sonraya bırakıldı.
FIRINNA-POS ile aynı yaklaşım.

### OPS Hedefi
Çift kayıt muhasebesi (LAW-001 uyumlu), case yönetimi,
HomeAssistant benzeri modüler dashboard.
WAVL dashboard'u base alınacak.

### OPS Mevcut Durum
- ✅ CalculationEngine (FAZ-06)
- ✅ createCase + createTransfer CF
- ✅ createParty, listParties, createAccount, getAccountBalance (FAZ-08B)
- ✅ Minimal UI (port 3001)
- ❌ Modüler dashboard
- ❌ Tam UI

### OPS Yol Haritası (Sıradaki Fazlar)
| Faz | Görev | Agent |
|-----|-------|-------|
| OPS-FAZ-01 | Boş modüler dashboard (HomeAssistant tarzı) | Gemini |
| OPS-FAZ-02 | Widget'lar: Bakiye, Kasa, Son İşlemler | Codex |
| OPS-FAZ-03 | Widget: Döviz kurları (canlı API) | Codex |
| OPS-FAZ-04 | Widget: Komisyon hesaplayıcı | Codex |
| OPS-FAZ-05 | FIRINNA-POS bağlantısı (opsiyonel) | Codex |

---

## FIRINNA-POS
- Bağımsız geliştirme — TINC entegrasyonu sonra
- OPS bittikten sonra

---

## PNOT / MINWIN
- CF'ler hazır bekliyor
- WAVL beklemeye alındığında başlanabilir

---

## TINC CORE
- Event bus V2.3 stabil
- 21 kanun, ZORUNLU_BASLIK güncel
- MCP planı: FAZ-28+ (500+ operatör sonrası)
