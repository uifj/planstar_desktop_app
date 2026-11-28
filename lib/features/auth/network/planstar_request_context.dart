library;

final class PlanstarRequestContext {
  PlanstarRequestContext({this.dvid, this.psSession, this.psCaptcha});

  String? dvid;
  String? psSession;
  String? psCaptcha;
  void Function(String dvid)? onDeviceIdChanged;
  void Function()? onUnauthorized;

  bool get hasSession => (psSession ?? '').isNotEmpty;

  void clearSession() => psSession = null;

  void clearCaptcha() => psCaptcha = null;
}
