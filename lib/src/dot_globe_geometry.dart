import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart'
    show ImageConfiguration, ImageInfo, ImageProvider, ImageStreamListener;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'dot_globe_colormap.dart';

/// Geometry data and projection math for the dotted globe.
///
/// Land dots come from `assets/land_dots.bin`: generated offline from Natural
/// Earth 110m land polygons sampled on a Fibonacci sphere, stored as
/// little-endian int16 pairs (lat*100, lng*100), ~6300 points. (Every Flutter
/// target platform is little-endian, so the host byte order is used directly.)
class DotGlobeGeometry {
  DotGlobeGeometry._(this.unitVectors, [this.colors])
      : pointCount = unitVectors.length ~/ 3,
        assert(
          colors == null || colors.length == unitVectors.length ~/ 3,
          'colors length must equal pointCount (one ARGB int per dot)',
        );

  /// Builds geometry directly from a flat `[x0,y0,z0, x1,y1,z1, ...]` buffer of
  /// unit vectors — the power-user entry point.
  ///
  /// The caller owns the axis convention. To line up with markers and arcs (which
  /// are positioned from lat/lng), each vector must follow the standard axes:
  /// `x = -cos(lat)cos(lng)` (east projects to screen-right), `y = sin(lat)`
  /// (north positive), `z = cos(lat)sin(lng)`, with lat/lng in radians. If you
  /// only have lat/lng pairs, prefer [DotGlobeGeometry.fromLatLng], which applies
  /// this convention for you.
  ///
  /// Does not touch the shared cache used by [load].
  ///
  /// Throws [ArgumentError] if [unitVectors] is empty or its length is not a
  /// multiple of 3.
  factory DotGlobeGeometry.fromUnitVectors(Float32List unitVectors) {
    if (unitVectors.isEmpty || unitVectors.length % 3 != 0) {
      throw ArgumentError.value(
        unitVectors.length,
        'unitVectors',
        'must be non-empty and a multiple of 3 (x,y,z per point)',
      );
    }
    return DotGlobeGeometry._(unitVectors);
  }

  /// Builds geometry from latitude/longitude pairs (degrees), applying the
  /// standard axis convention so the cloud lines up with markers and arcs.
  ///
  /// Expected ranges are latitude `[-90, 90]` and longitude `[-180, 180]`.
  /// Out-of-range values still project mathematically (no error is thrown), but
  /// will wrap around the sphere.
  ///
  /// Does not touch the shared cache used by [load].
  ///
  /// Throws [ArgumentError] if [points] is empty.
  factory DotGlobeGeometry.fromLatLng(
    List<({double latitude, double longitude})> points,
  ) {
    if (points.isEmpty) {
      throw ArgumentError.value(
        points,
        'points',
        'must be non-empty (at least one lat/lng pair)',
      );
    }
    final vectors = Float32List(points.length * 3);
    for (var i = 0; i < points.length; i++) {
      _fillVector(points[i].latitude, points[i].longitude, vectors, i * 3);
    }
    return DotGlobeGeometry._(vectors);
  }

  /// Builds geometry from the bundled `.bin` format: little-endian int16 pairs
  /// of `(round(lat * 100), round(lng * 100))`, two values (4 bytes) per point.
  /// Applies the standard axis convention, so the cloud lines up with markers
  /// and arcs.
  ///
  /// Does not touch the shared cache used by [load].
  ///
  /// Throws [FormatException] if [data] is empty or its byte length is not a
  /// multiple of 4.
  factory DotGlobeGeometry.fromPackedInt16(ByteData data) {
    if (data.lengthInBytes == 0 || data.lengthInBytes % 4 != 0) {
      throw FormatException(
        'Packed int16 geometry must be 2 little-endian int16 (4 bytes) per '
        'point; got ${data.lengthInBytes} bytes, which is empty or not a '
        'multiple of 4.',
      );
    }
    final int16 = Int16List.sublistView(data);
    final count = int16.length ~/ 2;
    final vectors = Float32List(count * 3);
    for (var i = 0; i < count; i++) {
      _fillVector(int16[i * 2] / 100, int16[i * 2 + 1] / 100, vectors, i * 3);
    }
    return DotGlobeGeometry._(vectors);
  }

  /// Loads geometry from an asset in the bundled `.bin` format (see
  /// [DotGlobeGeometry.fromPackedInt16]). [assetKey] is resolved against
  /// [bundle], defaulting to [rootBundle].
  ///
  /// Does not touch the shared cache used by [load].
  ///
  /// Throws an [Exception] naming [assetKey] (with the underlying cause) if the
  /// asset is missing or malformed.
  static Future<DotGlobeGeometry> fromAsset(
    String assetKey, {
    AssetBundle? bundle,
  }) async {
    try {
      final data = await (bundle ?? rootBundle).load(assetKey);
      return DotGlobeGeometry.fromPackedInt16(data);
    } catch (e) {
      throw Exception(
        'DotGlobeGeometry.fromAsset failed to load "$assetKey": $e',
      );
    }
  }

