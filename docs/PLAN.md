# Serbest Vuruş Oyunu: Proje Planı

Kaynak belge: "Serbest Vuruş Oyunu: Proje Planı" (2026-11-15). Bu dosya onun depo içi kopyasıdır.

## Özet

Android için 3D, gerçekçi görünümlü bir serbest vuruş oyunu. Oyuncu takımın yıldız duran top uzmanıdır: maç
otomatik akar, kritik bir serbest vuruş çıkınca oyuna alınır ve tek bir şut hakkı vardır. Oyunun değeri şut
hissindedir. Fizik gerçek top davranışına dayanır, kontrol tek parmak kaydırmasıdır, kariyer ve krampon sistemi
vuruşlara anlam katar.

## Verilen kararlar

| Konu | Karar |
| --- | --- |
| Platform | Android |
| Motor | Godot 4 |
| Görünüm | 3D, gerçekçi |
| Oynanış kapsamı | Sadece şut. Orta ve penaltı yok |
| Kontrol | Kaydırarak şut |
| Havada falso | Var, ama sınırlı |
| Krampon | Fiziği etkileyen özellikleri olan kramponlar |
| Senaryo | Yıldız duran top uzmanı, kritik anda oyuna alınır |
| Maçın geri kalanı | Tamamen otomatik akar |
| Geliştirme | Önce bulut Claude Code, birkaç gün sonra bilgisayar |

## Oynanış

Şut tek bir kaydırma hareketidir: parmağın hızı gücü, yönü nişanı, çizdiği yayın eğriliği falsoyu belirler.

**Vuruş öncesi**

- Kamera topun arkasındadır; kale, baraj ve kaleci görünür.
- Topun üzerinde vuruş noktası seçilir: alt kısım topu yükseltir, yanlar kıvırır, tam orta sert ve dönüşsüz vuruş (knuckleball) verir.
- Seçili kramponun özellikleri ekranda görünür.

**Vuruş**

- Kaydırma ne kadar hızlıysa şut o kadar sert olur, üst sınırı krampon belirler.
- Kaydırmadaki küçük sapmalar isabete yansır. Kramponun isabet değeri bu hatayı ne kadar affettiğini belirler.

**Havada falso (sınırlı)**

- Yalnızca uçuşun ilk yarısında çalışır.
- Topun mevcut dönüşünü en fazla yüzde 20 civarında artırır ya da azaltır, yönünü tersine çeviremez.
- Kötü bir vuruşu kurtarmaz, iyi bir vuruşu inceltir.
- Ayarlardan kapatılabilir (simülasyon modu).

**Baskı**

Kritik anlarda (son dakikalar, gerideyken, derbi) kalp atışı duyulur, nişan hafif titrer ve kaydırma toleransı daralır.

## Fizik modeli

Topun uçuşu hazır fizik motoruna bırakılmaz, her karede kendi formüllerimizle hesaplanır.

**Topa etki eden kuvvetler**

- Yerçekimi: 9,81 m/s²
- Hava direnci: hızın karesiyle artar, topu yavaşlatır
- Magnus kuvveti: dönen topu yana ya da aşağı yukarı büker, falsonun kaynağı budur
- Dönüş kaybı: top uçtukça dönüşü yavaşça azalır
- Rüzgar: hava koşuluna göre sabit bir itme

**Gerçek değerler**

| Ölçü | Değer |
| --- | --- |
| Top kütlesi | 0,43 kg |
| Top yarıçapı | 0,11 m |
| Şut hızı | 20 ile 35 m/s arası |
| Dönüş | saniyede 10 tura kadar |
| Kale | 7,32 m x 2,44 m |
| Baraj mesafesi | 9,15 m |
| Vuruş mesafesi | 18 ile 35 m arası |

**Çarpışmalar**

- Zemin: seker, her sekmede hız kaybeder, ıslak sahada kayar.
- Direk ve üst direk: geliş açısına göre içeri ya da dışarı döner.
- Baraj ve kaleci: vücut parçalarına çarpan top yön değiştirir.
- File: topu yutar ve esner.

**Doğrulama**

Fizik kodu otomatik testlerle kontrol edilir. Örnek: 25 metreden, 28 m/s hızla ve belirli bir falsoyla vurulan
topun kale çizgisini hangi noktadan geçtiği hesaplanır ve beklenen aralıkla karşılaştırılır.

