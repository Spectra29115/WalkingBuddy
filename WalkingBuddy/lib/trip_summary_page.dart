import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'api_service.dart';
import 'main.dart';

/// Main Trip Summary Page — displays trip details, map, stats, and insights
class TripSummaryPage extends StatefulWidget {
  final String tripId;
  final String userId;
  final ApiService apiService;
  final String appName;
  final String appUrl;

  const TripSummaryPage({
    super.key,
    required this.tripId,
    required this.userId,
    required this.apiService,
    this.appName = 'Walking Buddy',
    this.appUrl = 'https://walkingbuddy.app',
  });

  @override
  State<TripSummaryPage> createState() => _TripSummaryPageState();
}

class _TripSummaryPageState extends State<TripSummaryPage> {
  Trip? _trip;
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
  String? _duration;
  int? _stops;

  @override
  void initState() {
    super.initState();
    _loadTripData();
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

      setState(() => _trip = trip);

      // Load map data in parallel
      await Future.wait([
        _loadMapData(),
        _loadInsightData(),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error loading trip: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMapData() async {
    if (_trip == null) return;

    // Initialize map markers
    _addMarkers();

    // Try to get directions from Google Directions API
    // For now, we'll add a fallback straight-line polyline
    _addFallbackPolyline();
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
    _distance = _calculateHaversineDistance(
      _trip!.startLat,
      _trip!.startLng,
      _trip!.endLat,
      _trip!.endLng,
    );

    _stops = null;
  }

  double _calculateHaversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180.0;

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
      CameraUpdateOptions(bounds: bounds, padding: const EdgeInsets.all(100)),
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
          '${_trip!.startName} · ${_trip!.endName}',
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
    return AppCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 300,
          child: _mapAvailable
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
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 32,
                          color: DC.mutedOf(context),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Map unavailable',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: DC.bodyOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Distance',
            value: _distance != null
                ? '${_distance!.toStringAsFixed(1)} km${_usingFallback ? ' approx.' : ''}'
                : '—',
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
              : 'travelers on this route today. Your feedback has been added to this route\'s weekly report.',
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
