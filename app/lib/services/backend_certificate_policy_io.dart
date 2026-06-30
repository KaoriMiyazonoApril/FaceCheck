import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

const String _backendHost = '115.120.124.70';
const String _backendCertificatePem = '''
-----BEGIN CERTIFICATE-----
MIIDMDCCAhigAwIBAgIUYLr4ABXfIETosTkry+Um3hy/zZYwDQYJKoZIhvcNAQEL
BQAwHzEdMBsGA1UEAwwUZmFjZWNoZWNrLXNlbGZzaWduZWQwHhcNMjYwNjMwMTIx
MDQ0WhcNMzYwNjI3MTIxMDQ0WjAfMR0wGwYDVQQDDBRmYWNlY2hlY2stc2VsZnNp
Z25lZDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJwKMm52wmHsPaf2
5LeOUzxN/mdgRcTvxI3Zap0TGJ8RyxD8EKtUSY6JNMb84PHxR6o+DqxGqsU1QQoJ
LTSgWKHy80pYDFNyptGY2LB75vt/GH5Ng5dlXR4ICuzB08oLoG1mlH7xncl1aki5
vk6eJ/cZ1JI/etzpt2gdC2JdK9QQmza9efjcqyI3nv/tZ7arXPCA9Mt22ICz88Op
ln+wenqO8KKtRe7561yd+/laWkbfqYBnDsmvVWWkfAUUOX/PV0g1v67QNXGERVUy
HqWwxeWyidOfMEhTjXcFEtgFpIzAxgV8ceZhME500tOSXuMTO7YOqLusQDkqbOKT
D4dBlasCAwEAAaNkMGIwHQYDVR0OBBYEFJz5vgH+cMXC19w1uNSobdOb+FRyMB8G
A1UdIwQYMBaAFJz5vgH+cMXC19w1uNSobdOb+FRyMA8GA1UdEwEB/wQFMAMBAf8w
DwYDVR0RBAgwBocEc3h8RjANBgkqhkiG9w0BAQsFAAOCAQEAlrD0YCayT4ngoTSD
9Gd99mhNAAwzhhNh30Iq8VJxcq0EKzpYNHYS1+xDb7DOBA4Iek+QhumY3YXknX9b
wqIP71rwxD3psBeh6ZgcFLmn8A/rSBMDBjrEqDMYtRdKOXxVT8KC1nOheCn4DcXe
u716qsRcQNxHgQmy8LOtMIC7KwjBt95VrA1v8ZZlW6OsZQVWBNXReLL8E+zwpoUW
CFd88VKWu+i0W3AAbUnH8ujWGlsS3gNhEqN1GIIbHoUWiXny3X1SnrlaHIaT9ggL
iC4GAjRYBOgbFoBue+rJU/r8r0AlGH3erznT7CAiqLCjY/Hn+L6l2sXqjkFif0ep
1QVEbQ==
-----END CERTIFICATE-----
''';

void configureBackendCertificatePolicy(Dio dio, String baseUrl) {
  if (Uri.tryParse(baseUrl)?.host != _backendHost) {
    return;
  }

  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.badCertificateCallback = (
        X509Certificate certificate,
        String host,
        int port,
      ) {
        return host == _backendHost &&
            _normalizePem(certificate.pem) ==
                _normalizePem(_backendCertificatePem);
      };
      return client;
    },
  );
}

String _normalizePem(String pem) => pem.replaceAll(RegExp(r'\s+'), '');
