import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/auth_result.dart';

abstract class BiometricDataSource {
  Future<bool> canAuthenticate();
  Future<AuthResult> authenticate();
}

class BiometricDataSourceImpl implements BiometricDataSource {
  final LocalAuthentication _localAuth;

  BiometricDataSourceImpl({LocalAuthentication? localAuth}) 
      : _localAuth = localAuth ?? LocalAuthentication();

  @override
  Future<bool> canAuthenticate() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<AuthResult> authenticate() async {
    try {
      final isSupported = await canAuthenticate();
      if (!isSupported) {
        return const AuthResult(success: false, message: 'Dispositivo no soporta biometría');
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Por favor, autentícate para acceder a la aplicación',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        return const AuthResult(success: true);
      } else {
        return const AuthResult(success: false, message: 'Autenticación cancelada');
      }
    } on PlatformException catch (e) {
      return AuthResult(success: false, message: 'Error de plataforma: ${e.message}');
    } catch (e) {
      return AuthResult(success: false, message: 'Error desconocido: $e');
    }
  }
}
