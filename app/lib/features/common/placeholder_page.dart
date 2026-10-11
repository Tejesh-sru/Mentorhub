import 'package:flutter/material.dart';

import '../../core/widgets.dart';

/// Screens that land in later phases. The route + navigation entry already exist.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage(this.title, {super.key, this.phase = 'a later phase'});
  final String title;
  final String phase;

  @override
  Widget build(BuildContext context) =>
      PageBody(title: title, child: EmptyState(title: 'Coming in $phase', icon: Icons.construction_outlined, message: 'The backend for this screen is already in place.'));
}
