# CLAUDE.md — Serbest Kick

Android için 3D, gerçekçi görünümlü serbest vuruş oyunu. Motor Godot 4.6 (GDScript). Tasarım ve aşamalar:
`docs/PLAN.md` (her işten önce oku). Sıra önemlidir: bir aşama bitiş ölçütünü karşılamadan sonrakine geçilmez.

## Durum

- **Aşama 0 (kurulum) tamam:** proje iskeleti, boş sahne, test koşucusu, otomatik derleme (web + debug APK).
- **Aşama 1 (top fiziği) tamam:** `scripts/physics/` (uçuş, sekme, yuvarlanma, direk, file, gol kararı) ve testleri.
- **Aşama 2 (kontrol) tamam:** `scripts/control/` (kaydırma ölçümü, vuruş kurulumu, vuruş noktası, dönüşsüz vuruş,
  havada falso) ve testleri. Ana sahne gri kutulu antrenman sahasıdır: hedef halkası, rastgele konum, isabet sayacı.
- **Aşama 3 (his ayarı):** kullanıcının telefon geri bildirimiyle güç, falso ve nişan değerleri ayarlandı ("şimdi iyi").
- **Aşama 4 (kaleci ve baraj) tamam:** `scripts/keeper/` ve testleri. Antrenman sahasında baraj (mesafeye göre 2–4 kişi)
  ve kaleci var; zorluk kullanıcının geri bildirimiyle ayarlandı.
- **Aşama 5 (krampon) tamam:** `scripts/boots/boot.gd`, `data/boots.json` (4 tip), seçim ekranı ve testleri.
  Kullanıcının telefonda denemesi bekleniyor.
- Sıradaki: Aşama 6, maç senaryosu (hızlı akan maç, oyuna alınma, baskı, sonuç) → `scripts/match/`.

## Komutlar

```bash
godot --headless --path . --import                              # ilk açılışta ve yeni dosyadan sonra
godot --headless --path . --script res://tests/run_tests.gd     # testler (çıkış kodu 0 = geçti)
godot --headless --path . --export-release Web build/web/index.html
```

GitHub Actions (`.github/workflows/build.yml`) her `main` gönderiminde testleri çalıştırır, web çıktısını
GitHub Pages'e yayınlar ve debug APK'yı iş çıktısı olarak ekler.

## Fizik (`scripts/physics/`)

| Dosya | İçerik |
| --- | --- |
| `physics_params.gd` | Ayar değerleri; varsayılanların üzerine `data/physics.json` yazılır |
| `ball_state.gd` | Konum, hız, dönüş (rad/s); `from_kick(konum, hız, yükseliş, yön, yan falso, üst falso)` |
| `ball_flight.gd` | İvme (yerçekimi, direnç, Magnus, rüzgar) ve RK4 adımı, dönüş kaybı |
| `ball_collision.gd` | Sürtünmeli sekme (hız ↔ dönüş aktarımı) |
| `goal_frame.gd` | Kale ölçüleri, direk doğru parçaları |
| `ball_simulator.gd` | Bir vuruşun tamamı: sabit 1/240 sn adım, sonuç (`GOAL`, `OUT`, `STOPPED`), çizgi geçiş noktası |
| `pitch_conditions.gd` | Rüzgar ve ıslak saha |

## Kontrol (`scripts/control/`)

| Dosya | İçerik |
| --- | --- |
| `control_params.gd` | Ayar değerleri; üzerine `data/controls.json` yazılır |
| `swipe.gd` | Kaydırma ölçümü: hız (ekran yüksekliği/s), eğrilik, çıkış noktası |
| `shot_builder.gd` | Kaydırma + vuruş noktası → `BallState`; yükseliş açısını çözer |
| `aim_assist.gd` | Gizli nişan yardımı: direğin/üst direğin az dışına giden nişanı içeri çeker, baraja takılan vuruşu biraz yükseltir |
| `aftertouch.gd` | Havada falso: uçuşun ilk yarısında dönüşü en fazla ±%20 değiştirir |

Nişan: kaydırmanın çıkış noktasından (ilk yönde dümdüz gidilseydi varılacak ekran noktası) geçen kamera ışını kale
düzlemini nerede kesiyorsa falsosuz top oraya gider. Yay sağa bombeliyse top sağa çıkar, sola kıvrılır. Vuruş
noktası: alt = alt falso ve ek yükseliş, üst = üst falso, sağ = sola kıvrılır, tam orta = en sert ve dönüşsüz
(yalpalar). Girdi `scripts/main.gd` içinde `InputEventScreenTouch/Drag` ile işlenir (fare dokunmaya çevrilir);
çizimler `scripts/ui/practice_hud.gd`. Ekran koordinatları görünüm alanı birimindedir (720 yükseklik).

Nişan yardımı kullanıcının isteğiyle gizlidir: arayüzde adı geçmez, göstergesi yoktur. Gücü `data/controls.json`
içindeki `assist_*` değerleriyle ayarlanır (`assist_strength = 0` kapatır). Düzeltme süreklidir ve küçüktür.

## Krampon (`scripts/boots/`, `data/boots.json`)

Dört özellik vuruş hesabına `ShotBuilder.build(..., boot, noise, wet)` içinde girer: `power` en yüksek çıkış hızı,
`curl` en yüksek yan dönüş (vuruş noktası falsosunu da ölçekler), `accuracy` rastgele nişan sapmasının affedilen
oranı, `sweet_spot` vuruş noktasının güç ve isabet kaybetmeden kayabileceği alan. Ayrıca `aftertouch` (havada falso
sınırı) ve `wet_penalty` (ıslak sahada isabet kaybı). `noise` sahneden gelir (birim rastgele sapma); testlerde sıfırdır.
`boot` verilmezse `Boot.neutral(cp)` kullanılır (hatasız). Seçim ekranı `scripts/ui/boot_picker.gd`; krampon yalnızca
vuruştan önce değişir.

## Kaleci ve baraj (`scripts/keeper/`)

| Dosya | İçerik |
| --- | --- |
| `keeper_params.gd` | Kaleci ve baraj ayarları; üzerine `data/keeper.json` yazılır |
| `wall.gd` | Baraj: toptan 9,15 m, yakın direği kapatır, vuruşla zıplar; kutu çarpışması |
| `keeper.gd` | Kaleci: tepki süresi, tahmin (falsonun `spin_read` kadarını okur), ellerin hız ve erişim sınırı, tutma/çelme |

`BallSimulator.wall` ve `.keeper` isteğe bağlıdır; `hit_wall`, `hit_keeper` ve `Outcome.SAVED` (kaleci tuttu) sonuçları
verir. Kaleci gövdesi ayaklardan ellere uzanan kapsüldür ve çizginin `depth` kadar önünde durur.

Eksenler: kale çizgisi z = 0, kale ortası x = 0, vuruş +z'den -z'ye, +x vurucunun sağı. Yan falso artı = sağa
kıvrılır; üst falso artı = top dalar. Vector3 tek duyarlıklıdır: testlerde 1e-6'dan sıkı tolerans kullanma.

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
