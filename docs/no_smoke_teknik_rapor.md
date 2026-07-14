# NO SMOKE Teknik Sistem Raporu (A-Z)

Tarih: 2026-07-14
Proje: no_smoke
Amaç: Uygulamanın çalışma sistemi, algoritmaları, sensör yapısı, profil gelişimi ve risk skorlamasını uçtan uca teknik olarak açıklamak.

## 1. Yönetici Özeti

Bu uygulama, sigara bırakma sürecini üç ana veri hattı ile yönetir:

1. Kullanıcı beyanı: ilk/haftalık anketler
2. Nefes testi: iki aşamalı süre ölçümü
3. Davranış telemetrisi: görev sonuçları + sensör/telefon kullanım olayları

Sistem bu verileri SQLite üzerinde toplar, BehaviorEngine ile dinamik riske çevirir, Home ekranında günlük görev ve risk öngörüleri üretir, NotificationService ile kullanıcı etkileşimini sürdürülebilir hale getirir.

## 2. Uygulama Mimari Özeti

- Giriş ve locale: main.dart + LanguageService
- Onboarding yönlendirme: SplashPage, LanguageSelectionPage
- Veri toplama: SurveyPage, WeeklySurveyPage, BreathTestPage
- Risk çıktısı: RiskResultPage
- Operasyon merkezi: HomePage
- Kalıcılık ve hesaplama: StorageService + BehaviorEngine
- Bildirim ve aksiyon döngüsü: NotificationService

## 3. Çalışma Akışı (Uçtan Uca)

### 3.1 İlk Açılış

1. Uygulama başlarken bildirim servisi initialize edilir.
2. Kaydedilen dil okunur ve uygulama locale'i buna set edilir.
3. SplashPage:
- Dil seçimi yoksa LanguageSelectionPage
- Initial kayıt yoksa SurveyPage
- Initial kayıt varsa doğrudan BreathTestPage

### 3.2 İlk Profil Oluşturma

1. SurveyPage zorunlu alanları doğrular.
2. Initial SurveyRecord kaydedilir.
3. survey_details tablosuna bağlamsal alanlar kaydedilir (tetikleyici, sağlık, uyku vb.).
4. UserProfileSnapshot oluşturulur.
5. Günlük nefes hatırlatma planlanır.
6. Kullanıcı BreathTestPage'e gider.

### 3.3 Nefes Testi ve Risk Çıkışı

Nefes testi 2 aşamadır:
- Test 1: nefes verme dayanımı
- Test 2: nefes tutma dayanımı

Ortalama süreye göre base risk hesaplanır:
- ortalama <= 4 sn: 85 (Kritik)
- ortalama <= 7 sn: 65 (Yüksek)
- ortalama <= 10 sn: 40 (Orta)
- aksi: 15 (Düşük)

Sonrasında StorageService.calculateAdjustedRiskScore ile ayarlı risk üretilir.

### 3.4 Home Döngüsü

HomePage her yüklemede:
1. Son anket/nefes metriklerini okur.
2. loadBehaviorDashboard ile adaptif risk ve görevleri alır.
3. Bekleyen görev takiplerini restore eder.
4. Yeni görevler için push tetikler.
5. Kullanıcı bildirim aksiyonlarını dinleyerek task_result + follow-up akışını yönetir.

## 4. Veri Modeli ve Depolama

Veritabanı dosyası: no_smoke.db (uygulama belgeler dizininde)

Ana tablolar:
- app_events: survey, breath_test, task_result dahil olay tablosu
- survey_details: trigger/health/profession/sleep gibi detaylar
- user_profile_snapshots: profillerin zamansal snapshot'ı
- sensor_usage_events: sensör + kullanım telemetrisi
- behavior_snapshots: hesaplanmış dashboard snapshot'ı
- task_followups: ertelenen/izlenen görevler
- app_settings: genel anahtar-değer bayrakları

## 5. Algoritmalar

### 5.1 Base Risk (Nefes Testi)

Base risk yalnızca nefes testi ortalamasından gelir.

Tanım:
- avg = round((test1 + test2) / 2)

Eşik fonksiyonu:
- avg <= 4 => 85
- 5-7 => 65
- 8-10 => 40
- >10 => 15

### 5.2 Ayarlı Risk (StorageService.calculateAdjustedRiskScore)

Formül bileşenleri:

1. Geçmiş nefes farkı etkisi
- fark = currentAvg - previousAvg
- skor += fark * 2

2. Paket katkısı
- BehaviorEngine.calculatePackRiskContribution(packsPerDay)
- aralık: 5..40

3. Arka arkaya içme katkısı
- BehaviorEngine.calculateConsecutiveSmokingScore(habit,count)
- aralık: 0..20

4. Clamp
- skor = clamp(0,100)

### 5.3 Dinamik Risk (StorageService.loadBehaviorDashboard)

Dinamik risk üç katmandan oluşur:

1. trend tabanlı skor
- smokingTrend (Increasing/Decreasing)
- breathTrend (Improving/Declining)
- consecutiveTrend
- riskyTriggers sayısı
- riskyHours sayısı

