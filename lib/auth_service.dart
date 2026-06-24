import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dni_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtiene el usuario actual
  User? get currentUser => _auth.currentUser;

  /// Stream del estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<bool> dniExists(String dni) async {
    final query = await _firestore
        .collection('usuarios')
        .where('dni', isEqualTo: dni)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  /// Registra un nuevo usuario con email, contraseña y DNI
  Future<String?> register({
    required String email,
    required String password,
    required String confirmPassword,
    required String dni,
    required DniData? dniData,
  }) async {
    try {
      final trimmedEmail = email.trim();
      final trimmedDni = dni.trim();

      if (trimmedDni.isEmpty) {
        return 'Ingresa tu DNI';
      }

      if (!DniService.esDniValido(trimmedDni)) {
        return 'El DNI debe tener 8 dígitos válidos';
      }

      if (dniData == null) {
        return 'Debes validar tu DNI antes de registrarte';
      }

      if (dniData.dni != trimmedDni) {
        return 'El DNI no coincide con la validación';
      }

      if (trimmedEmail.isEmpty) {
        return 'Ingresa tu email';
      }

      final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+");
      if (!emailRegex.hasMatch(trimmedEmail)) {
        return 'Email inválido';
      }

      if (password.isEmpty || confirmPassword.isEmpty) {
        return 'Completa la contraseña y la confirmación';
      }

      if (password != confirmPassword) {
        return 'Las contraseñas no coinciden';
      }

      if (password.length < 6) {
        return 'La contraseña debe tener al menos 6 caracteres';
      }

      if (await dniExists(trimmedDni)) {
        return 'Ya existe una cuenta registrada con ese DNI';
      }

      // Crear usuario en Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      // Guardar datos del usuario en Firestore
      await _firestore.collection('usuarios').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email.trim(),
        'dni': dniData.dni,
        'nombres': dniData.nombre,
        'apellidoPaterno': dniData.apellidoPaterno,
        'apellidoMaterno': dniData.apellidoMaterno,
        'nombreCompleto': dniData.nombreCompleto,
        'estado': dniData.estado,
        'condicion': dniData.condicion,
        'rol': 'cliente',
        'roles': ['cliente'],
        'fechaRegistro': FieldValue.serverTimestamp(),
      });

      return null; // Sin errores
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'Error al registrar: $e';
    }
  }

  /// Inicia sesión con email y contraseña
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return null; // Sin errores
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'Error desconocido: $e';
    }
  }

  /// Inicia sesión con Google
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        return 'Inicio de Google cancelado';
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _auth.signInWithCredential(credential);

      // Si es un usuario nuevo, guardar datos básicos en Firestore
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        final user = userCredential.user;
        if (user != null) {
          await _firestore.collection('usuarios').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'nombreCompleto': user.displayName ?? '',
            'fotoUrl': user.photoURL ?? '',
            'provider': 'google',
            'rol': 'cliente',
            'roles': ['cliente'],
            'fechaRegistro': FieldValue.serverTimestamp(),
          });
        }
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'Error al iniciar con Google: $e';
    }
  }

  /// Cierra sesión
  Future<void> logout() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  /// Obtiene mensaje de error legible
  String _getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'La contraseña es muy débil';
      case 'email-already-in-use':
        return 'Este email ya está registrado';
      case 'invalid-email':
        return 'Email inválido';
      case 'user-not-found':
        return 'Usuario no encontrado';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde';
      default:
        return 'Error de autenticación: $code';
    }
  }
}
