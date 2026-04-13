# ══════════════════════════════════════════════════════════════
# ZORUNLU OKUMA BLOĞU — Her komut dosyasının başında bulunur.
# Bu bloğu atla = görevi reddet ve Müteahhit'e bildir.
# ══════════════════════════════════════════════════════════════

## REFERANS DOSYALAR — BAŞLAMADAN ÖNCE OKU
cat /home/turan/workspace/tinc_team/TEAM.md
cat /home/turan/workspace/tinc_team/LAWS.md
cat /home/turan/workspace/tinc_team/DESIGN_PROTOCOL.md
cat /home/turan/workspace/tinc/MASTER_SPEC.md
cat /home/turan/workspace/tinc/DECISION_LOG.md | tail -60
cat /home/turan/workspace/tinc_team/SEYİR_DEFTERİ.md | head -50

## ROL TANIMLARI (Değişmez — LAW-020)

| Agent | Rol | Yapamaz |
|-------|-----|---------|
| Müteahhit (Cevad) | Karar verir, onaylar | — |
| Claude Pro | Spec yazar, denetler, komut üretir | Kod yazar, tasarım yapar |
| Claude Code | Komut okur, uygular, commit, rapor | Spec dışı karar verir |
| Codex CLI / Go | Büyük kod yazar | Spec dışı field/logic ekler |
| Google Stitch | UI üretir (stitch.withgoogle.com) | Backend karar verir |
| Gemini CLI | DesignSpec.md yazar → DESIGN_SPECS/ | Tasarım dışı karar |
| Gemini Pro | Spec uyum doğrular PASS/REJECT | Subjektif kalite değerlendirir |
| Ollama/Aider | Küçük düzeltme, yerel denetim | Mimari karar verir |
| seyir_guncelle.sh | Faz sonu otonom log | — |
| Görsel üretim (maskot, illüstrasyon, ikon) | Codex → DALL-E API | — |
| GitHub Actions | Push sonrası otonom CI | — |

## TASARIM PIPELINE (LAW-016, LAW-017 — İhlal = DUR)
Sen (brief) → Stitch (UI) → Gemini CLI (DesignSpec.md) →
Claude Pro (spec uyum) → FINAL → Codex (implement) → Gemini Pro (doğrula)
NOT: Claude Code ve Codex tasarım kararı veremez.
NOT: DRAFT DesignSpec ile Codex çalışamaz.

## AKTİF KANUNLAR (Tamamı — İhlal = DUR ve bildir)
LAW-001: DR+CR = 0 (OPS çift giriş)
LAW-002: TASK → EXECUTION → RESULT, adım atlanamaz
LAW-003: Her karar DECISION_LOG'a yazılmadan tamamlanmış sayılmaz
LAW-004: Aynı input = aynı output, yorum yok
LAW-005: Uygulamalar birbirine direkt API çağrısı yapamaz
LAW-006: events_* yazıldıktan sonra değiştirilemez
LAW-007: İş mantığında sadece serverTime
LAW-008: Çevrimdışıyken OfflineQueue
LAW-009: Her task sonucu audit edilir
LAW-010: 8 spec dosyası yoksa task çalışmaz
LAW-011: TypeScript sıfır hata — hatalı build push edilemez
LAW-012: Commit: FAZ-XX / TASK-XXX / feat: / fix: / docs: / chore: / SYNC:
LAW-013: Local state geçici — Firestore tek kalıcı kaynak
LAW-014: Cross-app etkiler sadece Cloud Function'da
LAW-015: Kullanıcı aksiyonu olmadan popup/modal tetiklenemez
LAW-016: DRAFT DesignSpec ile Codex çalışamaz
LAW-017: UI/UX sadece Gemini+Stitch — Claude karışmaz
LAW-018: KANUN-DENETCI.sh BAŞARISIZ ise push yapılmaz
LAW-019: DECISION_LOG append-only, satır silinemez
LAW-020: Agent kendi tanımı dışında karar veremez
LAW-021: Kanun değişikliği sadece Müteahhit onayıyla

