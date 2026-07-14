
import '../models/risk_profile.dart';
import '../models/user_profile.dart';

class RiskEngine {
  static RiskProfile calculate(UserProfile profile) {
    int score = 0;

    // Yaş
    if (profile.age <= 25) {
      score += 10;
    } else if (profile.age <= 35) {
      score += 8;
    } else if (profile.age <= 45) {
      score += 6;
    } else if (profile.age <= 60) {
      score += 4;
    } else {
      score += 2;
    }

    // Günlük paket seviyesi
    score += _packRiskScore(profile.packsPerDay);

    // İlk sigara süresi
    if (profile.firstCigaretteMinutes <= 5) {
      score += 25;
    } else if (profile.firstCigaretteMinutes <= 30) {
      score += 18;
    } else if (profile.firstCigaretteMinutes <= 60) {
      score += 10;
    } else {
      score += 5;
    }

    // En fazla dayanabildiği süre
    if (profile.smokeFreeMinutes <= 15) {
      score += 15;
    } else if (profile.smokeFreeMinutes <= 30) {
      score += 10;
    } else if (profile.smokeFreeMinutes <= 60) {
      score += 6;
    } else {
      score += 2;
    }

    // Sigara geçmişi
    if (profile.smokingYears <= 2) {
      score += 3;
    } else if (profile.smokingYears <= 5) {
      score += 6;
    } else if (profile.smokingYears <= 10) {
      score += 10;
    } else {
      score += 15;
    }

    // Bırakma denemeleri
    if (profile.quitAttempts == 0) {
      score += 10;
    } else if (profile.quitAttempts == 1) {
      score += 8;
    } else if (profile.quitAttempts <= 4) {
      score += 5;
    } else {
      score += 2;
    }

    // Stres
    switch (profile.stressLevel) {
      case "Yüksek":
        score += 10;
        break;
      case "Orta":
        score += 5;
        break;
      default:
        score += 2;
    }

    // Tetikleyiciler
    score += profile.triggers.length;

    // Sağlık durumları
    if (profile.hypertension) score += 3;
    if (profile.asthma) score += 5;
    if (profile.diabetes) score += 4;
    if (profile.copd) score += 8;
    if (profile.heartDisease) score += 10;

    if (score > 100) {
      score = 100;
    }

    String level;
    String description;

    if (score >= 80) {
      level = "KRİTİK";
      description =
          "Yüksek bağımlılık ve yüksek risk tespit edildi.";
    } else if (score >= 60) {
      level = "YÜKSEK";
      description =
          "Bağımlılık seviyesi yüksek görünüyor.";
    } else if (score >= 40) {
      level = "ORTA";
      description =
          "Kontrol edilebilir ancak dikkat gerektiriyor.";
    } else {
      level = "DÜŞÜK";
      description =
          "Düşük risk seviyesi tespit edildi.";
    }

    return RiskProfile(
      score: score,
      level: level,
      description: description,
    );
  }

  static int _packRiskScore(String packsPerDay) {
    switch (packsPerDay) {
      case '1 paketten az':
        return 5;
      case '1 paket':
        return 10;
      case '2 paket':
        return 20;
      case '3 paket':
        return 30;
      case '3+ paket':
      case '4 paket':
      case '5 paket':
      case '6 paket':
      case '7+ paket':
        return 40;
      default:
        return 5;
    }
  }
}
