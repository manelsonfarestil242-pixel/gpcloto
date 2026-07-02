class AppConstants {
  // App Info
  static const String appName = 'GPCLOTO';
  static const String appFullName = 'GPCLOTO - Loterie Officielle';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Tentez votre chance, changez votre vie';

  // API
  static const String baseUrl = 'https://api.gpcloto.ht';
  static const String apiVersion = '/api/v1';
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Storage Keys
  static const String keyAuthToken = 'gpc_auth_token';
  static const String keyRefreshToken = 'gpc_refresh_token';
  static const String keyUserId = 'gpc_user_id';
  static const String keyUserData = 'gpc_user_data';
  static const String keyOnboardingDone = 'gpc_onboarding_done';
  static const String keyLanguage = 'gpc_language';
  static const String keyPrinterConfig = 'gpc_printer_config';

  // Lottery Types
  static const String lotoType = 'LOTO';
  static const String borlette = 'BORLETTE';
  static const String mariaj = 'MARIAJ';
  static const String lotoMax = 'LOTOMAX';

  // Pagination
  static const int defaultPageSize = 20;

  // Ticket
  static const int maxBetsPerTicket = 50;
  static const double minBetAmount = 5.0;
  static const double maxBetAmount = 10000.0;

  // Tirage schedule (Haiti timezone)
  static const Map<String, List<String>> tirageSchedule = {
    'BORLETTE': ['10:30', '13:00', '16:00', '19:00'],
    'LOTO': ['20:00'],
    'MARIAJ': ['13:00', '19:00'],
    'LOTOMAX': ['21:00'],
  };
}
