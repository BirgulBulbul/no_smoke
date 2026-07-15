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
}
