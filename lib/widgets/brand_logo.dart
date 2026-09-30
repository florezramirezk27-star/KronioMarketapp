import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final double size;

  const BrandLogo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/logo.png'),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: const SizedBox.shrink(),
    );
  }
}
