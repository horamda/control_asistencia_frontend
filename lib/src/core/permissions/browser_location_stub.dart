import 'package:geolocator/geolocator.dart';

Future<Position> readBrowserLocation(Duration timeLimit) =>
    Future.error(UnsupportedError('Browser location requires web'));
