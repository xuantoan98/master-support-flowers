import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/catalog_placeholders.dart';
import 'flower_template_theme.dart';

class CatalogProductImage extends StatelessWidget {
  const CatalogProductImage({super.key, required this.path, this.size = 56});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageSize = size - 8;
    // Decode at the size drawn: catalog images are symbolic thumbnails, so
    // 1× is enough even when `cover` slightly upscales a landscape photo.
    final pixels = (imageSize * MediaQuery.devicePixelRatioOf(context)).ceil();
    Widget fallback() => Image.asset(
      catalogPlaceholders.first,
      width: imageSize,
      height: imageSize,
      fit: BoxFit.cover,
      cacheWidth: pixels,
    );

    final image = path.startsWith('assets/')
        ? Image.asset(
            path,
            width: imageSize,
            height: imageSize,
            fit: BoxFit.cover,
            cacheWidth: pixels,
            errorBuilder: (_, _, _) => fallback(),
          )
        : path.isNotEmpty
        ? Image.file(
            File(path),
            width: imageSize,
            height: imageSize,
            fit: BoxFit.cover,
            cacheWidth: pixels,
            errorBuilder: (_, _, _) => fallback(),
          )
        : fallback();
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.blush,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(11), child: image),
    );
  }
}
