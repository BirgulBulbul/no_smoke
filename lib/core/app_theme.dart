import 'package:flutter/material.dart';

class AppTheme {
	static const Color noSmokeGreen = Color(0xFF00C853);
	static const Color noSmokeNavy = Color(0xFF0D1B2A);

	static ThemeData get darkTheme {
		final colorScheme = ColorScheme.fromSeed(
			seedColor: noSmokeGreen,
			brightness: Brightness.dark,
			primary: noSmokeGreen,
			secondary: noSmokeGreen,
			surface: const Color(0xFF132238),
		);

		return ThemeData(
			useMaterial3: true,
			brightness: Brightness.dark,
			colorScheme: colorScheme,
			scaffoldBackgroundColor: noSmokeNavy,
			appBarTheme: const AppBarTheme(
				backgroundColor: noSmokeNavy,
				foregroundColor: Colors.white,
				centerTitle: false,
			),
			cardTheme: CardThemeData(
				color: const Color(0xFF132238),
				elevation: 0,
				shape: RoundedRectangleBorder(
					borderRadius: BorderRadius.circular(20),
				),
			),
			elevatedButtonTheme: ElevatedButtonThemeData(
				style: ElevatedButton.styleFrom(
					backgroundColor: noSmokeGreen,
					foregroundColor: Colors.black,
					shape: RoundedRectangleBorder(
						borderRadius: BorderRadius.circular(16),
					),
				),
			),
			outlinedButtonTheme: OutlinedButtonThemeData(
				style: OutlinedButton.styleFrom(
					foregroundColor: Colors.white,
					side: const BorderSide(color: noSmokeGreen),
					shape: RoundedRectangleBorder(
						borderRadius: BorderRadius.circular(16),
					),
				),
			),
			inputDecorationTheme: InputDecorationTheme(
				filled: true,
				fillColor: const Color(0xFF132238),
				border: OutlineInputBorder(
					borderRadius: BorderRadius.circular(16),
					borderSide: BorderSide.none,
				),
			),
		);
	}
}
