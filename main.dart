import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_helper.dart';
import 'api_service_v2.dart' as api;
import 'trip_summary_page_v2.dart';

// Centralized design tokens used by the whole UI.
class DC {
  static const pageBg = Color(0xFFDCEEF7);
  static const cardBg = Color(0xFFF0F7FB);
  static const inputBg = Color(0xFFFFFFFF);

  static const darkPageBg = Color(0xFF0F1720);
  static const darkCardBg = Color(0xFF17222D);
  static const darkInputBg = Color(0xFF223240);

  static const blue = Color(0xFF29ABE2);
  static const blueDark = Color(0xFF1A8FC5);
  static const blueLight = Color(0xFFE8F6FD);

  static const title = Color(0xFF1A1A2E);
  static const body = Color(0xFF3A3A50);
  static const muted = Color(0xFF7A8BA0);
  static const labelBlue = Color(0xFF29ABE2);

  static const darkTitle = Color(0xFFEAF2F8);
  static const darkBody = Color(0xFFD3E0EA);
  static const darkMuted = Color(0xFF9CB0C2);
  static const darkLabelBlue = Color(0xFF7DD3FC);

  static const border = Color(0xFFCCDFEB);
  static const darkBorder = Color(0xFF2C3F51);
  static const darkBlueLight = Color(0xFF18364A);

  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color pageBgOf(BuildContext context) =>
      isDark(context) ? darkPageBg : pageBg;
  static Color cardBgOf(BuildContext context) =>
      isDark(context) ? darkCardBg : cardBg;
  static Color inputBgOf(BuildContext context) =>
      isDark(context) ? darkInputBg : inputBg;
  static Color blueLightOf(BuildContext context) =>
      isDark(context) ? darkBlueLight : blueLight;
  static Color titleOf(BuildContext context) =>
      isDark(context) ? darkTitle : title;
  static Color bodyOf(BuildContext context) =>
      isDark(context) ? darkBody : body;
  static Color mutedOf(BuildContext context) =>
      isDark(context) ? darkMuted : muted;
  static Color labelBlueOf(BuildContext context) =>
      isDark(context) ? darkLabelBlue : labelBlue;
  static Color borderOf(BuildContext context) =>
      isDark(context) ? darkBorder : border;
  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF1D2C39) : Colors.white;
}

class Submission {
  // Domain model for one trip submission row rendered in the table.
  final String id;
  final String fullName;
  final String fromLocation;
  final String destination;
  final String transportMode;
  final double fare;
  final bool crowdProblems;
  final int comfortRating;
  final DateTime createdAt;

  const Submission({
    required this.id,
    required this.fullName,
    required this.fromLocation,
    required this.destination,
    required this.transportMode,
    required this.fare,
    required this.crowdProblems,
    required this.comfortRating,
    required this.createdAt,
  });

