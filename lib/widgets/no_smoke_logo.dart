import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_theme.dart';

class NoSmokeLogo extends StatelessWidget {
  final double size;
  final bool showLabel;

  const NoSmokeLogo({
    super.key,
    this.size = 96,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final logoSize = size.clamp(48, 240).toDouble();
    final borderRadius = BorderRadius.circular(logoSize * 0.22);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: logoSize,
          height: logoSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: borderRadius,
              border: Border.all(
                color: AppTheme.noSmokeGreen,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: SvgPicture.asset(
                'assets/images/no_smoke_logo.svg',
                fit: BoxFit.contain,
                placeholderBuilder: (_) => _buildPlaceholder(logoSize),
              ),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 10),
          Text(
            'NO SMOKE',
            style: TextStyle(
              fontSize: (logoSize * 0.17).clamp(14, 28).toDouble(),
              fontWeight: FontWeight.w800,
              letterSpacing: 2.2,
              color: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlaceholder(double logoSize) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Icon(
          Icons.smoke_free,
          size: logoSize * 0.52,
          color: AppTheme.noSmokeGreen,
        ),
      ),
    );
  }
}