/// Clinic Docker URLs are stored as localhost on the PC. On a phone, that
/// host is the phone itself — rewrite loopback to the PocketBase host used
/// at login (usually the PC's LAN IP).
bool isLoopbackHost(String host) {
  final h = host.toLowerCase().trim();
  return h == 'localhost' ||
      h == '127.0.0.1' ||
      h == '::1' ||
      h == '0.0.0.0' ||
      h == '[::1]';
}

bool isLoopbackServerUrl(String server) {
  final trimmed = server.trim();
  if (trimmed.isEmpty) return false;
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.host.isNotEmpty) {
    return isLoopbackHost(uri.host);
  }
  final lower = trimmed.toLowerCase();
  return lower.contains('localhost') || lower.contains('127.0.0.1');
}

String resolveClinicServiceUrl(String serviceUrl, String loginUrl) {
  final trimmed = serviceUrl.trim();
  if (trimmed.isEmpty) return trimmed;
  final service = Uri.tryParse(trimmed);
  if (service == null || service.host.isEmpty) return trimmed;
  if (!isLoopbackHost(service.host)) return trimmed;
  final login = Uri.tryParse(loginUrl.trim());
  if (login == null || login.host.isEmpty || isLoopbackHost(login.host)) {
    return trimmed;
  }
  return service.replace(host: login.host).toString();
}
