library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

final class IdeaImage extends StatelessWidget {
  const IdeaImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.iconSize = 28,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url);
    final valid =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    return SizedBox(
      width: width,
      height: height,
      child: !valid
          ? _fallback(context)
          : Image.network(
              url,
              fit: fit,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stack) =>
                      _fallback(context),
              loadingBuilder:
                  (
                    BuildContext context,
                    Widget child,
                    ImageChunkEvent? progress,
                  ) => progress == null ? child : _fallback(context),
            ),
    );
  }

  Widget _fallback(BuildContext context) => Container(
    color: context.appColors.bgSubtle,
    alignment: Alignment.center,
    child: Icon(
      LucideIcons.image,
      size: iconSize,
      color: context.appColors.textDisabled,
    ),
  );
}
