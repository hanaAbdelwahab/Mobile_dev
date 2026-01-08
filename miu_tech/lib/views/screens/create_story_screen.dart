import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../controllers/stories_controller.dart';
import 'package:image_cropper/image_cropper.dart';

class CreateStoryScreen extends ConsumerStatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  File? _selectedFile;
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  String _loadingText = '';
  final _picker = ImagePicker();

  // Text Overlay State
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final List<TextOverlayItem> _textItems = [];

  // Drawing State
  final List<DrawingPoint?> _drawingPoints = [];
  bool _isDrawing = false;
  Color _drawingColor = Colors.white;
  final double _drawingWidth = 5.0;

  // Sticker State
  final List<StickerItem> _stickers = [];
  final List<String> _emojis = [
    '😀',
    '😂',
    '😍',
    '😎',
    '😭',
    '😡',
    '👍',
    '👎',
    '🎉',
    '🔥',
    '❤️',
    '💔',
    '⭐',
    '🌟',
    '🍕',
    '🍔',
    '🌮',
    '🍦',
    '🍩',
    '🍪',
    '🚗',
    '✈️',
    '🚀',
    '⚽',
    '🏀',
    '🏈',
    '⚾',
    '🎾',
    '🏐',
    '🏉',
    '🐶',
    '🐱',
    '🐭',
    '🐹',
    '🐰',
    '🦊',
    '🐻',
    '🐼',
    '🐨',
    '🐯',
  ];

  // Drag to Delete State
  bool _isDragging = false;
  bool _isOverTrash = false;

  @override
  void initState() {
    super.initState();
    // Optional: Auto-open picker when screen loads
    //WidgetsBinding.instance.addPostFrameCallback((_) => _pickMedia());
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      // 🟢 Pick Media (Image or Video)
      final XFile? picked = await _picker.pickMedia();

      if (picked != null) {
        final path = picked.path;
        final ext = path.split('.').last.toLowerCase();

        // Supported Formats
        final videoExts = {
          'mp4',
          'mov',
          'avi',
          'wmv',
          'm4v',
          'mpg',
          'mpeg',
          'webm',
        };
        final imageExts = {'jpg', 'jpeg', 'png', 'heic', 'webp', 'bmp'};

        // Check Type
        bool isVideo = picked.mimeType?.startsWith('video/') ?? false;
        if (!isVideo) isVideo = videoExts.contains(ext);

        bool isImage = picked.mimeType?.startsWith('image/') ?? false;
        if (!isImage) isImage = imageExts.contains(ext);

        if (isVideo) {
          await _setFile(File(path), isVideo: true);
        } else if (isImage) {
          // If image, crop it
          await _cropImage(path);
        } else {
          // 🔴 UNSUPPORTED FORMAT
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Unsupported file format: .$ext'),
                backgroundColor: Colors.red,
              ),
            );
            if (_selectedFile == null) Navigator.pop(context);
          }
        }
      } else {
        // If user cancelled picker and we have no file, close screen
        if (_selectedFile == null && mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error picking media: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking media: $e')));
      }
    }
  }

  Future<void> _cropImage(String sourcePath) async {
    // Set status bar to black to ensure crop controls are visible/clickable
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    CroppedFile? croppedFile;

    try {
      croppedFile = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        compressQuality: 80,
        aspectRatio: const CropAspectRatio(ratioX: 9, ratioY: 16),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Edit Story',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            statusBarColor: Colors.black,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
            backgroundColor: Colors.black,
            hideBottomControls: true,
          ),
          IOSUiSettings(
            title: 'Edit Story',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
    } finally {
      // Restore transparent status bar
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
    }

    if (!mounted) return;

    if (croppedFile != null) {
      await _setFile(File(croppedFile.path), isVideo: false);
    } else if (_selectedFile == null && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _setFile(File file, {required bool isVideo}) async {
    // 1. Clear old state & Show Loading
    setState(() {
      _isLoading = true;
      _loadingText = 'Loading...';
      _selectedFile = null; // Prevents showing stale file
      _videoController?.dispose();
      _videoController = null;
    });

    if (isVideo) {
      try {
        final controller = VideoPlayerController.file(file);
        await controller.initialize();

        // 🟢 DURATION CHECK (Max 30 seconds)
        if (controller.value.duration.inSeconds > 30) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video too long. Max duration is 30 seconds.'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => _isLoading = false);
          }
          await controller.dispose();
          return;
        }

        await controller.setLooping(true);
        await controller.play();
        _videoController = controller;
      } catch (e) {
        debugPrint("Error initializing video: $e");
        if (mounted) {
          String errorMessage = 'Could not load video';
          if (e.toString().contains('channel-error')) {
            errorMessage = 'Please restart the app to enable video support';
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
          setState(() => _isLoading = false);
        }
        return; // Exit if video failed to load
      }
    }

    // 🟢 SIZE CHECK (Max 10MB)
    final int sizeInBytes = await file.length();
    final double sizeInMb = sizeInBytes / (1024 * 1024);
    if (sizeInMb > 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'File too large (${sizeInMb.toStringAsFixed(1)}MB). Max 10MB.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
          _selectedFile = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _selectedFile = file;
        _isLoading = false;
      });
    }
  }

  Future<void> _postStory() async {
    if (_selectedFile == null) return;

    setState(() {
      _isLoading = true;
      _loadingText = 'Uploading...';
    });

    try {
      File fileToUpload = _selectedFile!;

      // If we have text overlay or stickers or drawings and it's an image (not video), capture the edited version
      if ((_textItems.isNotEmpty ||
              _stickers.isNotEmpty ||
              _drawingPoints.isNotEmpty) &&
          _videoController == null) {
        final captured = await _captureImage();
        if (captured != null) {
          fileToUpload = captured;
        }
      }

      await ref.read(storiesProvider.notifier).addStory(fileToUpload);
      if (mounted) {
        Navigator.pop(context); // Close screen on success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading story: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showTextEditor({TextOverlayItem? item}) {
    final controller = TextEditingController(text: item?.text ?? '');
    Color tempColor = item?.color ?? Colors.white;
    double tempSize = item?.fontSize ?? 24.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: Colors.black87,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  style: TextStyle(
                    color: tempColor,
                    fontSize: tempSize,
                    fontWeight: FontWeight.bold,
                  ),
                  autofocus: true,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: 'Type something...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 20),
                // Color Picker
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        [
                          Colors.white,
                          Colors.black,
                          Colors.red,
                          Colors.yellow,
                          Colors.green,
                          Colors.blue,
                          Colors.purple,
                          Colors.orange,
                          Colors.pink,
                        ].map((color) {
                          return GestureDetector(
                            onTap: () =>
                                setStateDialog(() => tempColor = color),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: tempColor == color ? 3 : 1,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                // Size Slider
                Row(
                  children: [
                    const Text(
                      'A',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Expanded(
                      child: Slider(
                        value: tempSize,
                        min: 12,
                        max: 60,
                        activeColor: Colors.white,
                        inactiveColor: Colors.grey,
                        onChanged: (val) =>
                            setStateDialog(() => tempSize = val),
                      ),
                    ),
                    const Text(
                      'A',
                      style: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (item != null) {
                    setState(() {
                      _textItems.remove(item);
                    });
                  }
                  Navigator.pop(context);
                },
                child: const Text('Clear', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    setState(() {
                      if (item != null) {
                        item.text = controller.text;
                        item.color = tempColor;
                        item.fontSize = tempSize;
                      } else {
                        _textItems.add(
                          TextOverlayItem(
                            text: controller.text,
                            position: const Offset(100, 100),
                            color: tempColor,
                            fontSize: tempSize,
                          ),
                        );
                      }
                    });
                  } else if (item != null) {
                    setState(() {
                      _textItems.remove(item);
                    });
                  }
                  Navigator.pop(context);
                },
                child: const Text('Done', style: TextStyle(color: Colors.blue)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: _emojis.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _stickers.add(
                      StickerItem(
                        emoji: _emojis[index],
                        position: const Offset(150, 300),
                      ),
                    );
                  });
                  Navigator.pop(context);
                },
                child: Center(
                  child: Text(
                    _emojis[index],
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<File?> _captureImage() async {
    try {
      RenderRepaintBoundary? boundary =
          _repaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) return null;

      // Capture image
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Save to temp file
      final tempDir = Directory.systemTemp;
      final file = await File(
        '${tempDir.path}/story_edit_${DateTime.now().millisecondsSinceEpoch}.png',
      ).create();
      await file.writeAsBytes(pngBytes);

      return file;
    } catch (e) {
      debugPrint("Error capturing image: $e");
      return null;
    }
  }

  bool _checkTrashCollision(Offset position) {
    final screenSize = MediaQuery.of(context).size;
    // Trash area at bottom center
    final trashRect = Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height - 100),
      width: 80,
      height: 80,
    );
    return trashRect.contains(position);
  }

  @override
  Widget build(BuildContext context) {
    final isVideo =
        _videoController != null && _videoController!.value.isInitialized;

    // 🟢 REMOVED PopScope as requested
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. THE PREVIEW (Image or Video) + TEXT OVERLAY
          // We wrap this in RepaintBoundary to capture it as an image
          if (_selectedFile != null)
            Positioned.fill(
              child: RepaintBoundary(
                key: _repaintBoundaryKey,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The Media
                    isVideo
                        ? FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _videoController!.value.size.width,
                              height: _videoController!.value.size.height,
                              child: VideoPlayer(_videoController!),
                            ),
                          )
                        : Image.file(_selectedFile!, fit: BoxFit.cover),

                    // Drawing Layer
                    if (_drawingPoints.isNotEmpty || _isDrawing)
                      GestureDetector(
                        onPanStart: _isDrawing
                            ? (details) {
                                setState(() {
                                  _drawingPoints.add(
                                    DrawingPoint(
                                      offset: details.localPosition,
                                      paint: Paint()
                                        ..color = _drawingColor
                                        ..isAntiAlias = true
                                        ..strokeWidth = _drawingWidth
                                        ..strokeCap = StrokeCap.round,
                                    ),
                                  );
                                });
                              }
                            : null,
                        onPanUpdate: _isDrawing
                            ? (details) {
                                setState(() {
                                  _drawingPoints.add(
                                    DrawingPoint(
                                      offset: details.localPosition,
                                      paint: Paint()
                                        ..color = _drawingColor
                                        ..isAntiAlias = true
                                        ..strokeWidth = _drawingWidth
                                        ..strokeCap = StrokeCap.round,
                                    ),
                                  );
                                });
                              }
                            : null,
                        onPanEnd: _isDrawing
                            ? (details) {
                                setState(() {
                                  _drawingPoints.add(null);
                                });
                              }
                            : null,
                        child: CustomPaint(
                          painter: DrawingPainter(points: _drawingPoints),
                          size: Size.infinite,
                        ),
                      ),

                    // Stickers Layer
                    ..._stickers.map((sticker) {
                      return Positioned(
                        left: sticker.position.dx,
                        top: sticker.position.dy,
                        child: GestureDetector(
                          onScaleStart: (details) {
                            if (_isLoading || _isDrawing) return;
                            setState(() => _isDragging = true);
                            sticker.baseScale = sticker.scale;
                            sticker.baseRotation = sticker.rotation;
                          },
                          onScaleUpdate: (details) {
                            if (_isLoading || _isDrawing) return;
                            setState(() {
                              sticker.position += details.focalPointDelta;
                              sticker.scale = sticker.baseScale * details.scale;
                              sticker.rotation =
                                  sticker.baseRotation + details.rotation;
                              _isOverTrash = _checkTrashCollision(
                                details.focalPoint,
                              );
                            });
                          },
                          onScaleEnd: (details) {
                            if (_isOverTrash) {
                              setState(() {
                                _stickers.remove(sticker);
                                _isDragging = false;
                                _isOverTrash = false;
                              });
                            } else {
                              setState(() {
                                _isDragging = false;
                                _isOverTrash = false;
                              });
                            }
                          },
                          child: Transform.rotate(
                            angle: sticker.rotation,
                            child: Transform.scale(
                              scale: sticker.scale,
                              child: Text(
                                sticker.emoji,
                                style: const TextStyle(fontSize: 50),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    // Text Layers
                    ..._textItems.map((item) {
                      return Positioned(
                        left: item.position.dx,
                        top: item.position.dy,
                        child: GestureDetector(
                          onScaleStart: (details) {
                            if (_isLoading || _isDrawing) return;
                            setState(() => _isDragging = true);
                            item.baseScale = item.scale;
                            item.baseRotation = item.rotation;
                          },
                          onScaleUpdate: (details) {
                            if (_isLoading || _isDrawing) return;
                            setState(() {
                              item.position += details.focalPointDelta;
                              item.scale = item.baseScale * details.scale;
                              item.rotation =
                                  item.baseRotation + details.rotation;
                              _isOverTrash = _checkTrashCollision(
                                details.focalPoint,
                              );
                            });
                          },
                          onScaleEnd: (details) {
                            if (_isOverTrash) {
                              setState(() {
                                _textItems.remove(item);
                                _isDragging = false;
                                _isOverTrash = false;
                              });
                            } else {
                              setState(() {
                                _isDragging = false;
                                _isOverTrash = false;
                              });
                            }
                          },
                          onTap: (_isLoading || _isDrawing)
                              ? null
                              : () => _showTextEditor(item: item),
                          child: Transform.rotate(
                            angle: item.rotation,
                            child: Transform.scale(
                              scale: item.scale,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.text,
                                  style: TextStyle(
                                    color: item.color,
                                    fontSize: item.fontSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            )
          else
            // Placeholder/Fallback
            Positioned.fill(
              child: GestureDetector(
                onTap: _isLoading ? null : _pickMedia,
                child: Container(
                  color: Colors.grey[900],
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                      SizedBox(height: 10),
                      Text(
                        "Tap to create story",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2. LOADING INDICATOR
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Column(
                  children: [
                    const LinearProgressIndicator(
                      color: Colors.blueAccent,
                      backgroundColor: Colors.white24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loadingText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // TRASH CAN (Drag to Delete)
          if (_isDragging)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _isOverTrash
                        ? Colors.red.withValues(alpha: 0.8)
                        : Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),

          // 3. TOP CONTROLS
          if (!_isDrawing && !_isDragging)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black54,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),

                    Row(
                      children: [
                        // Drawing Tool
                        if (_selectedFile != null && !_isLoading && !isVideo)
                          GestureDetector(
                            onTap: () => setState(() => _isDrawing = true),
                            child: Container(
                              margin: const EdgeInsets.only(right: 16),
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black54,
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),

                        // Sticker Tool
                        if (_selectedFile != null && !_isLoading && !isVideo)
                          GestureDetector(
                            onTap: _showStickerPicker,
                            child: Container(
                              margin: const EdgeInsets.only(right: 16),
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black54,
                              ),
                              child: const Icon(
                                Icons.emoji_emotions_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),

                        // Text Tool (Only for images or if we want to allow overlay on video without saving)
                        // Currently we only save text for images
                        if (_selectedFile != null && !_isLoading && !isVideo)
                          GestureDetector(
                            onTap: _showTextEditor,
                            child: Container(
                              margin: const EdgeInsets.only(right: 16),
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black54,
                              ),
                              child: const Icon(
                                Icons.text_fields,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),

                        // Crop (Only for images)
                        if (_selectedFile != null && !_isLoading && !isVideo)
                          GestureDetector(
                            onTap: () => _cropImage(_selectedFile!.path),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black54,
                              ),
                              child: const Icon(
                                Icons.crop,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // 4. BOTTOM CONTROLS
          if (_selectedFile != null && !_isDrawing && !_isDragging)
            Positioned(
              bottom: 30,
              right: 20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Retake
                  if (!_isLoading)
                    TextButton(
                      onPressed: _pickMedia,
                      child: const Text(
                        "Retake",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),

                  // Post
                  GestureDetector(
                    onTap: _isLoading ? null : _postStory,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _isLoading ? "Posting..." : "Your Story",
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (!_isLoading) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Colors.black,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 5. DRAWING TOOLBAR
          if (_isDrawing)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black87,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 8,
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Colors
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              [
                                Colors.white,
                                Colors.black,
                                Colors.red,
                                Colors.yellow,
                                Colors.green,
                                Colors.blue,
                                Colors.purple,
                                Colors.orange,
                                Colors.pink,
                              ].map((color) {
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _drawingColor = color),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: _drawingColor == color ? 3 : 1,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Undo
                          IconButton(
                            icon: const Icon(Icons.undo, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                if (_drawingPoints.isNotEmpty) {
                                  // Remove last stroke (points until null)
                                  if (_drawingPoints.last == null) {
                                    _drawingPoints.removeLast();
                                  }
                                  while (_drawingPoints.isNotEmpty &&
                                      _drawingPoints.last != null) {
                                    _drawingPoints.removeLast();
                                  }
                                }
                              });
                            },
                          ),
                          // Done
                          TextButton(
                            onPressed: () => setState(() => _isDrawing = false),
                            child: const Text(
                              "Done",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DrawingPoint {
  final Offset offset;
  final Paint paint;
  DrawingPoint({required this.offset, required this.paint});
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint?> points;

  DrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
          points[i]!.offset,
          points[i + 1]!.offset,
          points[i]!.paint,
        );
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawPoints(ui.PointMode.points, [
          points[i]!.offset,
        ], points[i]!.paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class StickerItem {
  String emoji;
  Offset position;
  double scale;
  double rotation;

  // Transient state for gestures
  double baseScale = 1.0;
  double baseRotation = 0.0;

  StickerItem({
    required this.emoji,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
  });
}

class TextOverlayItem {
  String text;
  Offset position;
  Color color;
  double fontSize;
  double scale;
  double rotation;

  // Transient state for gestures
  double baseScale = 1.0;
  double baseRotation = 0.0;

  TextOverlayItem({
    required this.text,
    required this.position,
    this.color = Colors.white,
    this.fontSize = 24.0,
    this.scale = 1.0,
    this.rotation = 0.0,
  });
}