  /// Land-dot unit vectors, laid out as `[x0,y0,z0, x1,y1,z1, ...]`.
  /// Axes: `x = -cos(lat)cos(lng)` (negated so east projects to screen-right),
  /// `y = sin(lat)` (north positive), `z = cos(lat)sin(lng)`.
  final Float32List unitVectors;

  /// Number of land dots (`unitVectors.length / 3`).
  final int pointCount;

  /// Optional per-dot colours, one packed ARGB-8888 int per point
  /// (`length == pointCount`).
  ///
  /// `null` (the default for every factory) means all dots use the style's
  /// single `dotColor` — a pixel-identical fast path. When non-null, each dot
  /// uses its own colour and a dot whose alpha is `0` is hidden. Build a
  /// coloured geometry with the immutable fillers [withColors], [colorize],
  /// [colorizeByValues], [colorizeFromImage] or [colorizedFromImageProvider];
  /// each returns a new geometry that shares [unitVectors] with this one.
  final Int32List? colors;

  /// Global cache so multiple instances share one point cloud.
  static DotGlobeGeometry? _cached;
  static Future<DotGlobeGeometry>? _loading;

  /// Loads (and caches) the land-dot point cloud from the bundled asset.
  static Future<DotGlobeGeometry> load() {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    return _loading ??= _doLoad();
  }

  static Future<DotGlobeGeometry> _doLoad() async {
    try {
      // When loaded by a consumer app, the asset key must be prefixed with packages/<package-name>/.
      final data =
          await rootBundle.load('packages/dot_globe/assets/land_dots.bin');
      final int16 = Int16List.sublistView(data);
      final count = int16.length ~/ 2;
      final vectors = Float32List(count * 3);
      for (var i = 0; i < count; i++) {
        _fillVector(int16[i * 2] / 100, int16[i * 2 + 1] / 100, vectors, i * 3);
      }
      _cached = DotGlobeGeometry._(vectors);
      return _cached!;
    } finally {
      // On success the result is stored in _cached; on failure _loading is cleared so
      // the next load() call can retry — prevents a failed Future from being cached permanently.
      _loading = null;
    }
  }

  /// Global cache for the natural-colour Earth.
  static DotGlobeGeometry? _cachedNatural;
  static Future<DotGlobeGeometry>? _loadingNatural;

  /// Loads (and caches) the bundled Earth dots **coloured with natural satellite
  /// colours** — deserts tan, vegetation green, ice white, water blue — baked
  /// offline from NASA Blue Marble (public domain). The out-of-the-box "real
  /// Earth" look: just pass the result as [DotGlobe.geometry].
  ///
  /// ```dart
  /// final earth = await DotGlobeGeometry.naturalEarth();
  /// DotGlobe(geometry: earth);
  /// ```
  static Future<DotGlobeGeometry> naturalEarth() {
    final cached = _cachedNatural;
    if (cached != null) return Future.value(cached);
    return _loadingNatural ??= _loadNatural();
  }

  static Future<DotGlobeGeometry> _loadNatural() async {
    try {
      final base = await load();
      // RGB888, 3 bytes per dot, in the same order as land_dots.bin.
      final data =
          await rootBundle.load('packages/dot_globe/assets/land_colors.bin');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final count = base.pointCount;
      if (bytes.length < count * 3) {
        throw FormatException(
          'land_colors.bin too short: need ${count * 3} bytes (3 per dot), '
          'got ${bytes.length}.',
        );
      }
      final colors = Int32List(count);
      for (var i = 0; i < count; i++) {
        final o = i * 3;
        colors[i] =
            0xFF000000 | (bytes[o] << 16) | (bytes[o + 1] << 8) | bytes[o + 2];
      }
      _cachedNatural = base.withColors(colors);
      return _cachedNatural!;
    } finally {
      _loadingNatural = null;
    }
  }

  /// Returns a new geometry sharing this cloud's [unitVectors] but carrying the
  /// explicit per-dot [colors] (one packed ARGB-8888 int per point). A dot whose
  /// alpha is `0` is hidden.
  ///
  /// Does not mutate this geometry and does not touch the shared cache used by
  /// [load]. Asserts `colors.length == pointCount`.
  DotGlobeGeometry withColors(Int32List colors) {
    assert(
      colors.length == pointCount,
      'colors length (${colors.length}) must equal pointCount ($pointCount)',
    );
    return DotGlobeGeometry._(unitVectors, colors);
  }

