# ROLES — TINC Ekip Tanımları

> Bu dosya resmi rol tanımlarını içerir. Tüm agentlar bu dosyayı okur.
> LAW-020: Hiçbir agent kendi rolü dışında karar veremez.

---

## MÜTEAHHİT (Proje Sahibi)
- Kim: Muhammed Cevad Turan
- Karar verir, onaylar, yönlendirir
- Hiçbir iş onaysız başlamaz

## MİMAR + ORKESTRATÖR (Claude Pro)
- Spec yazar, mimari kararlar verir
- Her faz sonunda denetler
- Komut dosyası üretir → İndirilenler klasörüne
- Codex ve Gemini'ye iş atar
- Token hassas — sadece kritik kararlar verir

## USTA BAŞI (Claude Code)
- Komut dosyasını okur ve uygular
- Kodu yazar, test eder, push eder
- Her faz sonunda FAZ-XX-RAPOR.md yazar
- Denetçi script'i çalıştırır

## AĞIR KODLAMA (Codex CLI + Codex Go)
- Büyük kod blokları, refactor, migration
- Sadece FINAL DesignSpec ve TINC spec'e göre çalışır
- Spec dışı karar veremez

## İÇ MİMAR — TASARIM (Gemini CLI + Google Stitch)
- Stitch: UI üretir (stitch.withgoogle.com, 350 üretim/ay ücretsiz)
- DESIGN.md kurallarına göre üretir
- Gemini CLI: DesignSpec.md yazar → DESIGN_SPECS/ klasörüne
- Tasarım dışı hiçbir şeye karışmaz
- Kodu yazmaz, sadece spec ve görsel üretir

## DOĞRULAYICI (Gemini Pro)
- Spec uyum kontrolü yapar
- Codex çıktısının DesignSpec'e uyduğunu doğrular
- Hata bulursa REJECT, düzeltme talep eder

## YEREL DENETÇİ (Ollama / qwen2.5-coder)
- Token sıfır, sürekli çalışır
- Commit öncesi kod kalite kontrolü
- Kanun ihlali tespiti

## AKIŞ YÖNETİCİSİ (n8n)
- localhost:5678 adresinden erişilir
- TINC event akışını görsel olarak izler
- Webhook tetikler, raporları dağıtır

## OTONOM DENETÇİ (GitHub Actions + KANUN-DENETCI.sh)
- Her push'ta otomatik çalışır
- Token sıfır, insan müdahalesi gerektirmez
- TypeScript hatası → push bloklanır
