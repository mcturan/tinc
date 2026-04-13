#!/bin/bash
# SEYİR DEFTERİ OTOMATİK GÜNCELLEME
# Kullanım: bash seyir_guncelle.sh "FAZ-06" "OPS Core FIN tamamlandi"
FAZ_NO="${1:-BILINMIYOR}"
FAZ_OZET="${2:-Guncelleme yapildi}"
TARIH=$(date '+%Y-%m-%d %H:%M')
SEYIR="/tmp/tinc_team/SEYİR_DEFTERİ.md"
ARSIV_SATIR=$(grep -n "^## ARŞİV" "$SEYIR" | cut -d: -f1)
QRVEE=$(cd /home/turan/workspace/qrvee 2>/dev/null && git log -1 --pretty="%h — %s" 2>/dev/null)
TINC=$(cd /home/turan/workspace/tinc 2>/dev/null && git log -1 --pretty="%h — %s" 2>/dev/null)
PNOT=$(cd /home/turan/workspace/pnot 2>/dev/null && git log -1 --pretty="%h — %s" 2>/dev/null)
YENI="
---

## SON DURUM: ${FAZ_NO} TAMAMLANDI
**Tarih:** ${TARIH}
**Yazan:** seyir_guncelle.sh (otomatik)

### Bu Fazda Ne Yapıldı
${FAZ_OZET}

### Son Commitler
- qrvee: ${QRVEE}
- tinc: ${TINC}
- pnot: ${PNOT}

"
if [ -n "$ARSIV_SATIR" ]; then
  HEAD=$(head -n 5 "$SEYIR")
  AFTER_HEADER=$(tail -n "+6" "$SEYIR")
  { echo "$HEAD"; echo "$YENI"; echo "$AFTER_HEADER"; } > /tmp/seyir_tmp.md
  mv /tmp/seyir_tmp.md "$SEYIR"
else
  echo "$YENI" >> "$SEYIR"
fi
cd /tmp/tinc_team
git add "SEYİR_DEFTERİ.md"
git commit -m "${FAZ_NO}: seyir defteri guncellendi"
git push origin main 2>/dev/null
echo "Seyir defteri güncellendi: ${FAZ_NO}"