  /// Returns a new geometry coloured by a callback, sharing this cloud's
  /// [unitVectors]. [toArgb] is called once per dot with the dot's recovered
  /// latitude/longitude (degrees) and its index, and returns a packed ARGB-8888
  /// int; alpha `0` hides the dot.
  ///
  /// Does not mutate this geometry and does not touch the shared cache used by
  /// [load].
  DotGlobeGeometry colorize(
    int Function(double latDeg, double lngDeg, int index) toArgb,
  ) {
    final out = Int32List(pointCount);
    final ll = Float64List(2);
    for (var i = 0; i < pointCount; i++) {
      _latLngOf(i, ll);
      out[i] = toArgb(ll[0], ll[1], i);
    }
    return DotGlobeGeometry._(unitVectors, out);
  }

  /// Returns a new geometry coloured by mapping each per-dot scalar in [values]
  /// through [colormap], sharing this cloud's [unitVectors].
  ///
  /// Each value is normalised to `t ∈ [0, 1]` using [min]/[max]; when either is
  /// null it is taken from the data extent (the value range across [values]).
  /// The colour is `colormap.argbAt(t)`. When [hideBelow] is non-null, any dot
  /// whose value is `< hideBelow` is hidden (alpha `0`).
  ///
  /// Does not mutate this geometry and does not touch the shared cache used by
  /// [load]. Asserts `values.length == pointCount`.
  DotGlobeGeometry colorizeByValues(
    List<double> values, {
    required DotGlobeColormap colormap,
    double? min,
    double? max,
    double? hideBelow,
  }) {
    assert(
      values.length == pointCount,
      'values length (${values.length}) must equal pointCount ($pointCount)',
    );
    assert(
      min == null || max == null || max >= min,
      'max ($max) must be >= min ($min)',
    );
    // Auto-derive the extent from the data when a bound is not supplied.
    var lo = min;
    var hi = max;
    if (lo == null || hi == null) {
      var dataMin = double.infinity;
      var dataMax = double.negativeInfinity;
      for (final value in values) {
        if (value.isNaN) continue;
        if (value < dataMin) dataMin = value;
        if (value > dataMax) dataMax = value;
      }
      if (dataMin == double.infinity) {
        // No finite values; fall back to a degenerate [0, 1] range.
        dataMin = 0;
        dataMax = 1;
      }
      lo ??= dataMin;
      hi ??= dataMax;
    }
    final span = hi - lo;
    final out = Int32List(pointCount);
    for (var i = 0; i < pointCount; i++) {
      final value = values[i];
      // NaN reads as "no data" — hidden, not painted as the ramp-start colour.
      if (value.isNaN || (hideBelow != null && value < hideBelow)) {
        out[i] = 0; // hidden (alpha 0)
        continue;
      }
      // Guard a zero-width span so all dots land at the ramp start.
      final t = span == 0 ? 0.0 : (value - lo) / span;
      out[i] = colormap.argbAt(t);
    }
    return DotGlobeGeometry._(unitVectors, out);
  }

  /// Returns a new geometry coloured by sampling an EQUIRECTANGULAR image,
  /// sharing this cloud's [unitVectors].
  ///
  /// [equirectangular] must map longitude `−180..180` across its width and
  /// latitude `90..−90` down its height. For each dot the sample point is
  /// `u = lng / 360 + 0.5`, `v = 0.5 - lat / 180`, read at pixel
  /// `(u * width, v * height)`. When [wrapLongitude] is true the horizontal
  /// coordinate wraps (seamless east/west); the vertical coordinate is always
  /// clamped. If the sampled alpha (`0..1`) is below [hideBelowAlpha] the dot is
  /// hidden.
  ///
  /// Does not mutate this geometry and does not touch the shared cache used by
  /// [load].
  Future<DotGlobeGeometry> colorizeFromImage(
    ui.Image equirectangular, {
    double hideBelowAlpha = 0.0,
    bool wrapLongitude = true,
  }) async {
    final width = equirectangular.width;
    final height = equirectangular.height;
    final byteData = await equirectangular.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    final out = Int32List(pointCount);
    if (byteData == null || width == 0 || height == 0) {
      // Undecodable image: leave every dot hidden rather than guessing colours.
      return DotGlobeGeometry._(unitVectors, out);
    }
    final rgba = byteData.buffer.asUint8List();
    final hideAlpha8 = (hideBelowAlpha.clamp(0.0, 1.0) * 255).round();
    final ll = Float64List(2);
    for (var i = 0; i < pointCount; i++) {
      _latLngOf(i, ll);
      final lat = ll[0];
      final lng = ll[1];
      final u = lng / 360 + 0.5;
      final v = 0.5 - lat / 180;
      // Map to pixel columns/rows; wrap u (modulo width) when seamless,
      // otherwise clamp it. v is always clamped to stay inside the poles.
      var px = (u * width).floor();
      if (wrapLongitude) {
        px %= width;
        if (px < 0) px += width;
      } else {
        px = px.clamp(0, width - 1);
      }
      final py = (v * height).floor().clamp(0, height - 1);
      final o = (py * width + px) * 4;
      final r = rgba[o];
      final g = rgba[o + 1];
      final b = rgba[o + 2];
      final a = rgba[o + 3];
      // Below the alpha cutoff -> hidden (fully transparent ARGB).
      out[i] = a < hideAlpha8 ? 0 : (a << 24) | (r << 16) | (g << 8) | b;
    }
    return DotGlobeGeometry._(unitVectors, out);
  }

