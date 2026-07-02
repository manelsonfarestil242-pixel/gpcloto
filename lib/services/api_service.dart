import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/app_constants.dart';
import '../models/models.dart';

// ─── Custom Exceptions ────────────────────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class NetworkException extends ApiException {
  const NetworkException({required super.message}) : super(statusCode: null);
}

class AuthException extends ApiException {
  const AuthException({required super.message}) : super(statusCode: 401);
}

class NotFoundException extends ApiException {
  const NotFoundException({required super.message}) : super(statusCode: 404);
}

// ─── API Service ──────────────────────────────────────────────────────────────
class ApiService {
  static ApiService? _instance;
  static ApiService get instance => _instance ??= ApiService._();
  ApiService._();

  final _storage = const FlutterSecureStorage();
  final _client = http.Client();

  String get _baseUrl => '${AppConstants.baseUrl}${AppConstants.apiVersion}';

  // ── Headers ──────────────────────────────────────────────────────────────
  Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-App-Version': AppConstants.appVersion,
      'X-Platform': 'flutter',
    };

    if (requireAuth) {
      final token = await _storage.read(key: AppConstants.keyAuthToken);
      if (token == null) {
        throw const AuthException(message: 'Session expirée. Veuillez vous reconnecter.');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // ── Response Handler ─────────────────────────────────────────────────────
  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes);

    Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        message: 'Réponse invalide du serveur',
        statusCode: response.statusCode,
      );
    }

    switch (response.statusCode) {
      case 200:
      case 201:
        return json;
      case 400:
        throw ApiException(
          message: json['message'] ?? 'Données invalides',
          statusCode: 400,
          code: json['code'],
        );
      case 401:
        throw AuthException(
          message: json['message'] ?? 'Session expirée. Veuillez vous reconnecter.',
        );
      case 403:
        throw ApiException(
          message: json['message'] ?? 'Accès refusé',
          statusCode: 403,
        );
      case 404:
        throw NotFoundException(
          message: json['message'] ?? 'Ressource introuvable',
        );
      case 422:
        // Validation errors — extract field messages
        final errors = json['errors'] as Map<String, dynamic>?;
        final messages = errors?.values
            .expand((e) => e is List ? e.cast<String>() : [e.toString()])
            .join(', ') ?? json['message'] ?? 'Erreur de validation';
        throw ApiException(message: messages, statusCode: 422);
      case 429:
        throw ApiException(
          message: 'Trop de requêtes. Veuillez patienter.',
          statusCode: 429,
        );
      case >= 500:
        throw ApiException(
          message: 'Erreur serveur. Réessayez plus tard.',
          statusCode: response.statusCode,
        );
      default:
        throw ApiException(
          message: json['message'] ?? 'Erreur inattendue',
          statusCode: response.statusCode,
        );
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: await _getHeaders(requireAuth: false),
        body: jsonEncode({'phone': phone, 'password': password}),
      ).timeout(AppConstants.connectTimeout);

      final data = _handleResponse(response);

      // Persist tokens securely
      await _storage.write(
        key: AppConstants.keyAuthToken,
        value: data['access_token'] ?? data['token'],
      );
      if (data['refresh_token'] != null) {
        await _storage.write(
          key: AppConstants.keyRefreshToken,
          value: data['refresh_token'],
        );
      }

      return data;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(
        message: 'Impossible de joindre le serveur. Vérifiez votre connexion.',
      );
    }
  }

  Future<void> logout() async {
    try {
      final headers = await _getHeaders();
      await _client.post(
        Uri.parse('$_baseUrl/auth/logout'),
        headers: headers,
      ).timeout(AppConstants.connectTimeout);
    } catch (_) {
      // Even if API fails, clear local tokens
    } finally {
      await _storage.deleteAll();
    }
  }

  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: AppConstants.keyRefreshToken);
      if (refreshToken == null) return false;

      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: await _getHeaders(requireAuth: false),
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(AppConstants.connectTimeout);

      final data = _handleResponse(response);
      await _storage.write(
        key: AppConstants.keyAuthToken,
        value: data['access_token'],
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── User ──────────────────────────────────────────────────────────────────
  Future<UserModel> getProfile() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/user/profile'),
        headers: await _getHeaders(),
      ).timeout(AppConstants.receiveTimeout);

      final data = _handleResponse(response);
      return UserModel.fromJson(data['user'] ?? data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Impossible de charger le profil.');
    }
  }

  Future<UserModel> updateProfile(Map<String, dynamic> updates) async {
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/user/profile'),
        headers: await _getHeaders(),
        body: jsonEncode(updates),
      ).timeout(AppConstants.receiveTimeout);

      final data = _handleResponse(response);
      return UserModel.fromJson(data['user'] ?? data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Impossible de mettre à jour le profil.');
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      throw const ApiException(
        message: 'Le mot de passe doit contenir au moins 6 caractères.',
        statusCode: 422,
      );
    }

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/user/change-password'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': newPassword,
        }),
      ).timeout(AppConstants.receiveTimeout);

      _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Impossible de changer le mot de passe.');
    }
  }

  // ── Tirages ───────────────────────────────────────────────────────────────
  Future<List<TirageModel>> getTirages({String? type, String? date}) async {
    try {
      final queryParams = <String, String>{};
      if (type != null) queryParams['type'] = type;
      if (date != null) queryParams['date'] = date;

      final uri = Uri.parse('$_baseUrl/tirages').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await _client.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(AppConstants.receiveTimeout);

      final data = _handleResponse(response);
      final list = data['data'] ?? data['tirages'] ?? [];
      return (list as List<dynamic>)
          .map((t) => TirageModel.fromJson(t as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Impossible de charger les tirages.');
    }
  }

  Future<TirageModel> getTirage(String id) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/tirages/$id'),
        headers: await _getHeaders(),
      ).timeout(AppConstants.receiveTimeout);

      final data = _handleResponse(response);
      return TirageModel.fromJson(data['tirage'] ?? data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Impossible de charger ce tirage.');
    }
  }

  // ── Tickets ───────────────────────────────────────────────────────────────
  Future<TicketModel> createTicket({
    required String tirageId,
    required List<MiseModel> mises,
  }) async {
    // Client-side validation
    if (mises.isEmpty) {
      throw const ApiException(
        message: 'Ajoutez au moins une mise avant de valider.',
        statusCode: 422,
      );
    }
    if (mises.length > AppConstants.maxBetsPerTicket) {
      throw ApiException(
        message: 'Maximum ${AppConstants.maxBetsPerTicket} mises par ticket.',
        statusCode: 422,
      );
    }
    for (final mise in mises) {
      if (mise.montant < AppConstants.minBetAmount) {
        throw ApiException(
          message: 'Mise minimale: ${AppConstants.minBetAmount} HTG.',
          statusCode: 422,
        );
      }
      if (mise.montant > AppConstants.maxBetAmount) {
        throw ApiException(
          message: 'Mise maximale: ${AppConstants.maxBetAmount} HTG.',
          statusCode: 422,
        );
      }
    }

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/tickets'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'tirage_id': tirageId,
          'mises': mises.map((m) => m.toJson()).toList(),
        }),
      ).timeout(AppConstants.receiveTimeout);

      final data = _handleResponse(response);
      return TicketModel.fromJson(data['ticket'] ?? data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Impossible de créer le ticket. Réessayez.');
    }
  }

  Future<TicketModel> getTicket(String code) async {
    if (code.trim().isEmpty) {
      throw const ApiException(
        message: 'Entrez un code de ticket valide.',
        statusCode: 422,
      );
    }

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/tickets/${code.trim().toUpperCase()}'),
        headers: await _getHeaders(),
      ).timeout(AppConstants.receiveTimeout);

      final data = _handleResponse(response);
      return TicketModel.fromJson(data['ticket'] ?? data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Impossible de vérifier le ticket.');
    }
  }

  Future<List<TicketModel>> getTickets({
    int page = 1,
    String? statut,
    String? tirageType,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': AppConstants.defaultPageSize.toString(),
      };
      if (statut != null) queryParams['statut'] = statut;
      if (tirageType != null) queryParams['tirage_type'] = tirageType;
      if (dateFrom != null) queryParams['date_from'] = dateFrom;
      if (dateTo != null) queryParams['date_to'] = dateTo;

      final response = await _client.get(
        Uri.parse('$_baseUrl/tickets').replace(queryParameters: queryParams),
        headers: await _getHeaders(),
      ).timeout(AppConstants.receiveTimeout);

      final data = _handleResponse(response);
      final list = data['data'] ?? data['tickets'] ?? [];
      return (list as List<dynamic>)
          .map((t) => TicketModel.fromJson(t as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Impossible de charger les tickets.');
    }
  }

  Future<bool> cancelTicket(String ticketId) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/tickets/$ticketId/annuler'),
        headers: await _getHeaders(),
      ).timeout(AppConstants.receiveTimeout);

      _handleResponse(response);
      return true;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Impossible d\'annuler ce ticket.');
    }
  }

  // ── Résultats ─────────────────────────────────────────────────────────────
  Future<List<TirageModel>> getResultats({String? type, String? date}) async {
    try {
      final queryParams = <String, String>{};
      if (type != null) queryParams['type'] = type;
      if (date != null) queryParams['date'] = date;

      final response = await _client.get(
        Uri.parse('$_baseUrl/resultats').replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
        ),
        headers: await _getHeaders(),
      ).timeout(AppConstants.receiveTimeout);

      final data = _handleResponse(response);
      final list = data['data'] ?? data['resultats'] ?? [];
      return (list as List<dynamic>)
          .map((t) => TirageModel.fromJson(t as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Impossible de charger les résultats.');
    }
  }

  // ── Stats / Dashboard ─────────────────────────────────────────────────────
  Future<StatsModel> getStats({String? dateFrom, String? dateTo}) async {
    try {
      final queryParams = <String, String>{};
      if (dateFrom != null) queryParams['date_from'] = dateFrom;
      if (dateTo != null) queryParams['date_to'] = dateTo;

      final response = await _client.get(
        Uri.parse('$_baseUrl/stats').replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
        ),
        headers: await _getHeaders(),
      ).timeout(AppConstants.receiveTimeout);

      final data = _handleResponse(response);
      return StatsModel.fromJson(data['stats'] ?? data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Impossible de charger les statistiques.');
    }
  }

  // ── Admin: Users ──────────────────────────────────────────────────────────
  Future<List<UserModel>> getUsers({int page = 1, String? role}) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': AppConstants.defaultPageSize.toString(),
      };
      if (role != null) queryParams['role'] = role;

      final response = await _client.get(
        Uri.parse('$_baseUrl/admin/users').replace(queryParameters: queryParams),
        headers: await _getHeaders(),
      ).timeout(AppConstants.receiveTimeout);

      final data = _handleResponse(response);
      final list = data['data'] ?? data['users'] ?? [];
      return (list as List<dynamic>)
          .map((u) => UserModel.fromJson(u as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Impossible de charger les utilisateurs.');
    }
  }

  Future<UserModel> createUser(Map<String, dynamic> userData) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/admin/users'),
        headers: await _getHeaders(),
        body: jsonEncode(userData),
      ).timeout(AppConstants.receiveTimeout);

      final data = _handleResponse(response);
      return UserModel.fromJson(data['user'] ?? data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Impossible de créer l\'utilisateur.');
    }
  }

  Future<bool> toggleUserStatus(String userId) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/admin/users/$userId/toggle-status'),
        headers: await _getHeaders(),
      ).timeout(AppConstants.receiveTimeout);

      _handleResponse(response);
      return true;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Impossible de modifier l\'utilisateur.');
    }
  }

  void dispose() {
    _client.close();
  }
}
