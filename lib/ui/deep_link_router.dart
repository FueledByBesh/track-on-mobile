import 'package:flutter/material.dart';

import 'pages/clubs/club_detail_page.dart';
import 'sharedwidgets/profile_page.dart';

/// Central tap-routing for push-notification and in-app-notification
/// deep links. The backend builds `trackon://<kind>/<id>` URIs in
/// `NotificationDispatcher.deepLink(...)`; this class is the sole
/// consumer on the mobile side.
///
/// Call [handle] with the raw string and a [NavigatorState]. Returns
/// true if the link matched a known kind and a route was pushed,
/// false otherwise (caller decides what to do — usually ignore or
/// log).
class DeepLinkRouter {
  DeepLinkRouter._();

  static bool handle(String deepLink, NavigatorState navigator) {
    final uri = Uri.tryParse(deepLink);
    if (uri == null || uri.scheme != 'trackon') return false;

    final host = uri.host;
    final segments = uri.pathSegments;
    // Convention: `trackon://<kind>/<id>` — kind on the host,
    // single-id path. Fall back gracefully if the id is missing.
    final id = segments.isNotEmpty ? segments.first : null;

    switch (host) {
      case 'user':
        if (id == null || id.isEmpty) return false;
        navigator.push(MaterialPageRoute(
          builder: (_) => ProfilePage(userId: id),
        ));
        return true;
      case 'club':
        if (id == null || id.isEmpty) return false;
        navigator.push(MaterialPageRoute(
          builder: (_) => ClubDetailPage(clubId: id),
        ));
        return true;
      // Kinds for posts + challenges + join-requests are emitted by
      // the server already but don't have corresponding top-level
      // pages yet. Leaving them unroutable is safer than guessing
      // wrong — tap just no-ops, and a later chunk can wire them as
      // those destinations land.
      default:
        return false;
    }
  }
}