## PRECHECK (Her görev başlamadan önce çalıştır)
ls /home/turan/workspace/tinc/MASTER_SPEC.md || { echo "MASTER_SPEC EKSİK — DUR"; exit 1; }
ls /home/turan/workspace/tinc/EVENT_CONTRACTS.md || { echo "EKSİK — DUR"; exit 1; }
ls /home/turan/workspace/tinc/DATA_MODEL.md || { echo "EKSİK — DUR"; exit 1; }
ls /home/turan/workspace/tinc/CALCULATION_RULES.md || { echo "EKSİK — DUR"; exit 1; }
ls /home/turan/workspace/tinc/VALIDATION_RULES.md || { echo "EKSİK — DUR"; exit 1; }
ls /home/turan/workspace/tinc/LEDGER_RULES.md || { echo "EKSİK — DUR"; exit 1; }
ls /home/turan/workspace/tinc/TRANSACTION_MAPPING.md || { echo "EKSİK — DUR"; exit 1; }
ls /home/turan/workspace/tinc/ENFORCEMENT.md || { echo "EKSİK — DUR"; exit 1; }
echo "PRECHECK PASSED"

## FAZ SONU PROTOKOL (Her faz sonunda — atlanamaz)
# A: npx tsc --noEmit — sıfır hata zorunlu
# B: bash /home/turan/workspace/tinc/KANUN-DENETCI.sh
# C: bash /home/turan/workspace/tinc/seyir_guncelle.sh "FAZ-XX" "özet"
# D: FEATURES.md güncelle (❌ → ✅)
# E: DECISION_LOG girişi ekle
# F: /home/turan/İndirilenler/FAZ-XX_Results.md yaz

# ══════════════════════════════════════════════════════════════
# ZORUNLU OKUMA SONU — Şimdi asıl göreve geç
# ══════════════════════════════════════════════════════════════

## KRİTİK KURAL — FALLBACK YASAĞI

Claude Code asla kendi başına "Codex/Gemini cevap vermedi, ben yapayım" kararı alamaz.
Codex veya Gemini bir görevi tamamlamazsa:
1. DUR
2. Rapor dosyasına yaz: "GÖREV-X: Codex/Gemini tamamlamadı — Müteahhit kararı gerekiyor"
3. Bekle

Bu kural ihlal edilemez. İhlal = görevi bırak, rapor yaz.

## DALL-E KULLANIM KURALLARI (Codex üzerinden)

Codex, DALL-E API'ye erişebilir. Şu görevler için kullanılır:

| Görev | Açıklama |
|-------|----------|
| WAVLEE maskot görselleri | Robot baykuş, EVA stili, farklı pozlar |
| Landing page hero görselleri | Ham radio ekipmanları, anten, shack |
| Feature section görseli | SDR waterfall, harita, ekipman |
| Tamagochi/animasyon frame'leri | WAVLEE animasyonu için kareler |
| UI ikonlar | Telsiz temalı SVG'ye dönüştürülecek referanslar |

**Kural:** DALL-E çıktıları doğrudan production'a gitmez.
Önce Claude Pro'ya gösterilir, onay sonrası kullanılır.

**Prompt şablonu (Codex kullanır):**
**WAVLEE için sabit stil parametreleri:**
- Robot owl, EVA (Wall-E) aesthetic
- Cyan glowing visor eyes
- White/silver metallic body
- Tall slender proportions
- Levitating (no legs/feet visible)
- Studio lighting, clean background


## WAVL MCP — GELECEKTEKİ MİMARİ (FAZ-20+)

Firestore event bus → MCP Server → Dış AI istemcileri
LAW-005 uyumlu. Kullanıcı tabanı oluşunca aktif edilir.
Şimdi mimari karar değil — sadece bilinç kaydı.
