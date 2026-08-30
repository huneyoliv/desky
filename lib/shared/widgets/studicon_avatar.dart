import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/cdn/cdn_resolver.dart';

class StudiconAvatar extends StatelessWidget {
  final int studiconId;
  final StudiconPose pose;
  final double size;
  final bool isStudying;

  const StudiconAvatar({
    super.key,
    required this.studiconId,
    this.pose = StudiconPose.normal1,
    this.size = 120,
    this.isStudying = true,
  });

  @override
  Widget build(BuildContext context) {
    if (studiconId <= 0 || studiconId == -1) {
      final defaultAsset = CdnResolver.defaultStudiconAsset(
        pose,
        isStudying: isStudying,
      );
      return Image.asset(
        defaultAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }

    final primaryUrl = CdnResolver.studiconUrl(studiconId, pose);
    final fallbackAsset = CdnResolver.defaultStudiconAsset(
      pose,
      isStudying: isStudying,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: CachedNetworkImage(
        key: ValueKey(primaryUrl),
        imageUrl: primaryUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholder: (context, url) => SizedBox(
          width: size,
          height: size,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Image.asset(
          fallbackAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
