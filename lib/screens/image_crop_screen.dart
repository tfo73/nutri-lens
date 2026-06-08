import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class ImageCropScreen extends StatefulWidget {
  final String imagePath;

  const ImageCropScreen({super.key, required this.imagePath});

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final TransformationController _controller = TransformationController();
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  // Image dimensions
  Size _imageSize = Size.zero;
  Size _viewportSize = Size.zero;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransformChanged);
    _loadImageSize();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransformChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    _clampTransform();
  }

  Future<void> _loadImageSize() async {
    final file = File(widget.imagePath);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    setState(() {
      _imageSize = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    });
    frame.image.dispose();
  }

  bool _isClamping = false;
  void _clampTransform() {
    if (_isClamping || _imageSize == Size.zero || _viewportSize == Size.zero) return;

    final matrix = _controller.value;
    final scale = matrix.getMaxScaleOnAxis();
    final cropSize = _viewportSize.width * 0.8;
    final cropLeft = (_viewportSize.width - cropSize) / 2;
    final cropTop = (_viewportSize.height - cropSize) / 2;
    final cropRight = cropLeft + cropSize;
    final cropBottom = cropTop + cropSize;

    final viewW = _viewportSize.width;
    final viewH = _viewportSize.height;
    final imgAspect = _imageSize.width / _imageSize.height;
    final viewAspect = viewW / viewH;

    double baseW, baseH;
    if (imgAspect > viewAspect) {
      baseH = viewH;
      baseW = viewH * imgAspect;
    } else {
      baseW = viewW;
      baseH = viewW / imgAspect;
    }

    final scaledW = baseW * scale;
    final scaledH = baseH * scale;

    final tx = matrix.storage[12];
    final ty = matrix.storage[13];

    final baseOffX = (viewW - baseW) / 2;
    final baseOffY = (viewH - baseH) / 2;

    final imgLeft = baseOffX * (1 - scale) + tx;
    final imgTop = baseOffY * (1 - scale) + ty;

    double clampedTx = tx;
    double clampedTy = ty;

    if (imgLeft > cropLeft) clampedTx = tx - (imgLeft - cropLeft);
    if (imgLeft + scaledW < cropRight) clampedTx = tx + (cropRight - (imgLeft + scaledW));
    if (imgTop > cropTop) clampedTy = ty - (imgTop - cropTop);
    if (imgTop + scaledH < cropBottom) clampedTy = ty + (cropBottom - (imgTop + scaledH));

    if (clampedTx != tx || clampedTy != ty) {
      _isClamping = true;
      final clamped = matrix.clone();
      clamped.storage[12] = clampedTx;
      clamped.storage[13] = clampedTy;
      _controller.value = clamped;
      _isClamping = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cropSize = size.width * 0.8;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Fotoğrafı Düzenle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, widget.imagePath);
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
          
          double baseW = 0, baseH = 0;
          double minScale = 1.0;
          if (_imageSize != Size.zero) {
            final imgAspect = _imageSize.width / _imageSize.height;
            final viewAspect = _viewportSize.width / _viewportSize.height;
            if (imgAspect > viewAspect) {
              baseH = _viewportSize.height;
              baseW = _viewportSize.height * imgAspect;
            } else {
              baseW = _viewportSize.width;
              baseH = _viewportSize.width / imgAspect;
            }
            
            // minScale should ensure the image covers cropSize
            minScale = cropSize / (baseW < baseH ? baseW : baseH);
          }

          return Stack(
            alignment: Alignment.center,
            children: [
              // Image with interactive viewer
              InteractiveViewer(
                transformationController: _controller,
                minScale: minScale,
                maxScale: 5.0,
                boundaryMargin: const EdgeInsets.all(1000),
                constrained: false,
                child: _imageSize != Size.zero
                    ? Image.file(
                        File(widget.imagePath),
                        width: baseW,
                        height: baseH,
                        fit: BoxFit.fill,
                      )
                    : SizedBox(
                        width: _viewportSize.width,
                        height: _viewportSize.height,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
              ),

              // Yuvarlak Maske
              IgnorePointer(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.7),
                    BlendMode.srcOut,
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          backgroundBlendMode: BlendMode.dstOut,
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: cropSize,
                          height: cropSize,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(cropSize / 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Yuvarlak Çerçeve
              IgnorePointer(
                child: Container(
                  width: cropSize,
                  height: cropSize,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(cropSize / 2),
                  ),
                ),
              ),

              Positioned(
                bottom: 40,
                child: Text(
                  'Yakınlaştırmak için kaydırın,\nhizalamak için sürükleyin',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
