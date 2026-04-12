import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'api_service_v2.dart' as api;
import 'main.dart';

/// Main Trip Summary Page — displays trip details, map, stats, and insights
class TripSummaryPage extends StatefulWidget {
  final String tripId;
  final String userId;
  final api.ApiService apiService;
  final api.Trip? initialTrip;
  final String appName;
  final String appUrl;

  const TripSummaryPage({
    super.key,
    required this.tripId,
    required this.userId,
    required this.apiService,
    this.initialTrip,
    this.appName = 'Walking Buddy',
    this.appUrl = 'https://walkingbuddy.app',
  });

  @override
  State<TripSummaryPage> createState() => _TripSummaryPageState();
}

class _TripSummaryPageState extends State<TripSummaryPage> {
  api.Trip? _trip;
  bool _loading = true;
  String? _error;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _mapAvailable = true;
  bool _usingFallback = false;

  int _commutersToday = 0;
  int _tripsThisMonth = 0;

  double? _distance;
  String? _distanceText;
  String? _duration;
  int? _stops;

  @override
  void initState() {
    super.initState();
    _mapAvailable = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (widget.initialTrip != null) {
      _trip = widget.initialTrip;
      _loading = false;
      _loadMapData();
      _loadInsightData();
    } else {
      _loadTripData();
    }
  }

