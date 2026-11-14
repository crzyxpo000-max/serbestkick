# CLAUDE.md — Serbest Kick

Android için 3D, gerçekçi görünümlü serbest vuruş oyunu. Motor Godot 4.6 (GDScript). Tasarım ve aşamalar:
`docs/PLAN.md` (her işten önce oku). Sıra önemlidir: bir aşama bitiş ölçütünü karşılamadan sonrakine geçilmez.

## Durum

- **Aşama 0 (kurulum) tamam:** proje iskeleti, boş sahne, test koşucusu, otomatik derleme (web + debug APK).
- Sıradaki: Aşama 1, top fiziği (`scripts/physics/`) ve testleri.

## Komutlar

```bash
godot --headless --path . --import                              # ilk açılışta ve yeni dosyadan sonra
godot --headless --path . --script res://tests/run_tests.gd     # testler (çıkış kodu 0 = geçti)
godot --headless --path . --export-release Web build/web/index.html
```

GitHub Actions (`.github/workflows/build.yml`) her `main` gönderiminde testleri çalıştırır, web çıktısını
GitHub Pages'e yayınlar ve debug APK'yı iş çıktısı olarak ekler.

## Kurallar

- Topun uçuşu Godot'nun fizik motoruna bırakılmaz; kendi formüllerimizle hesaplanır (yerçekimi, hava direnci,
  Magnus, dönüş kaybı, rüzgar). Fizik kodu sahneden bağımsız, saf hesap sınıfları olarak yazılır ki başsız test edilebilsin.
- Her formül ve kural için `tests/test_*.gd` içinde test yazılır. Test yöntemi `test_` ile başlar ve hata listesi
  (`Array[String]`) döndürür; boş liste geçti demektir.
- Fizik, kontrol, kaleci, maç akışı ve kariyer ayrı klasörlerde: `scripts/physics|control|keeper|match|career`.
- Krampon değerleri ve pozisyon ayarları kodda değil `data/` altındaki veri dosyalarında durur.
- Web çıktısı Compatibility, Android Mobile işleyicisini kullanır; web'de iş parçacığı kapalıdır (GitHub Pages için).
- Gerçek kulüp, lig ve oyuncu adı kullanılmaz. Hazır modellerin lisansı eklenmeden önce kontrol edilir.
- Oyun içi metinler şimdilik Türkçe (dil kararı açık).
