import 'dart:convert';
import 'package:http/http.dart' as http;

/// Model for a Trip record from the backend.
class Trip {
  final String id;
  final String userId;
  final String startName;
  final double startLat;
  final double startLng;
  final String endName;
  final double endLat;
  final double endLng;
  final String routeName;
  final DateTime submittedAt;

  const Trip({
    required this.id,
    required this.userId,
    required this.startName,
    required this.startLat,
    required this.startLng,
    required this.endName,
    required this.endLat,
    required this.endLng,
    required this.routeName,
    required this.submittedAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      startName: json['start_name']?.toString() ?? '',
      startLat: (json['start_lat'] as num?)?.toDouble() ?? 0.0,
      startLng: (json['start_lng'] as num?)?.toDouble() ?? 0.0,
      endName: json['end_name']?.toString() ?? '',
      endLat: (json['end_lat'] as num?)?.toDouble() ?? 0.0,
      endLng: (json['end_lng'] as num?)?.toDouble() ?? 0.0,
      routeName: json['route_name']?.toString() ?? '',
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

/// API Service for trip-related backend calls
class ApiService {
  final String baseUrl;
  final String? authToken;

  ApiService({
    required this.baseUrl,
    this.authToken,
  });

  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  /// Fetch a single trip by ID. Returns 404 if not found, 403 if unauthorized.
  Future<Trip?> fetchTrip(String tripId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/trips/$tripId'),
            headers: _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return Trip.fromJson(json);
      } else if (response.statusCode == 404) {
        return null; // Not found
      } else if (response.statusCode == 403) {
        throw Exception('Unauthorized: trip does not belong to this user');
      }
      throw Exception('Failed to fetch trip: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  /// Count commuters who traveled the same route on the same date.
  Future<int> fetchCommutorsOnRoute(String routeName, DateTime date) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final response = await http
          .get(
            Uri.parse('$baseUrl/routes/$routeName/commuters').replace(
              queryParameters: {'date': dateStr},
            ),
            headers: _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return (json['count'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Count trips logged by the current user this month.
  Future<int> fetchUserTripsThisMonth() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startStr = startOfMonth.toIso8601String();

      final response = await http
          .get(
            Uri.parse('$baseUrl/user/trips/monthly'),
            headers: _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return (json['count'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }
}
