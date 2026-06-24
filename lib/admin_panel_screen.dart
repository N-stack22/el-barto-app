import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'seed_restaurante_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  static const Color negro = Color(0xFF050505);
  static const Color amarillo = Color(0xFFFFC928);
  static const Color fondo = Color(0xFFF5F5F2);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _buscarController = TextEditingController();

  bool _loadingLogin = false;
  bool _showPassword = false;
  String? _loginError;
  String _busqueda = '';
  String _categoria = 'Todas';

  CollectionReference<Map<String, dynamic>> get _productosRef =>
      _db.collection(SeedRestauranteService.collectionName);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _buscarController.dispose();
    super.dispose();
  }

  bool _isAdmin(Map<String, dynamic>? data) {
    final rol = data?['rol']?.toString().toLowerCase().trim();
    final rolesRaw = data?['roles'];
    final roles = rolesRaw is List
        ? rolesRaw.map((role) => role.toString().toLowerCase().trim()).toList()
        : <String>[];

    return rol == 'admin' ||
        rol == 'administrador' ||
        roles.contains('admin') ||
        roles.contains('administrador');
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _loginError = 'Ingresa usuario y contrasena.');
      return;
    }

    setState(() {
      _loadingLogin = true;
      _loginError = null;
    });

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      setState(() => _loginError = _authError(e.code));
    } catch (e) {
      setState(() => _loginError = 'No se pudo iniciar sesion: $e');
    } finally {
      if (mounted) setState(() => _loadingLogin = false);
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'El correo no es valido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Usuario o contrasena incorrectos.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta nuevamente mas tarde.';
      default:
        return 'Error de autenticacion: $code';
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
  }

  double _precio(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) => 'S/ ${_precio(value).toStringAsFixed(2)}';

  bool _matchesSearch(Map<String, dynamic> data) {
    final query = _busqueda.toLowerCase();
    final nombre = data['nombre']?.toString().toLowerCase() ?? '';
    final categoria = data['categoria']?.toString().toLowerCase() ?? '';
    final descripcion = data['descripcion']?.toString().toLowerCase() ?? '';

    if (_categoria != 'Todas' && data['categoria']?.toString() != _categoria) {
      return false;
    }

    return query.isEmpty ||
        nombre.contains(query) ||
        categoria.contains(query) ||
        descripcion.contains(query);
  }

  List<String> _categorias(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final categorias =
        docs
            .map((doc) => doc.data()['categoria']?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['Todas', ...categorias];
  }

  Future<void> _toggleField(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String field,
    bool value,
  ) async {
    await doc.reference.update({
      field: value,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteProduct(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('Se eliminara "${data['nombre'] ?? 'Producto'}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await doc.reference.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Producto eliminado.')));
    }
  }

  Future<void> _seedProducts() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await SeedRestauranteService.cargarProductos();
      messenger.showSnackBar(
        SnackBar(content: Text('Carta base cargada: $count productos.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo cargar la carta base: $e')),
      );
    }
  }

  Future<void> _openProductForm({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? <String, dynamic>{};
    final nombreController = TextEditingController(
      text: data['nombre']?.toString() ?? '',
    );
    final categoriaController = TextEditingController(
      text: data['categoria']?.toString() ?? '',
    );
    final descripcionController = TextEditingController(
      text: data['descripcion']?.toString() ?? '',
    );
    final imagenController = TextEditingController(
      text: data['imagenUrl']?.toString() ?? '',
    );
    final precioController = TextEditingController(
      text: data['precio']?.toString() ?? '',
    );
    final precioFamiliarController = TextEditingController(
      text: data['precioFamiliar']?.toString() ?? '',
    );
    final ordenController = TextEditingController(
      text: data['orden']?.toString() ?? '',
    );
    var disponible = data['disponible'] != false;
    var destacado = data['destacado'] == true;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> save() async {
              final nombre = nombreController.text.trim();
              final categoria = categoriaController.text.trim();
              final precio = double.tryParse(precioController.text.trim());
              final precioFamiliarText = precioFamiliarController.text.trim();
              final precioFamiliar = precioFamiliarText.isEmpty
                  ? null
                  : double.tryParse(precioFamiliarText);
              final ordenText = ordenController.text.trim();
              final orden = int.tryParse(ordenText);

              if (nombre.isEmpty || categoria.isEmpty || precio == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Completa nombre, categoria y precio valido.',
                    ),
                  ),
                );
                return;
              }

              if (precioFamiliarText.isNotEmpty && precioFamiliar == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Precio familiar invalido.')),
                );
                return;
              }

              setSheetState(() => saving = true);

              final payload = <String, dynamic>{
                'nombre': nombre,
                'categoria': categoria,
                'descripcion': descripcionController.text.trim(),
                'imagenUrl': imagenController.text.trim(),
                'precio': precio,
                'disponible': disponible,
                'destacado': destacado,
                'orden': orden ?? DateTime.now().millisecondsSinceEpoch,
                'actualizadoEn': FieldValue.serverTimestamp(),
              };

              if (precioFamiliar == null) {
                payload['precioFamiliar'] = FieldValue.delete();
              } else {
                payload['precioFamiliar'] = precioFamiliar;
              }

              if (doc == null) {
                payload['creadoEn'] = FieldValue.serverTimestamp();
                await _productosRef.add(payload);
              } else {
                await doc.reference.set(payload, SetOptions(merge: true));
              }

              if (context.mounted) Navigator.pop(context);
              if (!mounted) return;
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(
                    doc == null ? 'Producto creado.' : 'Producto actualizado.',
                  ),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 18,
                  bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              doc == null
                                  ? 'Nuevo producto'
                                  : 'Editar producto',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _formField(nombreController, 'Nombre'),
                      const SizedBox(height: 10),
                      _formField(categoriaController, 'Categoria'),
                      const SizedBox(height: 10),
                      _formField(
                        descripcionController,
                        'Descripcion',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 10),
                      _formField(imagenController, 'URL de imagen'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _formField(
                              precioController,
                              'Precio',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _formField(
                              precioFamiliarController,
                              'Precio familiar',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _formField(
                        ordenController,
                        'Orden',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Disponible'),
                            selected: disponible,
                            selectedColor: amarillo,
                            onSelected: (value) =>
                                setSheetState(() => disponible = value),
                          ),
                          FilterChip(
                            label: const Text('Destacado'),
                            selected: destacado,
                            selectedColor: amarillo,
                            onSelected: (value) =>
                                setSheetState(() => destacado = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: saving ? null : save,
                          icon: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: const Text('Guardar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _formField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _loginScreen() {
    return Scaffold(
      backgroundColor: fondo,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/logo.png', height: 88),
                    const SizedBox(height: 18),
                    const Text(
                      'Panel administrador',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: negro,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ingresa con tu usuario y contrasena',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Usuario o correo',
                        prefixIcon: Icon(Icons.person_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Contrasena',
                        prefixIcon: const Icon(Icons.lock_rounded),
                        suffixIcon: IconButton(
                          tooltip: _showPassword ? 'Ocultar' : 'Mostrar',
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_loginError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _loginError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _loadingLogin ? null : _login,
                        icon: _loadingLogin
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login_rounded),
                        label: const Text('Entrar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notAdminScreen(User user) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text('Panel administrador'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 54,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Usuario sin permisos de administrador',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sesion actual: ${user.email ?? user.uid}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'En Firestore, asigna rol: admin o agrega admin dentro del arreglo roles del documento usuarios/{uid}.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _adminShell(User user) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text('El Barto Admin'),
        actions: [
          IconButton(
            tooltip: 'Cargar carta base',
            onPressed: _seedProducts,
            icon: const Icon(Icons.cloud_upload_rounded),
          ),
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Producto'),
        backgroundColor: amarillo,
        foregroundColor: negro,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _productosRef.orderBy('orden').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final categorias = _categorias(docs);
          if (!categorias.contains(_categoria)) {
            _categoria = 'Todas';
          }
          final filtrados = docs
              .where((doc) => _matchesSearch(doc.data()))
              .toList();
          final disponibles = docs
              .where((doc) => doc.data()['disponible'] == true)
              .length;
          final destacados = docs
              .where((doc) => doc.data()['destacado'] == true)
              .length;

          return LayoutBuilder(
            builder: (context, constraints) {
              final useTable = constraints.maxWidth >= 1180;
              final horizontalPadding = constraints.maxWidth < 640
                  ? 12.0
                  : 20.0;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            18,
                            horizontalPadding,
                            8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _summaryHeader(
                                total: docs.length,
                                disponibles: disponibles,
                                destacados: destacados,
                                user: user,
                                wide: useTable,
                              ),
                              const SizedBox(height: 14),
                              _filters(categorias),
                            ],
                          ),
                        ),
                      ),
                      if (filtrados.isEmpty)
                        const SliverFillRemaining(
                          child: Center(
                            child: Text('No hay productos para mostrar.'),
                          ),
                        )
                      else if (useTable)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            6,
                            horizontalPadding,
                            90,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _productsTable(filtrados),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            6,
                            horizontalPadding,
                            90,
                          ),
                          sliver: SliverList.separated(
                            itemCount: filtrados.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) =>
                                _productCard(filtrados[index]),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _summaryHeader({
    required int total,
    required int disponibles,
    required int destacados,
    required User user,
    required bool wide,
  }) {
    final stats = [
      _stat('Productos', total.toString(), Icons.restaurant_menu_rounded),
      _stat('Disponibles', disponibles.toString(), Icons.check_circle_rounded),
      _stat('Destacados', destacados.toString(), Icons.star_rounded),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: negro,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: wide
            ? Row(
                children: [
                  Expanded(child: _brandBlock(user)),
                  const SizedBox(width: 16),
                  Flexible(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: stats
                          .map(
                            (item) => Flexible(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: item,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _brandBlock(user),
                  const SizedBox(height: 14),
                  Wrap(spacing: 10, runSpacing: 10, children: stats),
                ],
              ),
      ),
    );
  }

  Widget _brandBlock(User user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Carta del restaurante',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.email ?? 'Administrador',
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 138, maxWidth: 174),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, color: amarillo),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters(List<String> categorias) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final searchWidth = compact ? constraints.maxWidth : 340.0;
        final categoryWidth = compact ? constraints.maxWidth : 280.0;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: searchWidth,
              child: TextField(
                controller: _buscarController,
                decoration: InputDecoration(
                  hintText: 'Buscar producto',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _busqueda.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar',
                          onPressed: () {
                            _buscarController.clear();
                            setState(() => _busqueda = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => _busqueda = value.trim()),
              ),
            ),
            DropdownMenu<String>(
              initialSelection: _categoria,
              width: categoryWidth,
              label: const Text('Categoria'),
              dropdownMenuEntries: categorias
                  .map(
                    (categoria) =>
                        DropdownMenuEntry(value: categoria, label: categoria),
                  )
                  .toList(),
              onSelected: (value) =>
                  setState(() => _categoria = value ?? 'Todas'),
            ),
          ],
        );
      },
    );
  }

  Widget _productsTable(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: SizedBox(
              width: constraints.maxWidth,
              child: DataTable(
                columnSpacing: 28,
                horizontalMargin: 18,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFFFF3C4),
                ),
                columns: const [
                  DataColumn(label: Text('Orden')),
                  DataColumn(label: Text('Producto')),
                  DataColumn(label: Text('Categoria')),
                  DataColumn(label: Text('Precio')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Destacado')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: docs.map((doc) {
                  final data = doc.data();
                  final precioFamiliar = data['precioFamiliar'];
                  final precio = precioFamiliar is num
                      ? '${_money(data['precio'])} / ${_money(precioFamiliar)}'
                      : _money(data['precio']);

                  return DataRow(
                    cells: [
                      DataCell(Text('${data['orden'] ?? ''}')),
                      DataCell(
                        SizedBox(
                          width: 260,
                          child: Text(
                            data['nombre']?.toString() ?? 'Producto',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 210,
                          child: Text(
                            data['categoria']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(precio)),
                      DataCell(
                        Switch(
                          value: data['disponible'] == true,
                          onChanged: (value) =>
                              _toggleField(doc, 'disponible', value),
                        ),
                      ),
                      DataCell(
                        Switch(
                          value: data['destacado'] == true,
                          onChanged: (value) =>
                              _toggleField(doc, 'destacado', value),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Editar',
                              onPressed: () => _openProductForm(doc: doc),
                              icon: const Icon(Icons.edit_rounded),
                            ),
                            IconButton(
                              tooltip: 'Eliminar',
                              onPressed: () => _deleteProduct(doc),
                              icon: const Icon(
                                Icons.delete_rounded,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _productCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final nombre = data['nombre']?.toString() ?? 'Producto';
    final categoria = data['categoria']?.toString() ?? 'Sin categoria';
    final precioFamiliar = data['precioFamiliar'];
    final precio = precioFamiliar is num
        ? '${_money(data['precio'])} / ${_money(precioFamiliar)}'
        : _money(data['precio']);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: amarillo.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${data['orden'] ?? '-'}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        categoria,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  precio,
                  style: const TextStyle(
                    color: negro,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              data['descripcion']?.toString() ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: const Text('Disponible'),
                  selected: data['disponible'] == true,
                  selectedColor: amarillo,
                  onSelected: (value) => _toggleField(doc, 'disponible', value),
                ),
                FilterChip(
                  label: const Text('Destacado'),
                  selected: data['destacado'] == true,
                  selectedColor: amarillo,
                  onSelected: (value) => _toggleField(doc, 'destacado', value),
                ),
                IconButton.filledTonal(
                  tooltip: 'Editar',
                  onPressed: () => _openProductForm(doc: doc),
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton.filledTonal(
                  tooltip: 'Eliminar',
                  onPressed: () => _deleteProduct(doc),
                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (user == null) return _loginScreen();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _db.collection('usuarios').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!_isAdmin(userSnapshot.data?.data())) {
              return _notAdminScreen(user);
            }

            return _adminShell(user);
          },
        );
      },
    );
  }
}
