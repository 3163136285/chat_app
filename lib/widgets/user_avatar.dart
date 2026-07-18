import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool online;

  const UserAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.online = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundColor: const Color(0xFF07C160),
          child: Text(
            name.isNotEmpty ? name[0] : '?',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (online)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.25,
              height: size * 0.25,
              decoration: BoxDecoration(
                color: const Color(0xFF07C160),
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(size * 0.125),
              ),
            ),
          ),
      ],
    );
  }
}
