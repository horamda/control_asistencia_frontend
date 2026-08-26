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
        size: const CropperSize(width: 520, height: 520),
      ),
    ],
  );
  return cropped == null ? null : XFile(cropped.path);
}
