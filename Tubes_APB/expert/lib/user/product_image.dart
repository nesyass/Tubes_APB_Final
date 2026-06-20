import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/product_images.dart';

class ProductImage extends StatelessWidget {
  final ServiceModel service;
  final double? height;
  final double borderRadius;
  final BoxFit fit;

  const ProductImage({
    super.key,
    required this.service,
    this.height,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final url = productImageUrlFor(service);
    final dpr = MediaQuery.of(context).devicePixelRatio;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 320.0;
        final resolvedHeight = height ??
            (constraints.hasBoundedHeight && constraints.maxHeight > 0
                ? constraints.maxHeight
                : width * 0.72);
        final cacheWidth = (width * dpr).clamp(240, 900).round();
        final cacheHeight = (resolvedHeight * dpr).clamp(180, 720).round();

        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: SizedBox(
            width: double.infinity,
            height: resolvedHeight,
            child: Image.network(
              url,
              fit: fit,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _ImagePlaceholder(serviceName: service.name);
              },
              errorBuilder: (context, error, stackTrace) {
                return _ImagePlaceholder(serviceName: service.name);
              },
            ),
          ),
        );
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final String serviceName;

  const _ImagePlaceholder({required this.serviceName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8EAFF),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_print_shop_outlined,
              color: Color(0xFF2E4CB9), size: 30),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              serviceName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF2E4CB9),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
