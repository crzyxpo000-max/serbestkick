# Yayın (Aşama 10)

Kod tarafı hazır; aşağıdaki adımlar hesap ve imza gerektirdiği için senin yapman gerekiyor.
Play Store koşulları değişebilir: başlamadan önce Play Console'daki güncel hesap ve test koşullarına bak.

## Hazır olanlar

- Uygulama simgesi (`icon.svg`), sürüm `1.0.0` (`project.godot`), paket adı `com.serbestkick.game` (`export_presets.cfg`).
- Her `main` gönderiminde debug APK: Actions → son "Derleme" çalışması → `serbestkick-debug-apk`.
- İmzalı release APK: depoya aşağıdaki gizli değerler eklenirse aynı iş akışı `serbestkick-release-apk` çıktısını da üretir.
  **Bu yol gizli değerler olmadan denenemedi; ilk çalıştırmada hata verebilir.**
- Oyun veri toplamaz, ağ kullanmaz; kayıtlar yalnızca cihazda durur (`user://career.json`, `user://settings.json`).

## Senin yapacakların

1. **Karar ver:** oyunun adı ve paket adı (yayınlandıktan sonra paket adı değişmez), ücretli/ücretsiz, dil.
   Ad değişirse `project.godot` içindeki `config/name` ile `export_presets.cfg` içindeki `package/name` ve
   `package/unique_name` güncellenir.
2. **İmza anahtarı oluştur** (bir kez; dosyayı ve şifreyi kaybetme, yedekle):
   ```bash
   keytool -genkeypair -v -keystore serbestkick-release.keystore -alias serbestkick \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
3. **Depoya gizli değerleri ekle** (GitHub → Settings → Secrets and variables → Actions):
   - `RELEASE_KEYSTORE_BASE64`: `base64 -w0 serbestkick-release.keystore` çıktısı
   - `RELEASE_KEYSTORE_USER`: anahtar adı (yukarıda `serbestkick`)
   - `RELEASE_KEYSTORE_PASSWORD`: şifre
4. **Farklı telefonlarda dene:** en az bir orta seviye Android telefonda akıcılık, dokunma hissi, ses ve titreşim.
5. **Play Console:** geliştirici hesabı, uygulama kaydı, mağaza metni, ekran görüntüleri, içerik derecelendirmesi,
   veri güvenliği formu (veri toplanmıyor), gizlilik politikası bağlantısı.
6. **AAB:** Play Store APK yerine AAB ister. AAB için Godot'da Gradle derlemesi gerekir; bilgisayarda Godot
   editöründe Project → Install Android Build Template, ardından Export → Android → "Use Gradle Build" açık,
   "Export Format: AAB". Bu adım bulutta kurulmadı.

## Yayından önce bakılacak açık işler

- Gerçek telefonda performans ölçümü yapılmadı (planın riski: "gerçekçi görsel telefonda takılabilir").
- Oyuncular ilkel şekillerden kurulu figürlerdir; gerçekçi insan modeli ve animasyon (Mixamo) eklenmedi.
- Sesler sentezdir; gerçek tribün ve vuruş kayıtlarıyla değiştirilebilir (`assets/audio/`, aynı dosya adları).
