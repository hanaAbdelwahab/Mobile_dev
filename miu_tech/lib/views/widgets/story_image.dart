import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StoryImage extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onImageLoaded;

  const StoryImage({
    super.key,
    required this.imageUrl,
    required this.onImageLoaded,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: Duration.zero, // Prevents flashing
      placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      errorWidget: (context, url, error) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white, size: 40),
      ),
      imageBuilder: (context, imageProvider) {
        // 🟢 REQUIRED FIX: Schedule the callback for after the build
        WidgetsBinding.instance.addPostFrameCallback((_) => onImageLoaded());

        return Image(image: imageProvider, fit: BoxFit.cover);
      },
    );
  }
}
