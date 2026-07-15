class MentorEngine {
	List<String> prioritizeTasks({
		required List<String> tasks,
		required int riskScore,
		String? primaryTrigger,
		String? predictedWindow,
	}) {
		if (tasks.isEmpty) {
			return const [];
		}

		final scored = tasks.map((task) {
			var score = 0;

			final normalizedTask = task.toLowerCase();
			final normalizedTrigger = (primaryTrigger ?? '').toLowerCase();

			if (riskScore >= 75 && normalizedTask.contains('ertele')) {
				score += 3;
			}
			if (riskScore >= 60 && normalizedTask.contains('nefes')) {
				score += 2;
			}
			if (normalizedTrigger.isNotEmpty && normalizedTask.contains(normalizedTrigger)) {
				score += 2;
			}
			if ((predictedWindow ?? '').isNotEmpty && normalizedTask.contains('riskli saat')) {
				score += 1;
			}

			return MapEntry(task, score);
		}).toList();

		scored.sort((a, b) {
			final byScore = b.value.compareTo(a.value);
			if (byScore != 0) {
				return byScore;
			}
			return a.key.compareTo(b.key);
		});

		return scored.map((entry) => entry.key).toList();
	}

	List<String> buildCoachingHints({
		required int riskScore,
		required String? predictedWindow,
		required String? predictedTrigger,
	}) {
		final hints = <String>[];

		if (riskScore >= 80) {
			hints.add('Yuksek risk donemindesiniz: ilk sigarayi mutlaka erteleyin.');
		} else if (riskScore >= 60) {
			hints.add('Orta-yuksek risk: tetikleyici aninda nefes + su rutini uygulayin.');
		} else {
			hints.add('Ritmi koruyun: bugun en az bir gorevi tamamlama hedefi koyun.');
		}

		if ((predictedWindow ?? '').isNotEmpty) {
			hints.add('En riskli pencere: ${predictedWindow!}. Bu saatten once hazirlik yapin.');
		}

		if ((predictedTrigger ?? '').isNotEmpty) {
			hints.add('Tahmini tetikleyici: ${predictedTrigger!}. Alternatif davranis belirleyin.');
		}

		return hints.take(3).toList();
	}

	List<String> buildActionCommands({
		required int riskScore,
		required String breathTrend,
		required String smokingTrend,
		required String consecutiveTrend,
		required int weeklyRiskTarget,
		required List<String> riskyHours,
		required String? predictedWindow,
		required String? predictedTrigger,
	}) {
		final commands = <String>[];

		if (riskScore >= 80) {
			commands.add('KOMUT 1: Ilk sigarayi en az 90 dakika ertele.');
		} else if (riskScore >= 60) {
			commands.add('KOMUT 1: Ilk sigarayi en az 45 dakika ertele.');
		} else {
			commands.add('KOMUT 1: Ilk sigarayi en az 25 dakika ertele.');
		}

		if (breathTrend == 'Declining') {
			commands.add('KOMUT 2: Nefes testini bugun 2 kez yap ve ortalamayi kaydet.');
		} else if (breathTrend == 'Improving') {
			commands.add('KOMUT 2: Nefes kazancini koru, bugun en az 1 nefes rutini uygula.');
		} else {
			commands.add('KOMUT 2: Her kriz aninda 2 dakika nefes + 1 bardak su uygula.');
		}

		if (smokingTrend == 'Increasing' || consecutiveTrend == 'trendDeclining') {
			commands.add('KOMUT 3: Bugun toplam sigara adedini dunun altinda tut.');
		} else {
			commands.add('KOMUT 3: Bugun secilen gorevlerin tamamina tamamlandi isareti ver.');
		}

		if ((predictedWindow ?? '').isNotEmpty) {
			commands.add('HAZIRLIK: ${predictedWindow!} oncesi kriz kiti hazirla.');
		}
		if ((predictedTrigger ?? '').isNotEmpty) {
			commands.add('TETIKLEYICI: ${predictedTrigger!} aninda sigara yerine alternatife gec.');
		}
		if (riskyHours.isNotEmpty) {
			commands.add('ODAK: En riskli saat ${riskyHours.first} icin bildirimleri acik tut.');
		}
		if (weeklyRiskTarget > 0) {
			commands.add('HEDEF: Haftalik risk hedefini $weeklyRiskTarget altina indir.');
		}

		return commands.take(4).toList();
	}
}
