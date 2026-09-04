import 'package:chatdent/utils/clinic_service_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('leaves non-loopback Evolution URLs unchanged', () {
    expect(
      resolveClinicServiceUrl(
        'http://192.168.1.20:8080',
        'http://192.168.1.20:8095',
      ),
      'http://192.168.1.20:8080',
    );
  });

  test('rewrites localhost Evolution to the PocketBase LAN host', () {
    expect(
      resolveClinicServiceUrl(
        'http://localhost:8080',
        'http://192.168.1.20:8095',
      ),
      'http://192.168.1.20:8080',
    );
  });

  test('keeps localhost when login is also localhost (clinic PC)', () {
    expect(
      resolveClinicServiceUrl(
        'http://localhost:8080',
        'http://localhost:8095',
      ),
      'http://localhost:8080',
    );
  });

  test('detects loopback server URLs', () {
    expect(isLoopbackServerUrl('http://localhost:8095'), isTrue);
    expect(isLoopbackServerUrl('http://127.0.0.1:8095'), isTrue);
    expect(isLoopbackServerUrl('http://192.168.1.20:8095'), isFalse);
  });
}