  // Creates a UI model from the normalized database row map.
  factory Submission.fromDb(Map<String, dynamic> row) {
    final crowdValue = (row['crowds'] ?? '').toString().toLowerCase();
    return Submission(
      id: (row['id'] ?? '').toString(),
      fullName: (row['name'] ?? '').toString(),
      fromLocation: (row['from'] ?? '').toString(),
      destination: (row['to'] ?? '').toString(),
      transportMode: (row['transport'] ?? '').toString().toLowerCase(),
      fare: (row['distance'] as num?)?.toDouble() ?? 0,
      crowdProblems:
          crowdValue == 'yes' || crowdValue == 'true' || crowdValue == '1',
      comfortRating: (row['comfort'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse((row['timestamp'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class TransOpt {
  // Value object describing one transport option tile.
  final String value;
  final String label;
  final IconData icon;

  const TransOpt(this.value, this.label, this.icon);
}

const transOpts = [
  TransOpt('auto', 'Auto', Icons.directions_car_outlined),
  TransOpt('metro', 'Metro', Icons.directions_subway_outlined),
  TransOpt('train', 'Train', Icons.train_outlined),
];

const impactCategories = [
  'overcrowding',
  'delays',
  'cleanliness',
  'safety',
  'accessibility',
];

const impactStatuses = {
  'under_review': 'Under review',
  'in_progress': 'In progress',
  'resolved': 'Resolved',
};

class ImpactBoardItem {
  final int id;
  final String title;
  final String category;
  final String routeId;
  final String status;
  final int feedbackCount;
  final DateTime dateFirstReported;
  final DateTime updatedAt;
  final String? outcomeText;
  final String? progressNote;
  final bool youReportedThis;
  final bool stillWaiting;

  const ImpactBoardItem({
    required this.id,
    required this.title,
    required this.category,
    required this.routeId,
    required this.status,
    required this.feedbackCount,
    required this.dateFirstReported,
    required this.updatedAt,
    required this.outcomeText,
    required this.progressNote,
    required this.youReportedThis,
    required this.stillWaiting,
  });

  factory ImpactBoardItem.fromDb(Map<String, dynamic> row) {
    final status = (row['status'] ?? 'under_review').toString();
    final firstReported =
        DateTime.tryParse((row['date_first_reported'] ?? '').toString()) ??
            DateTime.now();
    final updated = DateTime.tryParse((row['updated_at'] ?? '').toString()) ??
        DateTime.tryParse((row['created_at'] ?? '').toString()) ??
        firstReported;

    return ImpactBoardItem(
      id: (row['id'] as num?)?.toInt() ?? 0,
      title: (row['title'] ?? '').toString(),
      category: (row['category'] ?? '').toString(),
      routeId: (row['route_id'] ?? '').toString(),
      status: status,
      feedbackCount: (row['feedback_count'] as num?)?.toInt() ?? 0,
      dateFirstReported: firstReported,
      updatedAt: updated,
      outcomeText: row['outcome_text']?.toString(),
      progressNote: row['progress_note']?.toString(),
      youReportedThis: ((row['you_reported_this'] as num?)?.toInt() ?? 0) == 1,
      stillWaiting: status == 'under_review',
    );
  }
}

final mockBoardItems = [
  ImpactBoardItem(
    id: 1,
    title: 'Bus 42 was too crowded on weekday mornings.',
    category: 'overcrowding',
    routeId: 'Route 42',
    status: 'resolved',
    feedbackCount: 148,
    dateFirstReported: DateTime(2025, 1, 12),
    updatedAt: DateTime(2025, 3, 1),
    outcomeText:
        'An additional bus was added to Route 42 on weekday mornings from 7am-9am, starting March 2025.',
    progressNote: null,
    youReportedThis: true,
    stillWaiting: false,
  ),
  ImpactBoardItem(
    id: 2,
    title: 'Metro Blue Line had repeat delays after 8pm.',
    category: 'delays',
    routeId: 'Blue Line',
    status: 'in_progress',
    feedbackCount: 96,
    dateFirstReported: DateTime(2025, 2, 14),
    updatedAt: DateTime(2025, 3, 20),
    outcomeText: null,
    progressNote:
        'Reported to the Municipal Transport Authority on 14 Feb. Awaiting response on revised schedules.',
    youReportedThis: false,
    stillWaiting: false,
  ),
  ImpactBoardItem(
    id: 3,
    title: 'Station entrances near Gate C need better lighting at night.',
    category: 'safety',
    routeId: 'Station C',
    status: 'under_review',
    feedbackCount: 63,
    dateFirstReported: DateTime(2025, 3, 3),
    updatedAt: DateTime(2025, 3, 25),
    outcomeText: null,
    progressNote:
        'Issue bundle was submitted with photos and commuter logs. Initial safety audit is in review.',
    youReportedThis: false,
    stillWaiting: false,
  ),
  ImpactBoardItem(
    id: 4,
    title: 'Bus stop shelter at Park Road has frequent litter overflow.',
    category: 'cleanliness',
    routeId: 'Park Road Stop',
    status: 'under_review',
    feedbackCount: 28,
    dateFirstReported: DateTime(2025, 3, 18),
    updatedAt: DateTime(2025, 3, 27),
    outcomeText: null,
    progressNote:
        'Waiting for sanitation routing confirmation from city services.',
    youReportedThis: false,
    stillWaiting: true,
  ),
];

class ImpactEntry {
  final int id;
  final String title;
  final String category;
  final String routeId;
  final String status;
  final int feedbackCount;
  final DateTime dateFirstReported;
  final String? outcomeText;
  final String? progressNote;
  final DateTime? dateResolved;
  final DateTime createdAt;

  const ImpactEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.routeId,
    required this.status,
    required this.feedbackCount,
    required this.dateFirstReported,
    required this.outcomeText,
    required this.progressNote,
    required this.dateResolved,
    required this.createdAt,
  });

  factory ImpactEntry.fromDb(Map<String, dynamic> row) {
    return ImpactEntry(
      id: (row['id'] as num?)?.toInt() ?? 0,
      title: (row['title'] ?? '').toString(),
      category: (row['category'] ?? '').toString(),
      routeId: (row['route_id'] ?? '').toString(),
      status: (row['status'] ?? 'under_review').toString(),
      feedbackCount: (row['feedback_count'] as num?)?.toInt() ?? 0,
      dateFirstReported:
          DateTime.tryParse((row['date_first_reported'] ?? '').toString()) ??
              DateTime.now(),
      outcomeText: row['outcome_text']?.toString(),
      progressNote: row['progress_note']?.toString(),
      dateResolved: row['date_resolved'] == null
          ? null
          : DateTime.tryParse(row['date_resolved'].toString()),
      createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

// Desktop bootstrap for sqflite ffi and app startup.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Keep app startup resilient if .env is unavailable in some builds.
  }

  // Use FFI database factory only on desktop. Mobile must use native sqflite.
  final isDesktop = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  if (isDesktop) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const DataCollectorApp());
}

class DataCollectorApp extends StatefulWidget {
  // Root app widget: theme + home screen wiring.
  const DataCollectorApp({super.key});

  @override
  State<DataCollectorApp> createState() => _DataCollectorAppState();
}

class _DataCollectorAppState extends State<DataCollectorApp> {
  bool _darkMode = false;
  late final api.ApiService _apiService;

  String _readEnv(String key, {String defaultValue = ''}) {
    final fromDefine = String.fromEnvironment(key, defaultValue: '');
    if (fromDefine.isNotEmpty) return fromDefine;
    final fromDotEnv = dotenv.env[key]?.trim() ?? '';
    if (fromDotEnv.isNotEmpty) return fromDotEnv;
    return defaultValue;
  }

  @override
  void initState() {
    super.initState();
    // Initialize API service with backend URL from environment
    // For now, using a placeholder URL - replace with your actual backend
    _apiService = api.ApiService(
      baseUrl: _readEnv(
        'API_BASE_URL',
        defaultValue: 'http://localhost:3000/api',
      ),
      authToken: _readEnv('API_TOKEN'),
      googleMapsApiKey: _readEnv('GOOGLE_MAPS_API_KEY'),
    );
  }

  void _setDarkMode(bool enabled) {
    setState(() => _darkMode = enabled);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Data Collector',
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        scaffoldBackgroundColor: DC.pageBg,
        colorScheme: const ColorScheme.light(
          primary: DC.blue,
          surface: DC.cardBg,
        ),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: ThemeData(
        scaffoldBackgroundColor: DC.darkPageBg,
        colorScheme: const ColorScheme.dark(
          primary: DC.blue,
          surface: DC.darkCardBg,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      onGenerateRoute: (settings) {
        // Handle trip summary route: /trip/:id/summary
        if (settings.name?.startsWith('/trip/') ?? false) {
          final parts = settings.name!.split('/');
          if (parts.length >= 3 && parts[3] == 'summary') {
            final tripId = parts[2];
            return MaterialPageRoute(
              builder: (_) => TripSummaryPage(
                tripId: tripId,
                userId: 'demo_user', // Replace with actual user ID from auth
                apiService: _apiService,
              ),
            );
          }
        }
        return null;
      },
      home: DataCollectorHome(
        apiService: _apiService,
        isDarkMode: _darkMode,
        onThemeChanged: _setDarkMode,
      ),
    );
  }
}

// Home screen that owns tabs and routes form submissions to records.
class DataCollectorHome extends StatefulWidget {
  final api.ApiService apiService;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const DataCollectorHome({
    super.key,
    required this.apiService,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<DataCollectorHome> createState() => _DataCollectorHomeState();
}

// State for tab switching and shared DB/table refresh coordination.
class _DataCollectorHomeState extends State<DataCollectorHome>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final DatabaseHelper _db = DatabaseHelper();
  final GlobalKey<_SubmissionsTableState> _tableKey =
      GlobalKey<_SubmissionsTableState>();
  final GlobalKey<_ImpactAdminPanelState> _impactKey =
      GlobalKey<_ImpactAdminPanelState>();

  @override
  void initState() {
    // Initializes tab controller and rebuild listener for active tab styling.
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    // Cleans up controller resources when leaving the screen.
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Renders title, tabs, and the two tab pages (form + records).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: DC.pageBgOf(context),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      widget.isDarkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: DC.mutedOf(context),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: widget.isDarkMode,
                      onChanged: widget.onThemeChanged,
                      activeThumbColor: DC.blue,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'DATA COLLECTOR',
                style: GoogleFonts.barlow(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: DC.titleOf(context),
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Submit your info and it is saved to the local database',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: DC.mutedOf(context),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PillTab(
                    label: 'Submit Data',
                    active: _tabs.index == 0,
                    onTap: () => _tabs.animateTo(0),
                    filled: true,
                  ),
                  const SizedBox(width: 10),
                  PillTab(
                    label: 'View Records',
                    active: _tabs.index == 1,
                    onTap: () => _tabs.animateTo(1),
                    filled: false,
                  ),
                  const SizedBox(width: 10),
                  PillTab(
                    label: 'Admin Impacts',
                    active: _tabs.index == 2,
                    onTap: () => _tabs.animateTo(2),
                    filled: false,
                  ),
                  const SizedBox(width: 10),
                  PillTab(
                    label: 'Impact Board',
                    active: _tabs.index == 3,
                    onTap: () => _tabs.animateTo(3),
                    filled: false,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: SubmissionForm(
                        dbHelper: _db,
                        apiService: widget.apiService,
                        onSuccess: () {
                          _tableKey.currentState?._fetchData();
                          _tabs.animateTo(1);
                        },
                      ),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: SubmissionsTable(key: _tableKey, dbHelper: _db),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: ImpactAdminPanel(key: _impactKey, dbHelper: _db),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: ImpactBoardPage(
                        dbHelper: _db,
                        currentUserId: 'demo_user',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable rounded tab pill used for the two top actions.
class PillTab extends StatelessWidget {
  final String label;
  final bool active;
  final bool filled;
  final VoidCallback onTap;

  const PillTab({
    super.key,
    required this.label,
    required this.active,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Draws one tab chip and adapts style for active/inactive state.
    final isSolid = filled && active;
    final isOutlineActive = !filled && active;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        decoration: BoxDecoration(
          color: isSolid
              ? DC.blue
              : isOutlineActive
                  ? DC.blueLightOf(context)
                  : DC.surfaceOf(context),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: DC.blue, width: 1.5),
          boxShadow: isSolid
              ? [
                  BoxShadow(
                    color: DC.blue.withOpacity(0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isSolid ? Colors.white : DC.blue,
          ),
        ),
      ),
    );
  }
}

// Form container for creating and saving new trip records.
class SubmissionForm extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final api.ApiService apiService;
  final VoidCallback onSuccess;

  const SubmissionForm({
    super.key,
    required this.dbHelper,
    required this.apiService,
    required this.onSuccess,
  });

  @override
  State<SubmissionForm> createState() => _SubmissionFormState();
}

// Form state: controllers, validation, submit flow, and local UI states.
class _SubmissionFormState extends State<SubmissionForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();
  final _fareCtrl = TextEditingController();

  String _transport = 'auto';
  bool _crowd = false;
  int _comfort = 3;
  bool _loading = false;
  bool _submitted = false;
  bool _locatingPoints = false;
  String? _locationStatus;
  String? _googleApiWarning;
  api.LatLng? _startCoords;
  api.LatLng? _endCoords;
  Timer? _fromSuggestDebounce;
  Timer? _destSuggestDebounce;
  int _fromSuggestReqId = 0;
  int _destSuggestReqId = 0;
  bool _fetchingFromSuggestions = false;
  bool _fetchingDestSuggestions = false;
  List<api.PlaceSuggestion> _fromSuggestions = const [];
  List<api.PlaceSuggestion> _destSuggestions = const [];
  String _fromQuery = '';
  String _destQuery = '';

  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;

  @override
  void initState() {
    // Starts success icon bounce animation used after submit.
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );
    _runGoogleApiHealthCheck();
  }

  Future<void> _runGoogleApiHealthCheck() async {
    final warning = await widget.apiService.checkGoogleMapsAccess();
    if (!mounted) return;
    setState(() {
      _googleApiWarning = warning;
      if (warning != null) {
        _locationStatus = 'Google import is limited until API access is fixed.';
      }
    });
  }

  @override
  void dispose() {
    // Disposes animation and text controllers.
    _fromSuggestDebounce?.cancel();
    _destSuggestDebounce?.cancel();
    _bounceCtrl.dispose();
    _nameCtrl.dispose();
    _fromCtrl.dispose();
    _destCtrl.dispose();
    _routeCtrl.dispose();
    _fareCtrl.dispose();
    super.dispose();
  }

  void _onFromChanged(String value) {
    _startCoords = null;
    _locationStatus = null;
    _fromQuery = value;
    _fromSuggestDebounce?.cancel();
    _fromSuggestDebounce = Timer(
      const Duration(milliseconds: 320),
      () => _fetchSuggestions(value, isFrom: true),
    );
  }

  void _onDestChanged(String value) {
    _endCoords = null;
    _locationStatus = null;
    _destQuery = value;
    _destSuggestDebounce?.cancel();
    _destSuggestDebounce = Timer(
      const Duration(milliseconds: 320),
      () => _fetchSuggestions(value, isFrom: false),
    );
  }

  Future<void> _fetchSuggestions(
    String query, {
    required bool isFrom,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      if (!mounted) return;
      setState(() {
        if (isFrom) {
          _fromSuggestions = const [];
          _fetchingFromSuggestions = false;
        } else {
          _destSuggestions = const [];
          _fetchingDestSuggestions = false;
        }
      });
      return;
    }

    final reqId = isFrom ? ++_fromSuggestReqId : ++_destSuggestReqId;
    if (!mounted) return;
    setState(() {
      if (isFrom) {
        _fetchingFromSuggestions = true;
      } else {
        _fetchingDestSuggestions = true;
      }
    });

    final suggestions = await widget.apiService.searchPlaceSuggestions(trimmed);
    if (!mounted) return;

    if (isFrom) {
      if (reqId != _fromSuggestReqId) return;
      setState(() {
        _fetchingFromSuggestions = false;
        _fromSuggestions = suggestions;
      });

      final shouldAutoImport = trimmed.length >= 4 && _startCoords == null;
      if (shouldAutoImport && reqId == _fromSuggestReqId) {
        final resolved = await widget.apiService.resolvePlaceFromQuery(trimmed);
        if (!mounted || reqId != _fromSuggestReqId) return;

        if (resolved != null) {
          await _selectSuggestion(resolved, isFrom: true);
        }
      }
    } else {
      if (reqId != _destSuggestReqId) return;
      setState(() {
        _fetchingDestSuggestions = false;
        _destSuggestions = suggestions;
      });
    }
  }

  Future<void> _selectSuggestion(
    api.PlaceSuggestion suggestion, {
    required bool isFrom,
  }) async {
    final resolved =
        await widget.apiService.fetchPlaceDetails(suggestion) ?? suggestion;

    if (!mounted) return;

    setState(() {
      if (isFrom) {
        _fromCtrl.text = resolved.formattedAddress.isNotEmpty
            ? resolved.formattedAddress
            : resolved.title;
        _startCoords = resolved.location;
        _fromSuggestions = const [];
        _fromQuery = _fromCtrl.text;
        _fetchingFromSuggestions = false;
      } else {
        _destCtrl.text = resolved.formattedAddress.isNotEmpty
            ? resolved.formattedAddress
            : resolved.title;
        _endCoords = resolved.location;
        _destSuggestions = const [];
        _destQuery = _destCtrl.text;
        _fetchingDestSuggestions = false;
      }

      if (_startCoords != null && _endCoords != null) {
        _locationStatus = 'Imported exact Google Maps place data.';
      } else {
        _locationStatus = isFrom
            ? 'Imported Google Maps start location.'
            : 'Imported Google Maps destination.';
      }
    });
  }

  Widget _buildSuggestionsMenu(
    List<api.PlaceSuggestion> suggestions, {
    required String rawQuery,
    required bool isLoading,
    required Future<void> Function(api.PlaceSuggestion) onTap,
    required VoidCallback onUseTyped,
  }) {
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DC.blue,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Searching similar stations...',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: DC.mutedOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final trimmedQuery = rawQuery.trim();

    if (suggestions.isEmpty && trimmedQuery.length < 2) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: DC.surfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DC.borderOf(context)),
      ),
      child: suggestions.isEmpty
          ? ListTile(
              dense: true,
              leading: Icon(Icons.edit_location_alt_outlined,
                  size: 18, color: DC.blue),
              title: Text(
                'Use "$trimmedQuery"',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DC.bodyOf(context),
                ),
              ),
              subtitle: Text(
                'No close matches found. Continue with typed location.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: DC.mutedOf(context),
                ),
              ),
              onTap: onUseTyped,
            )
          : Column(
              children: suggestions.map((s) {
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.place_outlined, size: 18, color: DC.blue),
                  title: Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: DC.bodyOf(context),
                    ),
                  ),
                  subtitle: Text(
                    s.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: DC.mutedOf(context),
                    ),
                  ),
                  onTap: () => onTap(s),
                );
              }).toList(),
            ),
    );
  }

  Future<void> _submit() async {
    // Validates form, writes to SQLite, shows feedback, then resets fields.
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final now = DateTime.now();
    final routeName = _routeCtrl.text.trim();
    final startName = _fromCtrl.text.trim();
    final endName = _destCtrl.text.trim();

    setState(() {
      _locatingPoints = true;
      _locationStatus = 'Confirming exact points from Google...';
    });

    final startCoords =
        _startCoords ?? await widget.apiService.geocodePlace(startName);
    final endCoords =
        _endCoords ?? await widget.apiService.geocodePlace(endName);

    setState(() {
      _startCoords = startCoords;
      _endCoords = endCoords;
      _locatingPoints = false;
      _locationStatus = (startCoords != null && endCoords != null)
          ? 'Points pinned from Google location data.'
          : 'Could not pinpoint one or both locations. Route may be approximate.';
    });

    final insertedId = await widget.dbHelper.insertWalkEntry({
      'name': _nameCtrl.text.trim(),
      'from': startName,
      'to': endName,
      'route_name': routeName,
      'distance': double.tryParse(_fareCtrl.text.trim()) ?? 0,
      'transport': _transport,
      'crowds': _crowd ? 'Yes' : 'No',
      'comfort': _comfort,
      'timestamp': now.toIso8601String(),
    });

    if (!mounted) return;

    widget.onSuccess();

    final summaryTrip = api.Trip(
      id: insertedId.toString(),
      userId: 'demo_user',
      transportMode: _transport,
      startName: startName,
      startLat: startCoords?.lat ?? 0.0,
      startLng: startCoords?.lng ?? 0.0,
      endName: endName,
      endLat: endCoords?.lat ?? 0.0,
      endLng: endCoords?.lng ?? 0.0,
      routeName: routeName.isEmpty ? _transport.toUpperCase() : routeName,
      submittedAt: now,
    );

    setState(() => _loading = false);

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripSummaryPage(
          tripId: summaryTrip.id,
          userId: summaryTrip.userId,
          apiService: widget.apiService,
          initialTrip: summaryTrip,
          appName: 'Walking Buddy',
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _nameCtrl.clear();
      _fromCtrl.clear();
      _destCtrl.clear();
      _routeCtrl.clear();
      _fareCtrl.clear();
      _transport = 'auto';
      _crowd = false;
      _comfort = 3;
    });
  }

  @override
  Widget build(BuildContext context) =>
      // Switches between the form and temporary success state.
      _submitted ? _successCard() : _formCard();

  Widget _successCard() {
    // Success view shown briefly after a save completes.
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _bounceAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _bounceAnim.value),
                child: child,
              ),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DC.green,
                  boxShadow: [
                    BoxShadow(
                      color: DC.green.withOpacity(0.35),
                      blurRadius: 20,
                      spreadRadius: 3,
                    )
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 38),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Submitted!',
              style: GoogleFonts.barlow(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: DC.titleOf(context),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your trip data is saved.',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: DC.mutedOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formCard() {
    // Main input form section with grouped controls and submit button.
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TRIP DETAILS',
                style: GoogleFonts.barlow(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DC.labelBlueOf(context),
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              const FieldLabel('Full Name', required: true),
              const SizedBox(height: 6),
              AppTextField(
                ctrl: _nameCtrl,
                hint: 'e.g. John Doe',
                maxLen: 100,
                validator: (v) => v!.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('From', required: true),
                        const SizedBox(height: 6),
                        AppTextField(
                          ctrl: _fromCtrl,
                          hint: 'e.g. Central Station',
                          onChanged: _onFromChanged,
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Required' : null,
                        ),
                        _buildSuggestionsMenu(
                          _fromSuggestions,
                          rawQuery: _fromQuery,
                          isLoading: _fetchingFromSuggestions,
                          onTap: (s) => _selectSuggestion(s, isFrom: true),
                          onUseTyped: () {
                            setState(() {
                              _fromCtrl.text = _fromQuery.trim();
                              _startCoords = null;
                              _fromSuggestions = const [];
                              _locationStatus =
                                  'Using typed start location. Route may be approximate.';
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Destination', required: true),
                        const SizedBox(height: 6),
                        AppTextField(
                          ctrl: _destCtrl,
                          hint: 'e.g. Airport',
                          onChanged: _onDestChanged,
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Required' : null,
                        ),
                        _buildSuggestionsMenu(
                          _destSuggestions,
                          rawQuery: _destQuery,
                          isLoading: _fetchingDestSuggestions,
                          onTap: (s) => _selectSuggestion(s, isFrom: false),
                          onUseTyped: () {
                            setState(() {
                              _destCtrl.text = _destQuery.trim();
                              _endCoords = null;
                              _destSuggestions = const [];
                              _locationStatus =
                                  'Using typed destination. Route may be approximate.';
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_googleApiWarning != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _googleApiWarning!,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (_locatingPoints || _locationStatus != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_locatingPoints) ...[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DC.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      Icon(
                        (_startCoords != null && _endCoords != null)
                            ? Icons.location_on_rounded
                            : Icons.info_outline_rounded,
                        size: 14,
                        color: (_startCoords != null && _endCoords != null)
                            ? DC.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        _locationStatus ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: DC.mutedOf(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              const FieldLabel('Route Name'),
              const SizedBox(height: 6),
              AppTextField(
                ctrl: _routeCtrl,
                hint: 'e.g. Kolkata Metro Blue Line',
                maxLen: 120,
                validator: (v) =>
                    v!.trim().isEmpty ? 'Route is required' : null,
              ),
              const SizedBox(height: 14),
              const FieldLabel('Mode of Transport'),
              const SizedBox(height: 10),
              _buildTransportPicker(),
              const SizedBox(height: 14),
              const FieldLabel('Fare (INR)'),
              const SizedBox(height: 6),
              AppTextField(
                ctrl: _fareCtrl,
                hint: 'e.g. 150',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => v!.trim().isEmpty ? 'Fare is required' : null,
              ),
              const SizedBox(height: 14),
              const FieldLabel('Did you face crowd problems?'),
              const SizedBox(height: 10),
              _buildCrowdPicker(),
              const SizedBox(height: 14),
              const FieldLabel('Rate Comfort (1-5)'),
              const SizedBox(height: 10),
              _buildComfortRating(),
              const SizedBox(height: 24),
              _buildSubmitBtn(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransportPicker() {
    // Builds the row of selectable transport mode cards.
    return Row(
      children: transOpts.map((opt) {
        final active = _transport == opt.value;
        final isLast = opt == transOpts.last;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 10),
            child: GestureDetector(
              onTap: () => setState(() => _transport = opt.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 82,
                decoration: BoxDecoration(
                  color:
                      active ? DC.blueLightOf(context) : DC.surfaceOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? DC.blue : DC.borderOf(context),
                    width: active ? 2 : 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(opt.icon,
                        size: 28,
                        color: active ? DC.blue : DC.mutedOf(context)),
                    const SizedBox(height: 6),
                    Text(
                      opt.label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: active ? DC.blue : DC.bodyOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCrowdPicker() {
    // Builds yes/no crowd experience selector pills.
    return Row(
      children: ['yes', 'no'].map((v) {
        final selected = (_crowd ? 'yes' : 'no') == v;
        return Padding(
          padding: EdgeInsets.only(right: v == 'yes' ? 12 : 0),
          child: GestureDetector(
            onTap: () => setState(() => _crowd = v == 'yes'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color:
                    selected ? DC.blueLightOf(context) : DC.surfaceOf(context),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: selected ? DC.blue : DC.borderOf(context),
                  width: selected ? 2 : 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? DC.blue : Colors.transparent,
                      border: Border.all(
                        color: selected ? DC.blue : DC.mutedOf(context),
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? const Center(
                            child: CircleAvatar(
                                radius: 3.5, backgroundColor: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    v[0].toUpperCase() + v.substring(1),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? DC.blue : DC.bodyOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildComfortRating() {
    // Builds comfort score selector with 1-5 circular buttons.
    return Row(
      children: List.generate(5, (i) {
        final n = i + 1;
        final on = _comfort >= n;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _comfort = n),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? DC.blue : DC.surfaceOf(context),
                border: Border.all(
                  color: on ? DC.blue : DC.borderOf(context),
                  width: on ? 0 : 1.5,
                ),
                boxShadow: on
                    ? [
                        BoxShadow(
                          color: DC.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  '$n',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: on ? Colors.white : DC.mutedOf(context),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSubmitBtn() {
    // Primary CTA that triggers form submission and loading state.
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: DC.blue,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: DC.blue.withOpacity(0.35),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _loading ? null : _submit,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : const Icon(Icons.send_rounded, size: 18),
        label: Text(
          _loading ? 'Saving...' : 'Submit Trip',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// Table screen for loading and showing all saved submissions.
class SubmissionsTable extends StatefulWidget {
  final DatabaseHelper dbHelper;

  const SubmissionsTable({super.key, required this.dbHelper});

  @override
  State<SubmissionsTable> createState() => _SubmissionsTableState();
}

// State for loading, empty, and data table render paths.
class _SubmissionsTableState extends State<SubmissionsTable> {
  List<Submission> _data = [];
  bool _loading = true;

  @override
  void initState() {
    // Loads records when the records tab is created.
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    // Reads rows from DB and maps them into UI models.
    final rows = await widget.dbHelper.getWalkEntries();
    if (mounted) {
      setState(() {
        _data = rows.map(Submission.fromDb).toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Chooses loading, empty, or populated table state.
    if (_loading) return _loadingCard();
    if (_data.isEmpty) return _emptyCard();
    return _tableCard();
  }

  Widget _loadingCard() => AppCard(
        // Card with centered spinner while records are loading.
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(
            child: CircularProgressIndicator(color: DC.blue, strokeWidth: 2.5),
          ),
        ),
      );

  Widget _emptyCard() => AppCard(
        // Empty state card shown when no records are present.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DC.blueLightOf(context),
                  border: Border.all(color: DC.borderOf(context), width: 1.5),
                ),
                child: Icon(
                  Icons.inbox_rounded,
                  size: 28,
                  color: DC.mutedOf(context),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No records yet',
                style: GoogleFonts.barlow(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: DC.bodyOf(context),
                ),
              ),
              const SizedBox(height: 6),
              Text('Submit a trip first!',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: DC.mutedOf(context))),
            ],
          ),
        ),
      );

  Widget _tableCard() {
    // Main records card containing horizontally scrollable DataTable.
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TRIP RECORDS  -  ${_data.length}',
              style: GoogleFonts.barlow(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: DC.labelBlueOf(context),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 50,
                dataRowMaxHeight: 50,
                headingRowColor:
                    MaterialStateProperty.all(DC.blueLightOf(context)),
                dividerThickness: 1,
                border: TableBorder.all(
                  color: DC.borderOf(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                headingTextStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: DC.bodyOf(context),
                ),
                dataTextStyle:
                    GoogleFonts.inter(fontSize: 13, color: DC.bodyOf(context)),
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Route')),
                  DataColumn(label: Text('Mode')),
                  DataColumn(label: Text('Fare')),
                  DataColumn(label: Text('Crowd')),
                  DataColumn(label: Text('Rating')),
                  DataColumn(label: Text('Date')),
                ],
                rows: _data.map(_row).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _row(Submission s) {
    // Maps one submission object into a single DataTable row.
    final icon = switch (s.transportMode) {
      'metro' => Icons.directions_subway_outlined,
      'train' => Icons.train_outlined,
      _ => Icons.directions_car_outlined,
    };

    final modeText = s.transportMode.isEmpty
        ? '-'
        : s.transportMode[0].toUpperCase() + s.transportMode.substring(1);

    return DataRow(
      cells: [
        DataCell(Text(s.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(Text('${s.fromLocation} -> ${s.destination}')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: DC.blue),
              const SizedBox(width: 5),
              Text(modeText),
            ],
          ),
        ),
        DataCell(Text('INR ${s.fare.toStringAsFixed(0)}')),
        DataCell(
          s.crowdProblems
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: DC.red),
                    SizedBox(width: 4),
                    Text('Yes', style: TextStyle(color: DC.red)),
                  ],
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: DC.green),
                    SizedBox(width: 4),
                    Text('No', style: TextStyle(color: DC.green)),
                  ],
                ),
        ),
        DataCell(Text('${s.comfortRating}/5')),
        DataCell(
          Text(
            '${s.createdAt.day}/${s.createdAt.month}/${s.createdAt.year}',
            style: TextStyle(color: DC.mutedOf(context), fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class ImpactAdminPanel extends StatefulWidget {
  final DatabaseHelper dbHelper;

  const ImpactAdminPanel({super.key, required this.dbHelper});

  @override
  State<ImpactAdminPanel> createState() => _ImpactAdminPanelState();
}

class _ImpactAdminPanelState extends State<ImpactAdminPanel> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();
  final _feedbackCountCtrl = TextEditingController(text: '0');
  final _outcomeCtrl = TextEditingController();
  final _progressCtrl = TextEditingController();

  String _category = impactCategories.first;
  String _status = 'under_review';
  DateTime _firstReported = DateTime.now();
  int? _editingId;
  bool _saving = false;
  bool _loading = true;
  List<ImpactEntry> _impacts = [];
  List<Submission> _feedbackCandidates = [];
  Set<int> _selectedFeedbackIds = <int>{};

  @override
  void initState() {
    super.initState();
    _fetchImpacts();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _routeCtrl.dispose();
    _feedbackCountCtrl.dispose();
    _outcomeCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchImpacts() async {
    final rows = await widget.dbHelper.getImpacts();
    final feedbackRows = await widget.dbHelper.getWalkEntries();
    if (!mounted) return;
    setState(() {
      _impacts = rows.map(ImpactEntry.fromDb).toList();
      _feedbackCandidates = feedbackRows.map(Submission.fromDb).toList();
      _loading = false;
    });
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _category = impactCategories.first;
      _status = 'under_review';
      _firstReported = DateTime.now();
      _titleCtrl.clear();
      _routeCtrl.clear();
      _feedbackCountCtrl.text = '0';
      _outcomeCtrl.clear();
      _progressCtrl.clear();
      _selectedFeedbackIds = <int>{};
    });
  }

  Future<void> _pickFirstReportedDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _firstReported,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected == null || !mounted) return;
    setState(() => _firstReported = selected);
  }

  Future<void> _saveImpact() async {
    if (!_formKey.currentState!.validate()) return;
    final isEditing = _editingId != null;
    if (_status == 'resolved' && _outcomeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Outcome text is required when status is Resolved.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: DC.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final nowIso = DateTime.now().toIso8601String();
    final resolvedDate = _status == 'resolved' ? nowIso : null;

    final payload = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'category': _category,
      'route_id': _routeCtrl.text.trim(),
      'status': _status,
      'feedback_count': int.tryParse(_feedbackCountCtrl.text.trim()) ?? 0,
      'date_first_reported': _firstReported.toIso8601String(),
      'outcome_text':
          _outcomeCtrl.text.trim().isEmpty ? null : _outcomeCtrl.text.trim(),
      'progress_note':
          _progressCtrl.text.trim().isEmpty ? null : _progressCtrl.text.trim(),
      'date_resolved': resolvedDate,
      'created_at': nowIso,
    };

    if (_editingId == null) {
      _editingId = await widget.dbHelper.insertImpact(payload);
    } else {
      payload.remove('created_at');
      await widget.dbHelper.updateImpact(_editingId!, payload);
    }

    await widget.dbHelper.replaceImpactFeedbackLinks(
      _editingId!,
      _selectedFeedbackIds.toList(),
    );

    if (!mounted) return;
    setState(() => _saving = false);
    await _fetchImpacts();
    if (!mounted) return;
    _resetForm();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditing ? 'Impact updated' : 'Impact created',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: DC.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadForEdit(ImpactEntry impact) async {
    final linkedIds = await widget.dbHelper.getLinkedFeedbackIds(impact.id);
    if (!mounted) return;
    setState(() {
      _editingId = impact.id;
      _titleCtrl.text = impact.title;
      _routeCtrl.text = impact.routeId;
      _feedbackCountCtrl.text = impact.feedbackCount.toString();
      _category = impact.category;
      _status = impact.status;
      _firstReported = impact.dateFirstReported;
      _outcomeCtrl.text = impact.outcomeText ?? '';
      _progressCtrl.text = impact.progressNote ?? '';
      _selectedFeedbackIds = linkedIds.toSet();
    });
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IMPACT ADMIN',
                    style: GoogleFonts.barlow(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: DC.labelBlueOf(context),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _editingId == null
                        ? 'Create impact entry'
                        : 'Editing impact #$_editingId',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: DC.mutedOf(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const FieldLabel('Issue title', required: true),
                  const SizedBox(height: 6),
                  AppTextField(
                    ctrl: _titleCtrl,
                    hint: 'e.g. Bus 42 was too crowded on weekday mornings',
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Title is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel('Category', required: true),
                            const SizedBox(height: 6),
                            _dropdownField(
                              value: _category,
                              items: impactCategories,
                              labeler: (v) =>
                                  v[0].toUpperCase() + v.substring(1),
                              onChanged: (v) => setState(() => _category = v!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel('Status', required: true),
                            const SizedBox(height: 6),
                            _dropdownField(
                              value: _status,
                              items: impactStatuses.keys.toList(),
                              labeler: (v) => impactStatuses[v] ?? v,
                              onChanged: (v) => setState(() => _status = v!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel('Route/Line', required: true),
                            const SizedBox(height: 6),
                            AppTextField(
                              ctrl: _routeCtrl,
                              hint: 'e.g. Route 42',
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Route is required'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel('Feedback count'),
                            const SizedBox(height: 6),
                            AppTextField(
                              ctrl: _feedbackCountCtrl,
                              hint: 'Auto from linked feedback',
                              keyboardType: TextInputType.number,
                              readOnly: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const FieldLabel('Link commuter feedback entries'),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 220),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DC.inputBgOf(context),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: DC.borderOf(context), width: 1.5),
                    ),
                    child: _feedbackCandidates.isEmpty
                        ? Center(
                            child: Text(
                              'No submissions available yet.',
                              style: GoogleFonts.inter(
                                color: DC.mutedOf(context),
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _feedbackCandidates.take(25).length,
                            itemBuilder: (_, i) {
                              final candidate = _feedbackCandidates[i];
                              final id = int.tryParse(candidate.id);
                              if (id == null) return const SizedBox.shrink();
                              final selected =
                                  _selectedFeedbackIds.contains(id);
                              return CheckboxListTile(
                                value: selected,
                                activeColor: DC.blue,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${candidate.fullName} - ${candidate.fromLocation} -> ${candidate.destination}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: DC.bodyOf(context),
                                  ),
                                ),
                                subtitle: Text(
                                  'Submission #$id',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: DC.mutedOf(context),
                                  ),
                                ),
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedFeedbackIds.add(id);
                                    } else {
                                      _selectedFeedbackIds.remove(id);
                                    }
                                    _feedbackCountCtrl.text =
                                        _selectedFeedbackIds.length.toString();
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 14),
                  const FieldLabel('Date first reported', required: true),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickFirstReportedDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: DC.inputBgOf(context),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: DC.borderOf(context), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 16, color: DC.mutedOf(context)),
                          const SizedBox(width: 10),
                          Text(
                            _fmtDate(_firstReported),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: DC.bodyOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const FieldLabel('Outcome text (required when resolved)'),
                  const SizedBox(height: 6),
                  _multiLineField(
                    controller: _outcomeCtrl,
                    hint:
                        'e.g. An additional bus was added to Route 42 from 7am-9am starting March 2025.',
                  ),
                  const SizedBox(height: 14),
                  const FieldLabel('Progress note (for in-progress issues)'),
                  const SizedBox(height: 6),
                  _multiLineField(
                    controller: _progressCtrl,
                    hint:
                        'e.g. Reported to the Municipal Transport Authority on 14 Feb. Awaiting response.',
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DC.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _saving ? null : _saveImpact,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded, size: 18),
                            label: Text(
                              _editingId == null
                                  ? 'Create Impact'
                                  : 'Update Impact',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: DC.borderOf(context)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _resetForm,
                          child: Text(
                            'Clear',
                            style: GoogleFonts.inter(
                              color: DC.bodyOf(context),
                              fontWeight: FontWeight.w600,
                            ),
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
        const SizedBox(height: 14),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(
                          color: DC.blue, strokeWidth: 2.5),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RECENT IMPACT ENTRIES',
                        style: GoogleFonts.barlow(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: DC.labelBlueOf(context),
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_impacts.isEmpty)
                        Text(
                          'No impacts yet. Create the first entry above.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: DC.mutedOf(context),
                          ),
                        )
                      else
                        ..._impacts.take(8).map(
                              (impact) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GestureDetector(
                                  onTap: () {
                                    _loadForEdit(impact);
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: DC.surfaceOf(context),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: DC.borderOf(context),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          impact.title,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: DC.bodyOf(context),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${impactStatuses[impact.status] ?? impact.status}  |  ${impact.routeId}  |  ${impact.feedbackCount} reports',
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            color: DC.mutedOf(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _dropdownField({
    required String value,
    required List<String> items,
    required String Function(String) labeler,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      items: items
          .map(
            (v) => DropdownMenuItem<String>(
              value: v,
              child: Text(
                labeler(v),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: DC.bodyOf(context),
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: DC.inputBgOf(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: DC.borderOf(context), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: DC.blue, width: 2),
        ),
      ),
    );
  }

  Widget _multiLineField({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      minLines: 2,
      maxLines: 3,
      style: GoogleFonts.inter(fontSize: 14, color: DC.bodyOf(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.inter(fontSize: 13.5, color: DC.mutedOf(context)),
        filled: true,
        fillColor: DC.inputBgOf(context),
        contentPadding: const EdgeInsets.all(12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: DC.borderOf(context), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: DC.blue, width: 2),
        ),
      ),
    );
  }
}

class ImpactBoardPage extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final String currentUserId;

  const ImpactBoardPage({
    super.key,
    required this.dbHelper,
    required this.currentUserId,
  });

  @override
  State<ImpactBoardPage> createState() => _ImpactBoardPageState();
}

class _ImpactBoardPageState extends State<ImpactBoardPage> {
  bool _loading = true;
  List<ImpactBoardItem> _allItems = [];
  int _totalSubmissions = 0;
  int _issuesActedOn = 0;
  int _contributors = 0;

  String _routeFilter = 'all';
  String _categoryFilter = 'all';
  String _timeFilter = 'all_time';

  @override
  void initState() {
    super.initState();
    _loadBoard();
  }

  Future<void> _loadBoard() async {
    final rows = await widget.dbHelper.getImpactBoardRows(widget.currentUserId);
    final metrics = await widget.dbHelper.getImpactBoardMetrics();
    if (!mounted) return;

    final items = rows.isEmpty
        ? mockBoardItems
        : rows.map(ImpactBoardItem.fromDb).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    setState(() {
      _allItems = items;
      _totalSubmissions = metrics['total_submissions'] ?? 0;
      _issuesActedOn = metrics['issues_acted_on'] ?? 0;
      _contributors = metrics['contributors'] ?? 0;
      _loading = false;
    });
  }

  List<ImpactBoardItem> _filteredItems() {
    final now = DateTime.now();
    DateTime? fromDate;
    if (_timeFilter == 'this_month') {
      fromDate = DateTime(now.year, now.month, 1);
    } else if (_timeFilter == 'last_3_months') {
      fromDate = DateTime(now.year, now.month - 2, 1);
    }

    return _allItems.where((item) {
      final routeOk = _routeFilter == 'all' || item.routeId == _routeFilter;
      final catOk =
          _categoryFilter == 'all' || item.category == _categoryFilter;
      final timeOk = fromDate == null ||
          item.dateFirstReported
              .isAfter(fromDate.subtract(const Duration(days: 1)));
      return routeOk && catOk && timeOk;
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AppCard(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(
            child: CircularProgressIndicator(color: DC.blue, strokeWidth: 2.5),
          ),
        ),
      );
    }

    final filtered = _filteredItems();
    var timelineItems = filtered
        .where(
            (item) => item.status == 'resolved' || item.status == 'in_progress')
        .toList();
    final waitingItems =
        filtered.where((item) => item.status == 'under_review').toList();

    if (timelineItems.isEmpty) {
      final underReviewWithSignal = filtered.firstWhere(
        (item) => item.status == 'under_review' && item.feedbackCount >= 10,
        orElse: () =>
            filtered.isNotEmpty ? filtered.first : mockBoardItems.first,
      );
      timelineItems = [underReviewWithSignal];
    }

    final statusStats = _buildStatusStats(filtered);
    final categoryStats = _buildCategoryStats(filtered);
    final routeOptions = [
      'all',
      ...{for (final i in _allItems) i.routeId}
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IMPACT TRANSPARENCY BOARD',
          style: GoogleFonts.barlow(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: DC.titleOf(context),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                context,
                label: 'Total submissions',
                value: _totalSubmissions.toString(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                context,
                label: 'Issues acted on',
                value: _issuesActedOn.toString(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                context,
                label: 'Commuters contributed',
                value: _contributors.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _filterDropdown(
                  context,
                  label: 'Route',
                  value: _routeFilter,
                  items: routeOptions,
                  display: (v) => v == 'all' ? 'All routes' : v,
                  onChanged: (v) => setState(() => _routeFilter = v!),
                ),
                _filterDropdown(
                  context,
                  label: 'Category',
                  value: _categoryFilter,
                  items: ['all', ...impactCategories],
                  display: (v) => v == 'all'
                      ? 'All categories'
                      : v[0].toUpperCase() + v.substring(1),
                  onChanged: (v) => setState(() => _categoryFilter = v!),
                ),
                _filterDropdown(
                  context,
                  label: 'Time period',
                  value: _timeFilter,
                  items: const ['this_month', 'last_3_months', 'all_time'],
                  display: (v) => switch (v) {
                    'this_month' => 'This month',
                    'last_3_months' => 'Last 3 months',
                    _ => 'All time',
                  },
                  onChanged: (v) => setState(() => _timeFilter = v!),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _statsChartCard(
                context,
                title: 'Status breakdown',
                stats: statusStats,
                colorForKey: (k) => switch (k) {
                  'resolved' => DC.green,
                  'in_progress' => DC.blue,
                  _ => const Color(0xFFF59E0B),
                },
                labelForKey: (k) => impactStatuses[k] ?? k,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statsChartCard(
                context,
                title: 'Category reports',
                stats: categoryStats,
                colorForKey: (_) => DC.blue,
                labelForKey: (k) => k[0].toUpperCase() + k.substring(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timeline',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: DC.mutedOf(context),
                  ),
                ),
                const SizedBox(height: 10),
                ...timelineItems.map((item) => _impactCard(context, item)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STILL WAITING',
                  style: GoogleFonts.barlow(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: DC.labelBlueOf(context),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                if (waitingItems.isEmpty)
                  Text(
                    'No waiting issues for this filter set.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: DC.mutedOf(context),
                    ),
                  )
                else
                  ...waitingItems.map((item) => _impactCard(context, item)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterDropdown(
    BuildContext context, {
    required String label,
    required String value,
    required List<String> items,
    required String Function(String) display,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: DC.mutedOf(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: ValueKey('$label-$value'),
            initialValue: value,
            items: items
                .map(
                  (v) => DropdownMenuItem<String>(
                    value: v,
                    child: Text(
                      display(v),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: DC.bodyOf(context),
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: DC.inputBgOf(context),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: DC.borderOf(context), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: DC.blue, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.barlow(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: DC.titleOf(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: DC.mutedOf(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, int> _buildStatusStats(List<ImpactBoardItem> items) {
    final data = <String, int>{
      'under_review': 0,
      'in_progress': 0,
      'resolved': 0,
    };
    for (final item in items) {
      data[item.status] = (data[item.status] ?? 0) + 1;
    }
    return data;
  }

  Map<String, int> _buildCategoryStats(List<ImpactBoardItem> items) {
    final data = <String, int>{};
    for (final item in items) {
      data[item.category] = (data[item.category] ?? 0) + item.feedbackCount;
    }
    return data;
  }

  Widget _statsChartCard(
    BuildContext context, {
    required String title,
    required Map<String, int> stats,
    required Color Function(String key) colorForKey,
    required String Function(String key) labelForKey,
  }) {
    final maxValue = stats.values.fold<int>(0, (a, b) => a > b ? a : b);

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.barlow(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DC.labelBlueOf(context),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            ...stats.entries.map(
              (entry) {
                final ratio = maxValue == 0 ? 0.0 : entry.value / maxValue;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            labelForKey(entry.key),
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: DC.bodyOf(context),
                            ),
                          ),
                          Text(
                            '${entry.value}',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: DC.bodyOf(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: DC.blueLightOf(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: ratio,
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorForKey(entry.key),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _impactCard(BuildContext context, ImpactBoardItem item) {
    final badgeColor = switch (item.status) {
      'resolved' => DC.green,
      'in_progress' => DC.blue,
      _ => const Color(0xFFF59E0B),
    };

    final statusLabel = impactStatuses[item.status] ?? 'Under review';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DC.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DC.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (item.youReportedThis)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: DC.blueLightOf(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: DC.blue),
                  ),
                  child: Text(
                    'You reported this',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: DC.blue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: DC.bodyOf(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${item.feedbackCount} commuters reported this.',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: DC.blue,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(context, item.routeId),
              _pill(
                context,
                'First reported: ${item.dateFirstReported.day}/${item.dateFirstReported.month}/${item.dateFirstReported.year}',
              ),
              _pill(context, item.category),
            ],
          ),
          const SizedBox(height: 8),
          if (item.status == 'resolved' && item.outcomeText != null)
            Text(
              item.outcomeText!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: DC.bodyOf(context),
                height: 1.35,
              ),
            )
          else if (item.progressNote != null)
            Text(
              item.progressNote!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: DC.bodyOf(context),
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: DC.blueLightOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DC.borderOf(context)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: DC.bodyOf(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  // Shared rounded surface container for content blocks.
  final Widget child;

  const AppCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Builds the card with subtle border and shadow.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: DC.cardBgOf(context),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: DC.borderOf(context).withOpacity(0.6), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(DC.isDark(context) ? 0.25 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class FieldLabel extends StatelessWidget {
  // Label text with optional required asterisk.
  final String text;
  final bool required;

  const FieldLabel(this.text, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    // Renders field caption styling used across the form.
    return RichText(
      text: TextSpan(
        text: text,
        style: GoogleFonts.inter(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: DC.bodyOf(context),
        ),
        children: required
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: DC.blue, fontWeight: FontWeight.w700),
                )
              ]
            : [],
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  // Shared text input widget with consistent border/focus styling.
  final TextEditingController ctrl;
  final String hint;
  final int? maxLen;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final bool readOnly;
  final ValueChanged<String>? onChanged;

  const AppTextField({
    super.key,
    required this.ctrl,
    required this.hint,
    this.maxLen,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Builds one form input field with validation and formatters.
    return TextFormField(
      controller: ctrl,
      maxLength: maxLen,
      readOnly: readOnly,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 14, color: DC.bodyOf(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: DC.mutedOf(context)),
        counterText: '',
        filled: true,
        fillColor: DC.inputBgOf(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: DC.borderOf(context), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: DC.blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: DC.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: DC.red, width: 2),
        ),
      ),
    );
  }
}
