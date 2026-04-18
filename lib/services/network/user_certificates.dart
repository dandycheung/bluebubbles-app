import 'dart:convert';
import 'dart:io';
import 'package:flutter_user_certificates_android/flutter_user_certificates_android.dart';

class UserCertificates {
  Future<SecurityContext?> getContext() async {
    // return null if platform is not android (use default system certs)
    if (!Platform.isAndroid) {
      return null;
    }

    final certs = await FlutterUserCertificatesAndroid().getUserCertificates();

    // return null if no user certs (use default system certs)
    if (certs == null) {
      return null;
    }

    // Use defaultContext which includes system certificates
    final ctx = SecurityContext.defaultContext;

    // Add user certificates to the default context
    for (var c in certs.entries) {
      ctx.setTrustedCertificatesBytes(utf8.encode(c.value.toPEM()));
    }

    return ctx;
  }
}