  /// Resolves [provider] to a [ui.Image] and delegates to [colorizeFromImage] —
  /// the one-liner for an `AssetImage` / `NetworkImage`.
  ///
  /// Does not mutate this geometry and does not touch the shared cache used by
  /// [load].
  Future<DotGlobeGeometry> colorizedFromImageProvider(
    ImageProvider provider, {
    double hideBelowAlpha = 0.0,
    ImageConfiguration configuration = ImageConfiguration.empty,
  }) async {
    final stream = provider.resolve(configuration);
    final completer = Completer<ui.Image>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        // Remove the listener on the first frame so the stream isn't retained.
        stream.removeListener(listener);
        // Clone so we own a handle independent of the image cache; the caller
        // disposes this clone once sampling is done.
        if (!completer.isCompleted) completer.complete(info.image.clone());
      },
      onError: (Object error, StackTrace? stack) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    final image = await completer.future;
    try {
      return await colorizeFromImage(image, hideBelowAlpha: hideBelowAlpha);
    } finally {
      image.dispose(); // release our cloned handle once sampling is done
    }
  }

  /// Recovers a dot's latitude/longitude (degrees) from its unit vector, writing
  /// `[latDeg, lngDeg]` into [out]. Inverse of the standard axis convention:
  /// `lat = asin(y)`, `lng = atan2(z, -x)` (see [unitVectors]).
  void _latLngOf(int i, Float64List out) {
    final j = i * 3;
    final x = unitVectors[j];
    final y = unitVectors[j + 1];
    final z = unitVectors[j + 2];
    out[0] = math.asin(y.clamp(-1.0, 1.0)) * 180 / math.pi;
    out[1] = math.atan2(z, -x) * 180 / math.pi;
  }

  /// Converts a latitude/longitude (degrees) to a unit sphere vector, written into [out] indices 0–2.
  static void latLngToUnitVector(double latDeg, double lngDeg, Float64List out) {
    final lat = latDeg * math.pi / 180;
    final lng = lngDeg * math.pi / 180;
    final cosLat = math.cos(lat);
    out[0] = -cosLat * math.cos(lng);
    out[1] = math.sin(lat);
    out[2] = cosLat * math.sin(lng);
  }

  /// Single source of truth for the lat/lng → unit-vector projection.
  /// Writes `(x, y, z)` to [out] at indices [offset], [offset]+1, [offset]+2
  /// using the standard axis convention (see [unitVectors]).
  static void _fillVector(
    double latDeg,
    double lngDeg,
    Float32List out,
    int offset,
  ) {
    final lat = latDeg * math.pi / 180;
    final lng = lngDeg * math.pi / 180;
    final cosLat = math.cos(lat);
    out[offset] = -cosLat * math.cos(lng);
    out[offset + 1] = math.sin(lat);
    out[offset + 2] = cosLat * math.sin(lng);
  }
}

/// Current-frame rotation pose, shared between the painter and the marker layout layer
/// to avoid rebuilding widgets on every frame.
class DotGlobeFrame {
  /// Horizontal rotation angle around the Y axis, in radians.
  /// When longitude [lng] is centred in front, phi = π/2 − lng.
  double phi = math.pi / 2;

  /// Pitch angle around the X axis, in radians. Positive values tilt the north pole toward the viewer.
  double theta = 0;

  /// Zoom factor applied around the widget centre. `1.0` is the natural size;
  /// values above magnify the globe (dots, arcs and their stroke widths grow).
  /// Shared with the painters and the marker layout layer like [phi]/[theta].
  double scale = 1.0;

  /// Projects a unit vector (x, y, z) using the current pose.
  /// Results are written to [out]: [0] = rotated x (screen horizontal, sphere radius = 1),
  /// [1] = rotated y (screen vertical, up is positive), [2] = depth z (> 0 faces the viewer).
  void project(double x, double y, double z, Float64List out) {
    final cy = math.cos(phi);
    final sy = math.sin(phi);
    final cx = math.cos(theta);
    final sx = math.sin(theta);
    final x1 = cy * x + sy * z;
    final z1 = -sy * x + cy * z;
    out[0] = x1;
    out[1] = cx * y - sx * z1;
    out[2] = sx * y + cx * z1;
  }
}
