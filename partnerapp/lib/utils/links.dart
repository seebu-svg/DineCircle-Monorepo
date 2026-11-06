/// Guest-facing links — the payloads the venue's printed QR code encodes.
///
/// The public web origin is the one the customer app already shares event pages
/// under (`https://dinecircle.app/events/{id}`), so a venue page follows the
/// same shape. Encoding an absolute `https` URL rather than a bare id matters:
/// a guest scans the code on a table card with the phone's own camera app, which
/// shows text for a bare id and opens the page for a URL.
library;

/// Host of the guest-facing DineCircle web app.
const String publicWebOrigin = 'https://dinecircle.app';

/// Absolute guest URL for one venue's public menu.
///
/// Returns an empty string when there is no venue id, so callers render the
/// placeholder QR instead of encoding `https://dinecircle.app/menu/`.
String venuePublicUrl(String venueId) {
  final id = venueId.trim();
  if (id.isEmpty) return '';
  return '$publicWebOrigin/menu/${Uri.encodeComponent(id)}';
}
