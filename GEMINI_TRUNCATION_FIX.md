# GEMİNİ TRUNCATION SORUNU VE ÇÖZÜMÜ
## Sorun
Gemini --yolo prompt'a büyük HTML (50KB+) gönderilince 700-2000 byte truncated yanıt veriyor.

## Kural (Sprint 10'dan itibaren)
1. Gemini'ye büyük HTML gönderilmez
2. Yeni sayfa: sadece spec (maks 50 satır prompt)
3. Mevcut sayfa güncelleme: sadece eklenecek script bloğu istenir (>> ile append)
4. Kontrol: SZ < 15000 → git restore → Python stub

## Doğru Gemini Kullanımı
# YANLIŞ:
# gemini --yolo -p "Update this HTML: $(cat büyük-dosya.html)"

# DOĞRU:
# gemini --yolo -p "Write a <script> block that does X. Output only the script tag."
# >> dosya.html  # append et (overwrite değil)

## Sprint Geçmişi
Sprint 7: cariler.html 1096B, konsimento.html 1553B → git restore + Python inject
Sprint 8: auditlog.html 698B → Python stub 20KB
Sprint 9: auditlog.html 779B + 1900B → git restore
Sprint 10: Kural kesinleşti — HTML gönderme yasağı
