import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'dni_service.dart';

class AuthScreen extends StatefulWidget {
  final bool returnToPrevious;

  const AuthScreen({
    super.key,
    this.returnToPrevious = false,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _dniController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _validatingDni = false;
  String? _errorMessage;
  DniData? _dniData;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dniController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final dni = _dniController.text.trim();

    String? error;

    if (_isLogin) {
      if (email.isEmpty) {
        error = 'Ingresa tu email';
      } else if (password.isEmpty) {
        error = 'Ingresa tu contraseña';
      } else {
        error = await _authService.login(
          email: email,
          password: password,
        );
      }
    } else {
      final confirmPassword = _confirmPasswordController.text;

      if (dni.isEmpty) {
        error = 'Ingresa tu DNI';
      } else if (!DniService.esDniValido(dni)) {
        error = 'El DNI debe tener 8 dígitos válidos';
      } else if (_dniData == null) {
        error = 'Valida tu DNI antes de registrarte';
      } else if (_dniData!.dni != dni) {
        error = 'El DNI no coincide con la validación';
      } else if (email.isEmpty) {
        error = 'Ingresa tu email';
      } else if (password.isEmpty || confirmPassword.isEmpty) {
        error = 'Completa la contraseña y su confirmación';
      } else {
        error = await _authService.register(
          email: email,
          password: password,
          confirmPassword: confirmPassword,
          dni: dni,
          dniData: _dniData,
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    }

    if (error == null && mounted) {
      if (widget.returnToPrevious) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  Future<void> _validarDni() async {
    final dni = _dniController.text.trim();

    if (dni.isEmpty) {
      if (mounted) {
        setState(() => _errorMessage = 'Ingresa un DNI');
      }
      return;
    }

    if (!DniService.esDniValido(dni)) {
      if (mounted) {
        setState(() =>
            _errorMessage = 'El DNI debe tener exactamente 8 números');
      }
      return;
    }

    if (mounted) {
      setState(() {
        _validatingDni = true;
        _errorMessage = null;
        _dniData = null;
      });
    }

    final resultado = await DniService.validarDni(dni);
    final dniEnUso = await _authService.dniExists(dni);

    if (mounted) {
      setState(() {
        _validatingDni = false;
        if (resultado == null) {
          _errorMessage = 'No se encontró información del DNI';
          _dniData = null;
        } else if (dniEnUso) {
          _errorMessage = 'Este DNI ya está registrado';
          _dniData = null;
        } else {
          _dniData = resultado;
          _errorMessage = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.08),
              // Logo/Título
              Text(
                'El Barto',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: const Color(0xFF050505),
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin ? 'Bienvenido de vuelta' : 'Crea tu cuenta',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF111111),
                    ),
              ),
              const SizedBox(height: 40),

              // DNI (solo en registro)
              if (!_isLogin)
                Column(
                  children: [
                    TextField(
                      controller: _dniController,
                      decoration: InputDecoration(
                        labelText: 'DNI',
                        prefixIcon: const Icon(Icons.badge),
                        suffixIcon: _validatingDni
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : _dniData != null
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      onChanged: (value) {
                        if (mounted) {
                          setState(() {
                            _dniData = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _validatingDni ? null : _validarDni,
                        icon: const Icon(Icons.search),
                        label: Text(
                          _dniData != null ? 'DNI Validado' : 'Validar DNI',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _dniData != null
                              ? Colors.green
                              : const Color(0xFF050505),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    if (_dniData != null)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Datos validados:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _dniData!.nombreCompleto,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),

              // Email
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Contraseña
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),

              // Confirmar contraseña (solo en registro)
              if (!_isLogin)
                Column(
                  children: [
                    TextField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirmar contraseña',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              // Mensaje de error
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade400),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              if (_errorMessage != null) const SizedBox(height: 16),

              // Botón principal
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isLoading || (!_isLogin && _dniData == null))
                      ? null
                      : _handleAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF050505),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _isLogin ? 'Iniciar sesión' : 'Registrarse',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Cambiar entre login y registro
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin
                        ? '¿No tienes cuenta? '
                        : '¿Ya tienes cuenta? ',
                    style: const TextStyle(color: Color(0xFF8D5A1B)),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (mounted) {
                        setState(() {
                        _isLogin = !_isLogin;
                        _errorMessage = null;
                        _passwordController.clear();
                        _confirmPasswordController.clear();
                        _dniController.clear();
                        _dniData = null;
                        });
                      }
                    },
                    child: Text(
                      _isLogin ? 'Regístrate' : 'Inicia sesión',
                      style: const TextStyle(
                        color: Color(0xFF5D3517),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
