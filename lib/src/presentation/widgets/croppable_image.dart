import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

enum ImageCropMode { free, square }

Future<XFile?> cropPickedImage(
  BuildContext context,
  XFile image, {
  required String title,
  ImageCropMode mode = ImageCropMode.free,
  int maxWidth = 2048,
  int maxHeight = 2048,
  int compressQuality = 85,
}) async {
  final colorScheme = Theme.of(context).colorScheme;
  final square = mode == ImageCropMode.square;
  final cropped = await ImageCropper().cropImage(
    sourcePath: image.path,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    aspectRatio: square ? const CropAspectRatio(ratioX: 1, ratioY: 1) : null,
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: compressQuality,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: title,
        toolbarColor: colorScheme.primary,
        toolbarWidgetColor: colorScheme.onPrimary,
        lockAspectRatio: square,
        initAspectRatio: square
            ? CropAspectRatioPreset.square
            : CropAspectRatioPreset.original,
        aspectRatioPresets: square
            ? const [CropAspectRatioPreset.square]
            : const [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9,
              ],
      ),
      IOSUiSettings(
        title: title,
        doneButtonTitle: 'Usar',
        cancelButtonTitle: 'Cancelar',
        aspectRatioLockEnabled: square,
        aspectRatioPresets: square
            ? const [CropAspectRatioPreset.square]
            : const [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9,
              ],
      ),
      WebUiSettings(
        context: context,
        presentStyle: WebPresentStyle.dialog,
        customDialogBuilder: (cropper, init, crop, rotate, scale) =>
            ResponsiveCropDialog(
              title: title,
              cropper: cropper,
              initialize: init,
              crop: crop,
              rotate: rotate,
              scale: scale,
            ),
      ),
    ],
  );
  return cropped == null ? null : XFile(cropped.path);
}

class ResponsiveCropDialog extends StatefulWidget {
  const ResponsiveCropDialog({
    super.key,
    required this.title,
    required this.cropper,
    required this.initialize,
    required this.crop,
    required this.rotate,
    required this.scale,
  });

  final String title;
  final Widget cropper;
  final VoidCallback initialize;
  final Future<String?> Function() crop;
  final ValueChanged<RotationAngle> rotate;
  final ValueChanged<num> scale;

  @override
  State<ResponsiveCropDialog> createState() => _ResponsiveCropDialogState();
}

class _ResponsiveCropDialogState extends State<ResponsiveCropDialog> {
  bool _processing = false;
  double _scale = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.initialize();
  }

  Future<void> _crop() async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final result = await widget.crop();
      if (!mounted) return;
      if (result == null) throw StateError('No cropped image');
      Navigator.of(context).pop(result);
    } catch (_) {
      if (mounted) {
        setState(() {
          _processing = false;
          _error = 'No se pudo recortar. Intentá nuevamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 680),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(child: ClipRect(child: widget.cropper)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Girar a la izquierda',
                onPressed: _processing
                    ? null
                    : () => widget.rotate(RotationAngle.counterClockwise90),
                icon: const Icon(Icons.rotate_left_rounded),
              ),
              Expanded(
                child: Slider(
                  value: _scale,
                  min: 1,
                  max: 3,
                  onChanged: _processing
                      ? null
                      : (value) {
                          setState(() => _scale = value);
                          widget.scale(value);
                        },
                ),
              ),
              IconButton(
                tooltip: 'Girar a la derecha',
                onPressed: _processing
                    ? null
                    : () => widget.rotate(RotationAngle.clockwise90),
                icon: const Icon(Icons.rotate_right_rounded),
              ),
            ],
          ),
          if (_error != null) Text(_error!, textAlign: TextAlign.center),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 12,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: _processing
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar', textAlign: TextAlign.center),
                ),
                FilledButton(
                  onPressed: _processing ? null : _crop,
                  child: Text(
                    _processing ? 'Procesando…' : 'Usar',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