## Krampon sistemi

Her kramponun dört özelliği vardır ve hepsi doğrudan fizik hesabına girer.

| Özellik | Etkisi |
| --- | --- |
| Güç | Topun en yüksek çıkış hızı |
| Falso | Topa verilebilen en yüksek dönüş |
| İsabet | Kaydırma hatalarının ne kadarının affedildiği |
| Tatlı nokta | Temiz vuruş alanının genişliği |

| Tip | Güçlü yanı | Zayıf yanı | En iyi kullanım |
| --- | --- | --- | --- |
| Güç | Sert şut | Düşük isabet | Uzak mesafe |
| Kontrol | Yüksek isabet, geniş tatlı nokta | Düşük hız | Yakın ve dar açı |
| Falso | Çok kıvırır | Düşük güç | Barajın üstünden ya da yanından |
| Dengeli | Her şeyi orta | Hiçbir şeyde en iyi değil | Başlangıç kramponu |

- Kramponlar kariyer primleriyle açılır.
- Her maçtan önce bir krampon seçilir, pozisyon çıkınca değiştirilemez.
- Islak sahada bazı kramponların isabeti düşer.
- Sınırlı aftertouch'ın gücü de krampona bağlı küçük bir özelliktir.

## Senaryo ve maç akışı

Oyuncu yedek kulübesinde bekleyen duran top uzmanıdır ve her maçta yalnızca serbest vuruş anında sahaya girer.

1. Maç hızlandırılmış akar: skor tabelası, dakika ve kısa spiker yazıları.
2. Faul olur: düdük çalar, hakem köpüğü sıkar, kamera kulübeye döner.
3. Teknik direktör oyuncuyu çağırır, kısa bir oyuna giriş sahnesi oynar.
4. Oyuncu topun başına geçer ve şutunu çeker. Tekrar hakkı yoktur.
5. Gol ya da kaçan vuruşun ağır çekim tekrarı gösterilir.
6. Maç yeniden hızlı akar ve sonuç açıklanır.

**Her pozisyonu farklı kılan değişkenler:** mesafe ve açı; barajdaki oyuncu sayısı ve dizilişi; kalecinin tarzı
(çizgide bekleyen ya da öne çıkan); hava (açık, rüzgarlı, yağmurlu); skor ve dakika, yani baskı seviyesi; maçın
önemi (lig maçı, derbi, kupa finali). Bazı maçlarda iki pozisyon çıkabilir, bazılarında hiç çıkmayabilir.

## Kariyer

- **Hoca güveni:** gol attıkça daha fazla ve daha kritik pozisyonda oyuna alınırsın. Kaçırdıkça yalnızca kolay vuruşlarda şans verilir.
- **Sezon:** lig ve kupa maçlarından oluşur. Senin gollerin maç sonucunu ve takımın puan durumunu değiştirir.
- **Ün:** küçük bir takımda başlarsın. İyi sezonlardan sonra daha büyük kulüplerden teklif gelir.
- **Gelişim:** maç primleriyle krampon alınır ve oyuncu özellikleri yükseltilir: güç, falso, isabet, soğukkanlılık. Soğukkanlılık baskı anındaki titremeyi azaltır.

**Ek modlar:** serbest antrenman (mesafe ve barajı kendin ayarlarsın, kariyeri etkilemez); günlük meydan okuma
(her gün herkese aynı pozisyon; ilk sürüme girmeyebilir).

## Görsel ve ses

Gerçekçi görünüm hazır 3D malzemeyle sağlanır.

| Parça | Ne gerekiyor | Kaynak |
| --- | --- | --- |
| Işık ve gökyüzü | Stadyum ya da gökyüzü HDRI dosyası | Poly Haven |
| Çim | Yüksek çözünürlüklü doku, biçme çizgileri | Poly Haven |
| Top | Dokulu model, dönüşü görünen desen | Sketchfab ve benzeri |
| Oyuncular | İnsan modeli, forma | Mixamo |
| Animasyonlar | Şut koşusu, kaleci atışları, baraj zıplaması | Mixamo |
| Kale ve file | Model, esneyen ağ | Kendimiz kurarız |
| Stadyum | Uzaktan görünen tribün | Sketchfab ve benzeri |