  Future<void> _loadTripData() async {
    try {
      // Fetch trip from backend
      final trip = await widget.apiService.fetchTrip(widget.tripId);

      if (!mounted) return;

      if (trip == null) {
        setState(() => _error = 'Trip not found');
        return;
      }

      // Verify trip belongs to current user
      if (trip.userId != widget.userId) {
        setState(() => _error = 'Unauthorized');
        return;
      }

      setState(() {
        _trip = trip;
        _loading = false;
      });

      _loadMapData();
      _loadInsightData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error loading trip: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool _hasUsableCoordinates(api.Trip trip) {
    return ![
      trip.startLat,
      trip.startLng,
      trip.endLat,
      trip.endLng,
    ].any((value) => value == 0.0);
  }

  Future<void> _resolveCoordinatesIfNeeded() async {
    if (_trip == null || _hasUsableCoordinates(_trip!)) return;

    final results = await Future.wait([
      widget.apiService.geocodePlace(_trip!.startName),
      widget.apiService.geocodePlace(_trip!.endName),
    ]);

    if (!mounted) return;
    final start = results[0];
    final end = results[1];
    if (start == null || end == null) return;

    setState(() {
      _trip = api.Trip(
        id: _trip!.id,
        userId: _trip!.userId,
        transportMode: _trip!.transportMode,
        startName: _trip!.startName,
        startLat: start.lat,
        startLng: start.lng,
        endName: _trip!.endName,
        endLat: end.lat,
        endLng: end.lng,
        routeName: _trip!.routeName,
        submittedAt: _trip!.submittedAt,
      );
    });
  }

  String _toDirectionsMode(String transportMode) {
    switch (transportMode.toLowerCase()) {
      case 'auto':
        return 'driving';
      case 'train':
      case 'metro':
        return 'transit';
      default:
        return 'transit';
    }
  }

  Future<void> _loadMapData() async {
    if (_trip == null) return;

    if (!_hasUsableCoordinates(_trip!)) {
      await _resolveCoordinatesIfNeeded();
      if (_trip == null || !_hasUsableCoordinates(_trip!)) {
        return;
      }
    }

    final hasUsableCoordinates = _hasUsableCoordinates(_trip!);

    if (!hasUsableCoordinates) {
      return;
    }

    // Initialize map markers
    _addMarkers();

    // Try to get directions from Google Directions API
    final directions = await widget.apiService.fetchDirections(
      _trip!.startLat,
      _trip!.startLng,
      _trip!.endLat,
      _trip!.endLng,
      _toDirectionsMode(_trip!.transportMode),
    );

    if (!mounted) return;

    if (directions != null && directions.routes.isNotEmpty) {
      // Use real directions from API
      final route = directions.routes.first;
      if (route.legs.isNotEmpty) {
        final leg = route.legs.first;
        final transitSteps =
            leg.steps.where((s) => s.travelMode.toUpperCase() == 'TRANSIT');
        final summedTransitStops = transitSteps.fold<int>(
          0,
          (sum, step) => sum + (step.transitStops ?? 0),
        );

        setState(() {
          _distance = leg.distance.valueKm;
          _distanceText = leg.distance.text;
          _duration = leg.duration.text;
          _stops = _toDirectionsMode(_trip!.transportMode) == 'transit'
              ? (summedTransitStops > 0
                  ? summedTransitStops
                  : transitSteps.length)
              : leg.steps.length;
        });
      }

      // Draw route polyline
      final polylinePoints = route.points;
      if (polylinePoints.isNotEmpty) {
        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: polylinePoints.map((p) => LatLng(p.lat, p.lng)).toList(),
              color: const Color(0xFF1D9E75), // #1D9E75 green
              width: 5,
            ),
          };
        });
      }
    } else {
      // Fallback to straight line with toast
      _addFallbackPolyline();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exact route unavailable — showing estimated path.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _addMarkers() {
    if (_trip == null) return;

    _markers = {
      Marker(
        markerId: const MarkerId('start'),
        position: LatLng(_trip!.startLat, _trip!.startLng),
        infoWindow: InfoWindow(title: _trip!.startName),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
      ),
      Marker(
        markerId: const MarkerId('end'),
        position: LatLng(_trip!.endLat, _trip!.endLng),
        infoWindow: InfoWindow(title: _trip!.endName),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueMagenta,
        ),
      ),
    };
  }

  void _addFallbackPolyline() {
    if (_trip == null) return;

    // Draw straight line between start and end
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [
            LatLng(_trip!.startLat, _trip!.startLng),
            LatLng(_trip!.endLat, _trip!.endLng),
          ],
          color: const Color(0xFF1D9E75), // #1D9E75 green
          width: 5,
        ),
      };

      _usingFallback = true;

      // Calculate straight-line distance using Haversine formula
      _distance = api.ApiService.calculateHaversineDistance(
        _trip!.startLat,
        _trip!.startLng,
        _trip!.endLat,
        _trip!.endLng,
      );
      _distanceText = '${_distance!.toStringAsFixed(1)} km approx.';
      _duration = null;

      _stops = null;
    });
  }

  Future<void> _loadInsightData() async {
    try {
      final commuters = await widget.apiService.fetchCommutorsOnRoute(
        _trip!.routeName,
        _trip!.submittedAt,
      );
      final trips = await widget.apiService.fetchUserTripsThisMonth();

      if (!mounted) return;
      setState(() {
        _commutersToday = commuters;
        _tripsThisMonth = trips;
      });
    } catch (e) {
      // Silently fail for insights
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_trip != null) {
      _fitBounds();
    }
  }

  void _fitBounds() {
    if (_mapController == null || _trip == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        min(_trip!.startLat, _trip!.endLat),
        min(_trip!.startLng, _trip!.endLng),
      ),
      northeast: LatLng(
        max(_trip!.startLat, _trip!.endLat),
        max(_trip!.startLng, _trip!.endLng),
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  Future<void> _shareJourney() async {
    if (_trip == null) return;

    final message =
        'I just traveled from ${_trip!.startName} to ${_trip!.endName} on ${_trip!.routeName}. '
        'Tracked with ${widget.appName}. ${widget.appUrl}';

    try {
      await Share.share(message);
    } catch (e) {
      // Fallback to clipboard
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: message));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied to clipboard',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: DC.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: DC.pageBgOf(context),
        body: Center(
          child: CircularProgressIndicator(
            color: DC.blue,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (_error != null || _trip == null) {
      return Scaffold(
        backgroundColor: DC.pageBgOf(context),
        body: Center(
          child: AppCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: DC.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error ?? 'Trip not found',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: DC.bodyOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DC.pageBgOf(context),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trip header
              _buildTripHeader(),
              const SizedBox(height: 16),

              // Map container
              _buildMapContainer(),
              const SizedBox(height: 16),

              // Stats cards
              _buildStatsCards(),
              const SizedBox(height: 16),

              // Insight cards
              _buildInsightCards(),
              const SizedBox(height: 16),

              // Share button
              _buildShareButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripHeader() {
    final dateStr = _formatDate(_trip!.submittedAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateStr,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: DC.mutedOf(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _trip!.routeName,
          style: GoogleFonts.barlow(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: DC.titleOf(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_trip!.startName} → ${_trip!.endName}',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: DC.bodyOf(context),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final weekday = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ][date.weekday - 1];
    final month = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ][date.month];
    return '$weekday, ${date.day} $month ${date.year}';
  }

  Widget _buildMapContainer() {
    final canRenderGoogleMap =
        _mapAvailable && _trip != null && _hasUsableCoordinates(_trip!);

    return AppCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 300,
          child: canRenderGoogleMap
              ? GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      (_trip!.startLat + _trip!.endLat) / 2,
                      (_trip!.startLng + _trip!.endLng) / 2,
                    ),
                    zoom: 13,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: _onMapCreated,
                  zoomControlsEnabled: true,
                  myLocationButtonEnabled: false,
                  compassEnabled: true,
                )
              : Container(
                  color: DC.surfaceOf(context),
                  child: _buildRoutePreview(),
                ),
        ),
      ),
    );
  }

  Widget _buildRoutePreview() {
    if (_trip == null) {
      return Center(
        child: Text(
          'Map unavailable. Here is your trip summary:',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: DC.bodyOf(context),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _RoutePreviewPainter(isDark: DC.isDark(context)),
          ),
        ),
        Positioned(
          left: 22,
          top: 18,
          child: _MiniTag(
            label: 'Start',
            value: _trip!.startName,
            color: const Color(0xFF0F766E),
          ),
        ),
        Positioned(
          right: 22,
          bottom: 18,
          child: _MiniTag(
            label: 'End',
            value: _trip!.endName,
            color: const Color(0xFF6D28D9),
            alignRight: true,
          ),
        ),
        Positioned(
          left: 88,
          top: 98,
          child: _StopDot(color: const Color(0xFF0F766E), label: '1'),
        ),
        Positioned(
          left: 184,
          top: 148,
          child: _StopDot(color: DC.blue, label: '2'),
        ),
        Positioned(
          right: 116,
          top: 106,
          child: _StopDot(color: const Color(0xFF6D28D9), label: '3'),
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Distance',
            value: _distanceText ??
                (_distance != null
                    ? '${_distance!.toStringAsFixed(1)} km${_usingFallback ? ' approx.' : ''}'
                    : '—'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            label: 'Duration',
            value: _duration ?? '—',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            label: 'Stops',
            value: _stops?.toString() ?? '—',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({required String label, required String value}) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.barlow(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DC.titleOf(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: DC.mutedOf(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCards() {
    return Column(
      children: [
        _buildInsightCard(
          title: _commutersToday == 0
              ? 'Be the first'
              : '${_commutersToday} commuters',
          subtitle: _commutersToday == 0
              ? 'Be the first to report on this route today.'
              : 'traveled this route today. Your feedback has been added to this route\'s weekly report.',
          icon: Icons.people_outline_rounded,
        ),
        const SizedBox(height: 10),
        _buildInsightCard(
          title:
              _tripsThisMonth == 1 ? 'First trip' : '${_tripsThisMonth}th trip',
          subtitle: _tripsThisMonth == 1
              ? 'This is your first trip logged this month — great start.'
              : 'This is your ${_tripsThisMonth}th trip logged this month.',
          icon: Icons.trending_up_rounded,
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DC.blueLightOf(context),
              ),
              child: Icon(icon, color: DC.blue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DC.bodyOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: DC.mutedOf(context),
                      height: 1.4,
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

  Widget _buildShareButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: DC.blue,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: DC.blue.withOpacity(0.35),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _shareJourney,
        icon: const Icon(Icons.share_rounded, size: 18),
        label: Text(
          'Share my journey',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool alignRight;

  const _MiniTag({
    required this.label,
    required this.value,
    required this.color,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopDot extends StatelessWidget {
  final Color color;
  final String label;

  const _StopDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutePreviewPainter extends CustomPainter {
  final bool isDark;

  const _RoutePreviewPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = isDark ? const Color(0xFF1A2531) : const Color(0xFFEAF1E8)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, bg);

    final overlay = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.03)
      ..style = PaintingStyle.fill;

    final blocks = [
      Rect.fromLTWH(size.width * 0.10, size.height * 0.18, 78, 44),
      Rect.fromLTWH(size.width * 0.22, size.height * 0.28, 118, 42),
      Rect.fromLTWH(size.width * 0.39, size.height * 0.14, 92, 52),
      Rect.fromLTWH(size.width * 0.58, size.height * 0.24, 138, 48),
      Rect.fromLTWH(size.width * 0.67, size.height * 0.52, 118, 60),
      Rect.fromLTWH(size.width * 0.30, size.height * 0.56, 102, 42),
    ];
    for (final rect in blocks) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)), overlay);
    }

    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.70)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.62,
        size.width * 0.44,
        size.height * 0.50,
        size.width * 0.56,
        size.height * 0.44,
      )
      ..cubicTo(
        size.width * 0.66,
        size.height * 0.38,
        size.width * 0.74,
        size.height * 0.34,
        size.width * 0.82,
        size.height * 0.32,
      );

    final routePaint = Paint()
      ..color = const Color(0xFF1D9E75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, routePaint);

    final startPaint = Paint()..color = const Color(0xFF0F766E);
    final endPaint = Paint()..color = const Color(0xFF6D28D9);
    canvas.drawCircle(
        Offset(size.width * 0.18, size.height * 0.70), 8, startPaint);
    canvas.drawCircle(
        Offset(size.width * 0.82, size.height * 0.32), 8, endPaint);

    final midPaint = Paint()..color = const Color(0xFF22C55E);
    canvas.drawCircle(
        Offset(size.width * 0.39, size.height * 0.56), 5, midPaint);
    canvas.drawCircle(
        Offset(size.width * 0.63, size.height * 0.42), 5, midPaint);
  }

  @override
  bool shouldRepaint(covariant _RoutePreviewPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
