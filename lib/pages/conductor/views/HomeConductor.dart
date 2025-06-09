import 'package:flutter/material.dart';
import '../widgets/MapaConductorWidget.dart';

class HomeConductor extends StatelessWidget {
  const HomeConductor({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: MapaConductorWidget(),
      ),
    );
  }
}