- **Kamera:** vuruş öncesi topun arkasında, alçak açı; şutta topu takip eden yayın kamerası; golde farklı açılardan ağır çekim tekrar.
- **Ses ve titreşim:** tribün uğultusu (baskı anında yükselir); topa vuruş, direk, file sesleri; kalp atışı, düdük, gol tezahüratı; vuruşta ve golde telefon titreşimi.
- **Performans sınırı:** sahnede yalnızca vurucu, kaleci ve baraj bulunur. Detay topa, çime ve kaleye harcanır, tribün basit tutulur. Hedef orta seviye bir Android telefonda akıcı çalışmasıdır.

## Aşamalar

Sıra önemlidir: önce şut hissi, sonra oyun, en son görünüm.

| Aşama | Yapılacaklar | Bitiş ölçütü | Nerede |
| --- | --- | --- | --- |
| 0. Kurulum | GitHub deposu, Godot proje iskeleti, otomatik derleme | Boş sahne telefonda linkten açılıyor | Bulut |
| 1. Top fiziği | Uçuş formülleri, sekme, direk, otomatik testler | Testler geçiyor, top gerçekçi yay çiziyor | Bulut |
| 2. Kontrol | Kaydırarak şut, vuruş noktası, sınırlı aftertouch | Gri kutulu sahada istediğin köşeye bilerek vurabiliyorsun | Bulut, sonra bilgisayar |
| 3. His ayarı | Güç, falso ve tolerans değerlerinin ince ayarı | Şut çekmek tek başına keyifli | Bilgisayar |
| 4. Kaleci ve baraj | Kaleci tepkisi ve atışları, baraj zıplaması | Kolay vuruşlar kurtarılıyor, iyi vuruşlar gol oluyor | Bilgisayar |
| 5. Krampon | Dört özellik, dört tip, seçim ekranı | Krampon değiştirince şut fark edilir biçimde değişiyor | Bilgisayar |
| 6. Maç senaryosu | Hızlı akan maç, oyuna alınma, baskı, sonuç | Baştan sona bir maç oynanabiliyor | Bilgisayar |
| 7. Kariyer | Hoca güveni, sezon, ün, gelişim, kayıt | Bir sezon baştan sona oynanıp kaydediliyor | Bilgisayar |
| 8. Görsel | Modeller, ışık, animasyon, kamera, tekrar | Oyun gerçekçi görünüyor ve telefonda akıcı | Bilgisayar |
| 9. Ses ve cila | Sesler, titreşim, menüler, ayarlar | Eksik ekran ya da sessiz an kalmıyor | Bilgisayar |
| 10. Yayın | Farklı telefonlarda test, APK, Play Store | Oyun mağazada | Bilgisayar |

İlk oynanabilir sürüm 6. aşamanın sonudur: tek maç, tek krampon seti, gri kutulu görünüm.

## Riskler

| Risk | Önlem |
| --- | --- |
| Şut hissi oturmazsa oyunun geri kalanı anlamsız kalır | 3. aşama bitmeden başka işe geçilmez |
| Kapsam büyük: kariyer, krampon, gerçekçi görsel bir arada | Önce 6. aşamadaki sade sürüm bitirilir |
| Gerçekçi görsel telefonda takılabilir | Sahne küçük tutulur, erken aşamada gerçek telefonda ölçülür |
| Hazır modellerin lisansı ticari kullanıma izin vermeyebilir | Her dosyanın lisansı indirilmeden önce kontrol edilir |
| Gerçek kulüp, lig ve oyuncu adları lisans gerektirir | Uydurma takım ve lig adları kullanılır |
| Bulutta oyunu görmeden geliştirmek yavaştır | Bu dönemde yalnızca testle doğrulanabilen kod yazılır |
| Play Store yayın koşulları değişebilir | 10. aşamadan önce güncel hesap ve test koşullarına bakılır |

## Henüz karar verilmeyenler

- Oyunun adı
- Oyun dili: yalnızca Türkçe mi, İngilizce de olacak mı
- Ücretli mi, ücretsiz mi, reklam ya da uygulama içi satın alma olacak mı
- Takım ve lig yapısı: kaç takım, kaç kademe
- Günlük meydan okuma ilk sürüme girecek mi
