import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/app_constants.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _errorMessage;
  bool _isLoading = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isAdmin => _user?.role == 'admin';
  bool get isAgent => _user?.role == 'agent';

  final ApiService _api = ApiService.instance;

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _setError(String? msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Initialize (check existing session) ───────────────────────────────────
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(AppConstants.keyUserData);

      if (userData != null) {
        _user = UserModel.fromJson(jsonDecode(userData) as Map<String, dynamic>);
        _status = AuthStatus.authenticated;
        notifyListeners();

        // Refresh profile in background
        _refreshProfile();
      } else {
        // Try to load from API (token might still be valid)
        final profile = await _api.getProfile();
        await _saveUser(profile);
        _user = profile;
        _status = AuthStatus.authenticated;
      }
    } on AuthException {
      _status = AuthStatus.unauthenticated;
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> _refreshProfile() async {
    try {
      final profile = await _api.getProfile();
      await _saveUser(profile);
      _user = profile;
      notifyListeners();
    } catch (_) {
      // Silent fail — user stays logged in with cached data
    }
  }

  Future<void> _saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.keyUserData,
      jsonEncode(user.toJson()),
    );
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<bool> login({
    required String phone,
    required String password,
  }) async {
    // Input validation
    if (phone.trim().isEmpty) {
      _setError('Entrez votre numéro de téléphone.');
      return false;
    }
    if (password.isEmpty) {
      _setError('Entrez votre mot de passe.');
      return false;
    }

    _setLoading(true);
    _setError(null);

    try {
      final data = await _api.login(phone: phone.trim(), password: password);
      final user = UserModel.fromJson(
        data['user'] as Map<String, dynamic>? ?? data,
      );
      await _saveUser(user);
      _user = user;
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    _setLoading(true);
    try {
      await _api.logout();
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyUserData);
      _user = null;
      _status = AuthStatus.unauthenticated;
      _setLoading(false);
    }
  }

  // ── Update Profile ────────────────────────────────────────────────────────
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    _setLoading(true);
    _setError(null);
    try {
      final updatedUser = await _api.updateProfile(updates);
      await _saveUser(updatedUser);
      _user = updatedUser;
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Change Password ───────────────────────────────────────────────────────
  Future<bool> changePassword({
    required String current,
    required String newPass,
    required String confirm,
  }) async {
    if (newPass != confirm) {
      _setError('Les mots de passe ne correspondent pas.');
      return false;
    }
    if (newPass.length < 6) {
      _setError('Le mot de passe doit contenir au moins 6 caractères.');
      return false;
    }

    _setLoading(true);
    _setError(null);
    try {
      await _api.changePassword(
        currentPassword: current,
        newPassword: newPass,
      );
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
