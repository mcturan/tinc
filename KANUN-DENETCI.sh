#!/bin/bash
ERRORS=0
WARNINGS=0
REPORT="/home/turan/İndirilenler/DENETCI-RAPOR-$(date +%Y%m%d-%H%M).txt"

echo "=== KANUN DENETÇİSİ RAPORU ===" > $REPORT
echo "Tarih: $(date)" >> $REPORT
echo "" >> $REPORT

echo "--- LAW-001: Commit formatı ---" >> $REPORT
cd /home/turan/workspace/qrvee
LAST_COMMIT=$(git log -1 --pretty=%s 2>/dev/null)
if [[ ! "$LAST_COMMIT" =~ (TASK-|FAZ-|SYNC:|docs:|fix:|feat:|chore:) ]]; then
  echo "UYARI: Commit mesajı standart değil: $LAST_COMMIT" >> $REPORT
  WARNINGS=$((WARNINGS+1))
else
  echo "PASS: $LAST_COMMIT" >> $REPORT
fi

echo "" >> $REPORT
echo "--- LAW-002: Uncommitted dosyalar ---" >> $REPORT
for REPO in qrvee tinc pnot; do
  DIRTY=$(git -C /home/turan/workspace/$REPO status --porcelain 2>/dev/null | wc -l)
  if [ "$DIRTY" -gt 0 ]; then
    echo "UYARI: $REPO — $DIRTY uncommitted dosya" >> $REPORT
    WARNINGS=$((WARNINGS+1))
  else
    echo "PASS: $REPO temiz" >> $REPORT
  fi
done

echo "" >> $REPORT
echo "--- LAW-003: TypeScript build (sadece CI'da tam çalışır) ---" >> $REPORT
if [ -f /home/turan/workspace/qrvee/apps/web/package.json ]; then
  echo "INFO: TypeScript kontrolü için CI/GitHub Actions kullanılıyor" >> $REPORT
else
  echo "UYARI: qrvee/apps/web bulunamadı" >> $REPORT
fi

echo "" >> $REPORT
echo "--- LAW-004: Ollama denetçi ---" >> $REPORT
if command -v ollama &>/dev/null; then
  echo "PASS: Ollama kurulu" >> $REPORT
else
  echo "UYARI: Ollama kurulu değil — yerel denetçi pasif" >> $REPORT
  WARNINGS=$((WARNINGS+1))
fi

echo "" >> $REPORT
echo "=== ÖZET ===" >> $REPORT
echo "HATA: $ERRORS" >> $REPORT
echo "UYARI: $WARNINGS" >> $REPORT
if [ $ERRORS -eq 0 ]; then
  echo "DURUM: GEÇTİ" >> $REPORT
else
  echo "DURUM: BAŞARISIZ" >> $REPORT
fi
cat $REPORT
