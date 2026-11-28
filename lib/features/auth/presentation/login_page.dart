library;

import 'dart:async';

import 'package:core/result.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../application/auth_providers.dart';
import '../application/auth_state.dart';
import '../domain/auth_models.dart';

final class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

final class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _passwordMode = false;
  bool _agreed = false;
  static final RegExp _phonePattern = RegExp(r'^1[3-9]\d{9}$');
  static const int _maxCaptchaRounds = 3;

  @override
  void initState() {
    super.initState();
    _phone.addListener(_onInputChanged);
    _code.addListener(_onInputChanged);
    _password.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _phone
      ..removeListener(_onInputChanged)
      ..dispose();
    _code
      ..removeListener(_onInputChanged)
      ..dispose();
    _password
      ..removeListener(_onInputChanged)
      ..dispose();
    super.dispose();
  }

  bool get _phoneValid => _phonePattern.hasMatch(_phone.text.trim());
  bool get _credentialValid =>
      _passwordMode ? _password.text.length >= 6 : _code.text.length == 6;

  void _onInputChanged() {
    if (!mounted) return;
    ref.read(authControllerProvider.notifier).clearFailure();
    setState(() {});
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendCode() async {
    final l10n = context.l10n;
    if (!_phoneValid) {
      _toast(l10n.authPhoneInvalid);
      return;
    }
    final before = ref.read(authControllerProvider);
    if (!before.canSendCode) return;
    final phone = _phone.text.trim();
    final controller = ref.read(authControllerProvider.notifier);
    AuthFailure? failure = await controller.sendCode(phone);
    final captcha = await _resolveCaptcha(
      failure,
      (String captcha) => controller.sendCode(phone, captcha: captcha),
    );
    if (!mounted || captcha.cancelled) return;
    if (captcha.failure == null) {
      _toast(l10n.authCodeSent);
    } else {
      _report(captcha.failure!);
    }
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!_phoneValid) {
      _toast(l10n.authPhoneInvalid);
      return;
    }
    if (!_credentialValid) {
      _toast(_passwordMode ? l10n.authPasswordInvalid : l10n.authCodeInvalid);
      return;
    }
    if (!_agreed) {
      _toast(l10n.authAgreementRequired);
      return;
    }
    if (ref.read(authControllerProvider).busy) return;

    final phone = _phone.text.trim();
    final controller = ref.read(authControllerProvider.notifier);
    AuthFailure? failure = _passwordMode
        ? await controller.loginWithPassword(phone, _password.text)
        : await controller.loginWithCode(phone, _code.text);
    final captcha = await _resolveCaptcha(
      failure,
      (String captcha) => _passwordMode
          ? controller.loginWithPassword(
              phone,
              _password.text,
              captcha: captcha,
            )
          : controller.loginWithCode(phone, _code.text, captcha: captcha),
    );
    if (!mounted || captcha.cancelled) return;
    if (captcha.failure != null) {
      _report(captcha.failure!);
      return;
    }
    if (!ref.read(authControllerProvider).isLoggedIn) return;
    final isNewUser = ref.read(authControllerProvider).isNewUser;
    if (isNewUser) _toast(l10n.authNewUserWelcome);
    context.go(_returnDestination());
  }

  String _returnDestination() {
    final raw = GoRouterState.of(context).uri.queryParameters['from'];
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (uri != null &&
        !uri.hasAuthority &&
        !uri.hasScheme &&
        !raw!.contains('//') &&
        !raw.contains('\\') &&
        (uri.path == '/project-ideas' ||
            RegExp(r'^/project-ideas/\d+$').hasMatch(uri.path))) {
      return uri.toString();
    }
    return '/account';
  }

  Future<({AuthFailure? failure, bool cancelled})> _resolveCaptcha(
    AuthFailure? failure,
    Future<AuthFailure?> Function(String captcha) retry,
  ) async {
    var rounds = 0;
    while (failure != null &&
        failure.needsCaptcha &&
        rounds < _maxCaptchaRounds) {
      rounds++;
      if (!mounted) return (failure: failure, cancelled: true);
      final captcha = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) =>
            _CaptchaDialog(message: failure?.message),
      );
      if (captcha == null) return (failure: failure, cancelled: true);
      failure = await retry(captcha);
    }
    return (failure: failure, cancelled: false);
  }

  void _report(AuthFailure failure) {
    final l10n = context.l10n;
    if (failure.isAccountLocked) {
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => AlertDialog(
            title: Text(l10n.authAccountLockedTitle),
            content: Text(failure.message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.authAccountLockedConfirm),
              ),
            ],
          ),
        ),
      );
      return;
    }
    _toast(switch (failure.kind) {
      AuthFailureKind.network => l10n.authNetworkError,
      AuthFailureKind.timeout => l10n.authTimeoutError,
      AuthFailureKind.storage => l10n.authStorageError,
      AuthFailureKind.unauthorized =>
        failure.message.isNotEmpty ? failure.message : l10n.authUnknownError,
      AuthFailureKind.business ||
      AuthFailureKind.needsCaptcha ||
      AuthFailureKind.accountLocked ||
      AuthFailureKind.unknown =>
        failure.message.isNotEmpty ? failure.message : l10n.authUnknownError,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: colors.bgPage,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(LucideIcons.sparkles, color: colors.brand),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            l10n.authLoginTitle,
                            style: TextStyle(
                              fontSize: AppTypography.title,
                              fontWeight: AppTypography.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.authBackToAccount,
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/account'),
                          icon: const Icon(LucideIcons.x),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.authLoginSubtitle,
                      style: TextStyle(
                        fontSize: AppTypography.body,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextField(
                      key: const ValueKey<String>('auth.phone'),
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.authPhoneHint,
                        prefixIcon: const Icon(LucideIcons.smartphone),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_passwordMode)
                      TextField(
                        key: const ValueKey<String>('auth.password'),
                        controller: _password,
                        obscureText: true,
                        inputFormatters: <TextInputFormatter>[
                          LengthLimitingTextInputFormatter(20),
                        ],
                        decoration: InputDecoration(
                          labelText: l10n.authPasswordHint,
                          prefixIcon: const Icon(LucideIcons.lockKeyhole),
                          border: const OutlineInputBorder(),
                        ),
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              key: const ValueKey<String>('auth.code'),
                              controller: _code,
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              decoration: InputDecoration(
                                labelText: l10n.authCodeHint,
                                prefixIcon: const Icon(LucideIcons.shieldCheck),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          SizedBox(
                            height: 56,
                            child: OutlinedButton(
                              onPressed: beforeCanSend(auth, _phoneValid)
                                  ? _sendCode
                                  : null,
                              child: Text(
                                auth.sendingCode
                                    ? l10n.authSendingCode
                                    : auth.inCooldown
                                    ? l10n.authResendCode(auth.cooldownSeconds)
                                    : l10n.authSendCode,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.md),
                    CheckboxListTile(
                      key: const ValueKey<String>('auth.agreement'),
                      contentPadding: EdgeInsets.zero,
                      value: _agreed,
                      onChanged: (bool? value) =>
                          setState(() => _agreed = value ?? false),
                      title: Text(
                        l10n.authAgreementText,
                        style: TextStyle(
                          fontSize: AppTypography.caption,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      key: const ValueKey<String>('auth.submit'),
                      onPressed: !auth.busy ? _submit : null,
                      child: auth.loggingIn
                          ? Semantics(
                              label: l10n.authLoggingIn,
                              child: const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : Text(l10n.authLoginAction),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: auth.busy
                            ? null
                            : () {
                                _password.clear();
                                _code.clear();
                                setState(() => _passwordMode = !_passwordMode);
                              },
                        child: Text(
                          _passwordMode
                              ? l10n.authSwitchToCode
                              : l10n.authSwitchToPassword,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool beforeCanSend(AuthState auth, bool phoneValid) =>
    phoneValid && auth.canSendCode;

final class _CaptchaDialog extends ConsumerStatefulWidget {
  const _CaptchaDialog({this.message});

  final String? message;

  @override
  ConsumerState<_CaptchaDialog> createState() => _CaptchaDialogState();
}

final class _CaptchaDialogState extends ConsumerState<_CaptchaDialog> {
  final TextEditingController _input = TextEditingController();
  Uint8List? _image;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ref
        .read(authControllerProvider.notifier)
        .fetchCaptcha();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _image = result.fold(
        onFailure: (Failure _) => null,
        onSuccess: (List<int> bytes) =>
            bytes.isEmpty ? null : Uint8List.fromList(bytes),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.authCaptchaTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if ((widget.message ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                widget.message!,
                style: TextStyle(color: context.appColors.textSecondary),
              ),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _loading ? null : () => unawaited(_load()),
            child: SizedBox(
              height: 52,
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : _image == null
                    ? Text(l10n.authCaptchaLoadFailed)
                    : Image.memory(
                        _image!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) =>
                            Text(l10n.authCaptchaLoadFailed),
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _input,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: <TextInputFormatter>[
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: InputDecoration(
              labelText: l10n.authCaptchaHint,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (String value) =>
                Navigator.of(context).pop(value.trim()),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loading ? null : () => unawaited(_load()),
              child: Text(l10n.authCaptchaRefresh),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.authCaptchaCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_input.text.trim()),
          child: Text(l10n.authCaptchaConfirm),
        ),
      ],
    );
  }
}
