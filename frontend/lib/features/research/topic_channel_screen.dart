import 'package:flutter/material.dart';

class TopicChannelScreen extends StatelessWidget {
  final Map<String, dynamic> topic;
  const TopicChannelScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Topic Channel — Coming Soon')));
  }
}
