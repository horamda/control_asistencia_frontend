import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Exact decimal normalization; arithmetic uses integer cents, never doubles.
String? reintegroAmount(String input) {
  var value = input.trim();
  if (value.isEmpty) return null;
  if (value.contains(',')) {
    if (!RegExp(r'^(?:\d+|\d{1,3}(?:\.\d{3})+),\d{1,2}$').hasMatch(value)) {
      throw const FormatException('Importe inválido. Usá 1250,50.');
    }
    value = value.replaceAll('.', '').replaceAll(',', '.');
  }
  if (!RegExp(r'^\d{1,9}(?:\.\d{1,2})?$').hasMatch(value)) {
    throw const FormatException(
      'Importe inválido. Usá 1250,50, sin separadores de miles.',
    );
  }
  final parts = value.split('.');
  final cents =
      int.parse(parts[0]) * 100 +
      int.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
  if (cents <= 0 || cents > 99999999999) {
    throw const FormatException(
      'El importe debe ser mayor a cero y hasta 999999999,99.',
    );
  }
  return '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
}

List<Map<String, dynamic>> reintegroMaps(dynamic value) =>
    (value as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

const reintegroStates = <String, String>{
  'borrador': 'Borrador',
  'pendiente': 'Pendiente de aprobación',
  'devuelta': 'Devuelta para corregir',
  'aprobada': 'Aprobada',
  'rechazada': 'Rechazada',
  'pagada': 'Pagada',
  'cancelada': 'Cancelada',
};

/// Runs in compute on native. Reject oversized originals before decoding.
Uint8List compressReintegroPhoto(Uint8List bytes) {
  try {
    return _compressPhoto(bytes);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('La imagen está dañada o no se puede leer.');
  }
}

Uint8List _compressPhoto(Uint8List bytes) {
  if (bytes.length < 12) {
    throw const FormatException('Usá una imagen JPEG, PNG o WebP válida.');
  }
  if (bytes.length > 5 * 1024 * 1024) {
    throw const FormatException(
      'La foto supera 5 MB. Elegí una imagen más pequeña.',
    );
  }
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null || !['jpg', 'png', 'webp'].contains(decoder!.format.name)) {
    throw const FormatException('Usá una imagen JPEG, PNG o WebP.');
  }
  if (info.width * info.height > 20000000) {
    throw const FormatException('La foto supera 20 megapíxeles.');
  }
  var picture = decoder.decodeFrame(0);
  if (picture == null) {
    throw const FormatException('No se pudo leer la imagen.');
  }
  picture = img.bakeOrientation(picture);
  if (picture.width > 1800 || picture.height > 1800) {
    picture = img.copyResize(
      picture,
      width: picture.width >= picture.height ? 1800 : null,
      height: picture.height > picture.width ? 1800 : null,
    );
  }
  for (final quality in [85, 70, 55]) {
    final result = img.encodeJpg(picture, quality: quality);
    if (result.length <= 2 * 1024 * 1024) return result;
  }
  throw const FormatException(
    'No se pudo reducir la foto a 2 MB. Elegí otra imagen.',
  );
}
