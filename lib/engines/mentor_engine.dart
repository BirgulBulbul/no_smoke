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

	Map<String, dynamic> optimizeActionCommands({
		required List<String> commands,
		required List<dynamic> taskHistory,
		required Map<String, double> previousScores,
	}) {
		if (commands.isEmpty) {
			return {
				'commands': const <String>[],
				'scores': <String, double>{},
				'categoryScores': <String, double>{},
			};
		}

		final globalSuccessRate = _globalSuccessRate(taskHistory);
		final scores = <String, double>{};

		for (final command in commands) {
			final prior = previousScores[command] ?? 0.50;
			final evidence = _commandEvidenceScore(command, taskHistory);

			double nextScore;
			if (evidence == null) {
				nextScore = (prior * 0.85) + (globalSuccessRate * 0.15);
			} else {
				nextScore = (prior * 0.60) + (evidence * 0.40);
			}

			scores[command] = nextScore.clamp(0.05, 0.95);
		}

		final ordered = [...commands]
			..sort((a, b) {
				final byScore = (scores[b] ?? 0).compareTo(scores[a] ?? 0);
				if (byScore != 0) {
					return byScore;
				}
				return a.compareTo(b);
			});
		final categoryScores = _deriveCategoryScores(ordered, scores);

		return {
			'commands': ordered,
			'scores': scores,
			'categoryScores': categoryScores,
		};
	}

	List<String> rebalanceCommandMix({
		required List<String> orderedCommands,
		required Map<String, double> commandScores,
		required Map<String, double> categoryScores,
		int maxCount = 4,
	}) {
		if (orderedCommands.isEmpty) {
			return const <String>[];
		}

		final buckets = <String, List<String>>{};
		for (final command in orderedCommands) {
			final category = _categoryForCommand(command);
			buckets.putIfAbsent(category, () => <String>[]).add(command);
		}

		for (final entry in buckets.entries) {
			entry.value.sort(
				(a, b) => (commandScores[b] ?? 0).compareTo(commandScores[a] ?? 0),
			);
		}

		final sortedCategories = buckets.keys.toList()
			..sort((a, b) {
				final sa = categoryScores[a] ?? 0.5;
				final sb = categoryScores[b] ?? 0.5;
				return sb.compareTo(sa);
			});

		final weakestCategories = [...sortedCategories]
			..sort((a, b) {
				final sa = categoryScores[a] ?? 0.5;
				final sb = categoryScores[b] ?? 0.5;
				return sa.compareTo(sb);
			});

		final maxItems = maxCount < orderedCommands.length
			? maxCount
			: orderedCommands.length;
		final topCategory = sortedCategories.first;
		final weakestCategory = weakestCategories.first;
		final selected = <String>[];

		int pullFromCategory(String category, int count) {
			var added = 0;
			final list = buckets[category] ?? const <String>[];
			for (final command in list) {
				if (selected.contains(command)) {
					continue;
				}
				selected.add(command);
				added += 1;
				if (added >= count || selected.length >= maxItems) {
					break;
				}
			}
			return added;
		}

		final topQuota = maxItems >= 4 ? 2 : 1;
		pullFromCategory(topCategory, topQuota);

		if (weakestCategory != topCategory && selected.length < maxItems) {
			pullFromCategory(weakestCategory, 1);
		}

		while (selected.length < maxItems) {
			var progressed = false;
			for (final category in sortedCategories) {
				final added = pullFromCategory(category, 1);
				if (added > 0) {
					progressed = true;
				}
				if (selected.length >= maxItems) {
					break;
				}
			}
			if (!progressed) {
				break;
			}
		}

		if (selected.length < maxItems) {
			for (final command in orderedCommands) {
				if (selected.contains(command)) {
					continue;
				}
				selected.add(command);
				if (selected.length >= maxItems) {
					break;
				}
			}
		}

		return selected;
	}

	Map<String, double> _deriveCategoryScores(
		List<String> orderedCommands,
		Map<String, double> commandScores,
	) {
		final grouped = <String, List<double>>{};
		for (final command in orderedCommands) {
			final category = _categoryForCommand(command);
			grouped.putIfAbsent(category, () => <double>[]).add(
				commandScores[command] ?? 0.5,
			);
		}

		final result = <String, double>{};
		for (final entry in grouped.entries) {
			final average = entry.value.reduce((a, b) => a + b) / entry.value.length;
			result[entry.key] = average;
		}
		return result;
	}

	String _categoryForCommand(String command) {
		final value = _normalize(command);
		if (value.contains('nefes')) {
			return 'breath';
		}
		if (value.contains('ertele')) {
			return 'delay';
		}
		if (value.contains('tetikleyici') ||
			value.contains('riskli saat') ||
			value.contains('kriz')) {
			return 'trigger';
		}
		if (value.contains('sigara adedini') ||
			value.contains('haftalik risk hedefi') ||
			value.contains('hedef')) {
			return 'reduction';
		}
		return 'routine';
	}

	double _globalSuccessRate(List<dynamic> taskHistory) {
		if (taskHistory.isEmpty) {
			return 0.50;
		}

		var success = 0;
		for (final item in taskHistory) {
			final completed = item.completed == true;
			if (completed) {
				success += 1;
			}
		}
		return success / taskHistory.length;
	}

	double? _commandEvidenceScore(String command, List<dynamic> taskHistory) {
		if (taskHistory.isEmpty) {
			return null;
		}

		final commandTokens = _tokens(command);
		if (commandTokens.isEmpty) {
			return null;
		}

		double weightedSuccess = 0;
		double totalWeight = 0;
		for (var i = 0; i < taskHistory.length; i++) {
			final item = taskHistory[i];
			final title = item.taskTitle?.toString() ?? '';
			final overlap = _overlapScore(commandTokens, _tokens(title));
			if (overlap <= 0) {
				continue;
			}

			final recencyWeight = 0.6 + (0.4 * ((i + 1) / taskHistory.length));
			final weight = overlap * recencyWeight;
			totalWeight += weight;
			if (item.completed == true) {
				weightedSuccess += weight;
			}
		}

		if (totalWeight <= 0) {
			return null;
		}

		return weightedSuccess / totalWeight;
	}

	Set<String> _tokens(String text) {
		final normalized = _normalize(text);
		final parts = normalized
			.split(RegExp(r'[^a-z0-9]+'))
			.where((part) => part.length >= 3)
			.toSet();
		return parts;
	}

	double _overlapScore(Set<String> a, Set<String> b) {
		if (a.isEmpty || b.isEmpty) {
			return 0;
		}

		final intersection = a.where(b.contains).length;
		if (intersection == 0) {
			return 0;
		}

		final union = {...a, ...b}.length;
		return intersection / union;
	}

	String _normalize(String value) {
		return value
			.toLowerCase()
			.replaceAll('ı', 'i')
			.replaceAll('ğ', 'g')
			.replaceAll('ş', 's')
			.replaceAll('ö', 'o')
			.replaceAll('ü', 'u')
			.replaceAll('ç', 'c');
	}
}
