import 'package:file_cast/data/models/user_model.dart';
import 'package:file_cast/presentation/widgets/custom_appbar.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final UserModel user = UserModel(
      nombreCompleto: 'Alberto Orlando Paredes Mamani',
    );
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            CustomAppbar(
              user: user,
              countNoti: 2,
            ),
          ],
        ),
      ),
    );
  }
}
