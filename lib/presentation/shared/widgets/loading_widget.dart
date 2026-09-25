import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator())
      .animate()
      .fadeIn(delay: 150.ms, duration: 200.ms);
}
