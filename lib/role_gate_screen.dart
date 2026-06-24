import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'motociclista_screen.dart';
import 'restaurante_screen.dart';

class RoleGateScreen extends StatelessWidget {
  const RoleGateScreen({super.key});

  bool _isMotociclista(Map<String, dynamic>? data) {
    final rol = data?['rol']?.toString().toLowerCase().trim();
    final rolesRaw = data?['roles'];
    final roles = rolesRaw is List
        ? rolesRaw.map((e) => e.toString().toLowerCase().trim()).toList()
        : <String>[];

    return rol == 'motociclista' ||
        rol == 'repartidor' ||
        roles.contains('motociclista') ||
        roles.contains('repartidor');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (user == null) {
          return const RestauranteScreen();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final data = snapshot.data?.data();
            if (_isMotociclista(data)) {
              return const MotociclistaScreen();
            }

            return const RestauranteScreen();
          },
        );
      },
    );
  }
}