2. profil ayarı
- meslek grubu
- kısa uyku penceresi
- sağlık koşulu sayısı
- paket seviyesi
- chain smoking şiddeti
- nefes testi yoksa ek ceza

3. görev sonuç ayarı
- son 5 görevde:
  - success: -2
  - failed: +3
- toplam clamp: -6..12

Toplam:
- dynamicRisk = clamp(0,100, trendScore + profileAdjustment + taskOutcomeAdjustment)

### 5.4 Tetikleyici ve Riskli Saat Analizi

Tetikleyici skorları:
- başlangıç: her tetikleyici 10
- her survey kaydında seçiliyse +5, seçili değilse -1
- max skora sahip tetikleyiciler riskyTriggers

Riskli saatler (2 saatlik bucket):
- survey zamanları ağırlık 3
- appUsage/screenUnlock yoğun olaylar ağırlık 2
- task başarısızlık zamanı ağırlık 4
- breath test zamanı ağırlık 1
- en yüksek 3 bucket seçilir

### 5.5 Görev Üretimi

İlk profil özel kuralı:
- yüksek riskte tek kolay görev (15 dk geciktirme)

Normal durumda:
- risk skoru ile zorluk seçimi:
  - >=70 easy
  - >=40 medium
  - <40 hard
- başarı oranına göre ağırlıklı rastgele seçim
- varsayılan günlük üretim: 3 görev

## 6. Sensörler ve Telefon Durumu

### 6.1 Mevcut Sensör Veri Şeması

sensor_usage_events tablosunda şu alanlar tutuluyor:
- activityState
- accelerometerMagnitude
- gyroscopeMagnitude
- screenUnlockCount
- appUsageMinutes
- idleMinutes
- charging
- createdAt

### 6.2 SensorService Çalışma Mantığı

SensorService.logSensorSample:
1. Son kayıt zamanı kontrolü (min 20 dakika)
2. Son örnekle anlamlı fark kontrolü
3. Anlamlı fark varsa kayıt

Anlamlı fark eşikleri:
- activityState değişimi
- charging değişimi
- accel/gyro delta >= 0.35
- unlock delta >= 5
- appUsage delta >= 10

### 6.3 PhoneStateService Çıkarımı

inferDailyStateSummary:
- activeHours: appUsage>=10 veya unlock>=8
- passiveHours: kalanlar
- drivingPrediction:
  - event.activityState == driving
  - veya accel>1.1 + gyro>0.8 + unlock<=2
  - oy oranı >= %20 ise driving

### 6.4 Bildirimlerde Sensör Etkisi

NotificationService, breath ve follow-up bildirim zamanını sürüş olasılığına göre +20 dk erteleyebiliyor.

## 7. Profil Gelişimi (Profile Evolution)

Profil gelişimi zaman içinde şu kaynaklarla ilerler:

1. Initial survey snapshot
2. Weekly survey snapshot'ları
3. Breath test snapshot'ları
4. Task result geçmişi
5. Sensör/kullanım olayları

Bu akış sayesinde kullanıcı tek seferlik değil, sürekli güncellenen bir davranış profiline taşınır.

## 8. A-Z Kontrol Sonucu (Teknik Bulgular)

1. Risk hesaplama katmanı iki parçalıdır:
- Nefes bazlı anlık risk
- Davranış bazlı dinamik risk

2. Sensör altyapısı model olarak hazırdır ancak doğrudan donanım sensör okuma entegrasyonu (örn. sensors_plus stream'i) bu depoda görünmemektedir.

3. location_service.dart, subscription_service.dart, engines/behavior_engine.dart, engines/prediction_engine.dart dosyaları boştur. Aktif iş mantığı services/behavior_engine.dart içindedir.

4. RiskEngine (engines/risk_engine.dart) kapsamlı bir formül içeriyor, fakat aktif akışta ana risk hesapları StorageService + services/behavior_engine.dart tarafında yürütülüyor.

5. Görev sonucu risk etkisi canlıdır (başarı azaltır, başarısızlık artırır).

## 9. Önerilen Yol Haritası

1. Gerçek sensör toplama pipeline'ı ekle
- accelerometer/gyroscope stream
- foreground/background güvenli örnekleme

2. Telefon kullanım metriklerini işletim sistemi izin modeli ile netleştir
- appUsage/screen unlock kaynak doğrulaması

3. engines klasöründeki boş dosyaları kaldır ya da yönlendir
- tek kaynaklı mimari netliği

4. Risk modeline explainability log ekle
- skorun hangi bileşenden ne kadar etkilendiğini kullanıcı/analitik katmanında sakla

## 10. Sonuç

Sistem, davranış değişikliği odaklı adaptif bir motor olarak çalışıyor: anket + nefes + görev + telemetri birleşimiyle dinamik risk üretip kişiselleştirilmiş görev planı oluşturuyor. Mevcut sürümde sensör modeli güçlü, ancak donanım seviyesinde canlı sensör toplama entegrasyonu tamamlandığında doğruluk ve öngörü kalitesi daha da artacaktır.
