import 'dart:async';
import 'dart:math' as math;

import 'package:expandable/expandable.dart';
import 'package:file_cast/domain/models/auth_challenge.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/theme/login_verification_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:pinput/pinput.dart';

class LoginChallenge extends StatefulWidget {
  const LoginChallenge({
    required this.revision,
    required this.challenge,
    required this.trustedDevice,
    required this.sendingCode,
    required this.verifyingCode,
    required this.onMediumSelected,
    required this.onConfirm,
    required this.onTrustedDeviceChanged,
    required this.onBack,
    required this.onOpenTelegram,
    required this.onListenForSmsCode,
    required this.onStopSmsCodeListener,
    this.errorMessage,
    super.key,
  });

  final int revision;
  final AuthChallenge challenge;
  final String? errorMessage;
  final bool trustedDevice;
  final bool sendingCode;
  final bool verifyingCode;
  final ValueChanged<int> onMediumSelected;
  final ValueChanged<String> onConfirm;
  final ValueChanged<bool> onTrustedDeviceChanged;
  final VoidCallback onBack;
  final VoidCallback onOpenTelegram;
  final Future<String?> Function() onListenForSmsCode;
  final Future<void> Function() onStopSmsCodeListener;

  @override
  State<LoginChallenge> createState() => _LoginChallengeState();
}

class _LoginChallengeState extends State<LoginChallenge> {
  final _pinController = TextEditingController();
  Timer? _timer;
  int _remainingSeconds = 0;
  int _smsRequest = 0;
  String? _lastSubmittedCode;

  @override
  void initState() {
    super.initState();
    _startTimer();
    unawaited(_listenForSms());
  }

  @override
  void didUpdateWidget(covariant LoginChallenge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      _lastSubmittedCode = null;
      _pinController.clear();
      _startTimer();
      unawaited(_listenForSms());
    } else if (widget.errorMessage != null &&
        widget.errorMessage != oldWidget.errorMessage) {
      _lastSubmittedCode = null;
      _pinController.clear();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _remainingSeconds = math.max(0, widget.challenge.tiempoVigencia ?? 0);
    if (_remainingSeconds == 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _remainingSeconds = math.max(0, _remainingSeconds - 1);
        if (_remainingSeconds == 0) timer.cancel();
      });
    });
  }

  Future<void> _listenForSms() async {
    final request = ++_smsRequest;
    await widget.onStopSmsCodeListener();
    if (!mounted || request != _smsRequest || widget.challenge.medio != 5) {
      return;
    }
    final code = await widget.onListenForSmsCode();
    if (!mounted ||
        request != _smsRequest ||
        code == null ||
        !RegExp(r'^\d{6}$').hasMatch(code)) {
      return;
    }
    _pinController.setText(code);
    _submitPin(code);
  }

  void _submitPin(String code) {
    if (_lastSubmittedCode == code ||
        widget.sendingCode ||
        widget.verifyingCode ||
        ((widget.challenge.tiempoVigencia ?? 0) > 0 &&
            _remainingSeconds == 0)) {
      return;
    }
    _lastSubmittedCode = code;
    widget.onConfirm(code);
  }

  @override
  void dispose() {
    _smsRequest++;
    _timer?.cancel();
    unawaited(widget.onStopSmsCodeListener());
    _pinController.dispose();
    super.dispose();
  }

  String _mediumName(int id) => switch (id) {
    1 => 'Whatsapp',
    2 => 'Telegram',
    3 => 'Correo Electrónico',
    5 => 'SMS',
    _ => 'Fiscalía',
  };

  String _mediumIcon(int id) => switch (id) {
    1 => 'whatsapp.svg',
    2 => 'telegram.svg',
    3 => 'gmail.svg',
    5 => 'mail.svg',
    _ => 'paper.svg',
  };

  @override
  Widget build(BuildContext context) {
    final visual = LoginVerificationTheme.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Verificación'),
        backgroundColor: theme.cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Volver al inicio de sesión',
          onPressed: widget.sendingCode || widget.verifyingCode
              ? null
              : widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compactHeight = constraints.maxHeight < 480;
          final compactWidth = constraints.maxWidth < 600;
          final horizontalPadding = compactWidth ? AppSpace.m : AppSpace.l;
          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: compactHeight ? AppSpace.m : AppSpace.l,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: _content(
                    context,
                    visual: visual,
                    compactHeight: compactHeight,
                    compactWidth: compactWidth,
                    availableWidth: math.min(
                      620,
                      constraints.maxWidth - horizontalPadding * 2,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _content(
    BuildContext context, {
    required LoginVerificationTheme visual,
    required bool compactHeight,
    required bool compactWidth,
    required double availableWidth,
  }) {
    final theme = Theme.of(context);
    final challenge = widget.challenge;
    final hasMedium = challenge.medio != null;
    final expired =
        hasMedium &&
        (challenge.tiempoVigencia ?? 0) > 0 &&
        _remainingSeconds == 0;
    final canRetry = expired || (challenge.tiempoVigencia ?? 0) <= 0;
    final busy = widget.sendingCode || widget.verifyingCode;
    final media = challenge.mediosVerificados;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasMedium) ...[
          Center(child: _hero(context, visual, compactHeight, compactWidth)),
          SizedBox(height: compactHeight ? AppSpace.m : 30),
        ],
        Text(
          hasMedium
              ? 'Autenticación 2FA ${_mediumName(challenge.medio!)}'
              : 'Seleccione un medio de contacto',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          hasMedium
              ? challenge.message ?? ''
              : 'Seleccione un medio de verificación para poder registrar su '
                    'autenticación en dos pasos y continuar con el proceso '
                    'de inicio de sesión.',
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
        ),
        if (challenge.mensajeServicio?.isNotEmpty == true) ...[
          const SizedBox(height: AppSpace.m),
          Text(
            challenge.mensajeServicio!,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          ),
        ],
        if (challenge.medio == 2) ...[
          const SizedBox(height: AppSpace.s),
          TextButton.icon(
            onPressed: widget.onOpenTelegram,
            style: TextButton.styleFrom(
              backgroundColor: visual.telegram,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.m,
                vertical: AppSpace.s,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.s),
              ),
            ),
            icon: SvgPicture.asset(
              'assets/images/icons/telegram.svg',
              width: AppSize.iconS,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            label: const Text('Ir a Telegram'),
          ),
        ],
        if (hasMedium) ...[
          SizedBox(height: compactHeight ? AppSpace.m : 30),
          _pinInput(context, visual, availableWidth, expired, busy),
          if (expired) ...[
            const SizedBox(height: AppSpace.m),
            Center(
              child: Text(
                'Tiempo de verificación agotado',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: visual.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.m),
          Row(
            children: [
              Checkbox(
                value: widget.trustedDevice,
                onChanged: busy
                    ? null
                    : (value) => widget.onTrustedDeviceChanged(value ?? false),
                activeColor: visual.primary,
                side: BorderSide(color: visual.primary, width: 1.5),
              ),
              Expanded(
                child: Text(
                  'Guardar como dispositivo de confianza',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (widget.verifyingCode)
            Center(child: CircularProgressIndicator(color: visual.primary)),
          if (canRetry) ...[
            const SizedBox(height: AppSpace.s),
            Center(
              child: Text(
                '¿No recibiste el código de verificación?',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: visual.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Center(
              child: TextButton.icon(
                onPressed: busy
                    ? null
                    : () => widget.onMediumSelected(challenge.medio!),
                icon: SvgPicture.asset(
                  'assets/images/icons/paper.svg',
                  width: AppSize.iconS,
                  colorFilter: ColorFilter.mode(
                    visual.primary,
                    BlendMode.srcIn,
                  ),
                ),
                label: const Text('Reenviar'),
              ),
            ),
          ],
        ],
        const SizedBox(height: AppSpace.l),
        if (media.isNotEmpty && (!hasMedium || canRetry))
          ExpandableNotifier(
            initialExpanded: true,
            child: Expandable(
              collapsed: ExpandableButton(
                child: _mediumHeader(context, visual, hasMedium),
              ),
              expanded: Column(
                children: [
                  ExpandableButton(
                    child: _mediumHeader(context, visual, hasMedium),
                  ),
                  const SizedBox(height: AppSpace.s),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: media.length,
                    itemBuilder: (context, index) {
                      final medium = media[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s),
                        child: _mediumCard(
                          context,
                          visual,
                          medium,
                          enabled:
                              !busy && medium.verificado && !medium.observado,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          )
        else if (media.isEmpty)
          _noMediaMessage(context, visual),
        if (widget.sendingCode) ...[
          const SizedBox(height: AppSpace.m),
          Center(child: CircularProgressIndicator(color: visual.primary)),
        ],
      ],
    );
  }

  Widget _hero(
    BuildContext context,
    LoginVerificationTheme visual,
    bool compactHeight,
    bool compactWidth,
  ) {
    final size = compactHeight || compactWidth ? 120.0 : 180.0;
    final radius = compactWidth ? 43.0 : 50.0;
    final total = widget.challenge.tiempoVigencia ?? 0;
    final percent = total > 0
        ? (_remainingSeconds / total).clamp(0.0, 1.0)
        : 0.0;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            Theme.of(context).brightness == Brightness.dark
                ? 'assets/images/illustrations/pinCodeDark.svg'
                : 'assets/images/illustrations/pinCode.svg',
            height: size,
            width: size,
          ),
          CircularPercentIndicator(
            radius: radius,
            lineWidth: 10,
            percent: percent,
            circularStrokeCap: CircularStrokeCap.round,
            linearGradient: LinearGradient(
              colors: [visual.primary, visual.primarySoft],
            ),
            backgroundColor: visual.mutedText.withOpacity(0.1),
            center: Text(
              '$_remainingSeconds',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pinInput(
    BuildContext context,
    LoginVerificationTheme visual,
    double availableWidth,
    bool expired,
    bool busy,
  ) {
    final theme = Theme.of(context);
    final width = math.min(56.0, math.max(48.0, (availableWidth - 5 * 8) / 6));
    final base = PinTheme(
      width: width,
      height: math.max(52.0, width * 1.15),
      textStyle: theme.textTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: visual.background,
        border: Border.all(color: visual.mutedText.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: visual.text.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: math.max(availableWidth, 6 * width + 5 * 8),
        child: Center(
          child: Pinput(
            controller: _pinController,
            length: 6,
            enabled: !busy && !expired,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.oneTimeCode],
            onCompleted: _submitPin,
            defaultPinTheme: base,
            focusedPinTheme: base.copyDecorationWith(
              border: Border.all(color: visual.primary),
              borderRadius: BorderRadius.circular(AppRadius.s),
            ),
            submittedPinTheme: base.copyWith(
              decoration: base.decoration?.copyWith(color: visual.surface),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mediumHeader(
    BuildContext context,
    LoginVerificationTheme visual,
    bool hasMedium,
  ) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: visual.surface,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        _iconBox('verificaciones.svg', visual),
        const SizedBox(width: AppSpace.m),
        Expanded(
          child: Text(
            hasMedium
                ? 'Selecciona otro medio de verificación'
                : 'Seleccione un medio de verificación',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );

  Widget _mediumCard(
    BuildContext context,
    LoginVerificationTheme visual,
    AuthMedium medium, {
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: visual.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: enabled ? () => widget.onMediumSelected(medium.medio) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(
            children: [
              _iconBox(_mediumIcon(medium.medio), visual),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpace.xs,
                      runSpacing: AppSpace.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _mediumName(medium.medio),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: visual.mutedText,
                          ),
                        ),
                        if (medium.porDefecto)
                          _badge('Por defecto', visual.primary),
                        if (!medium.verificado)
                          _badge('No verificado', visual.error),
                        if (medium.observado) _badge('Observado', visual.error),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      medium.contacto ?? medium.nombre ?? 'Cuenta vinculada',
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (enabled)
                SvgPicture.asset(
                  'assets/images/icons/arrow-right.svg',
                  width: AppSize.iconM,
                  colorFilter: ColorFilter.mode(
                    visual.primary,
                    BlendMode.srcIn,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBox(String asset, LoginVerificationTheme visual) => Container(
    width: AppSize.minTouchTarget,
    height: AppSize.minTouchTarget,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: visual.primary.withOpacity(0.05),
      borderRadius: BorderRadius.circular(10),
    ),
    child: SvgPicture.asset(
      'assets/images/icons/$asset',
      width: AppSize.iconM,
      colorFilter: ColorFilter.mode(visual.primary, BlendMode.srcIn),
    ),
  );

  Widget _badge(String label, Color foreground) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
    decoration: BoxDecoration(
      color: foreground.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: foreground,
      ),
    ),
  );

  Widget _noMediaMessage(
    BuildContext context,
    LoginVerificationTheme visual,
  ) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: visual.error.withOpacity(0.05),
      border: Border.all(color: visual.error, width: 0.5),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        SvgPicture.asset(
          'assets/images/icons/userFaltas.svg',
          width: AppSize.iconM,
          colorFilter: ColorFilter.mode(visual.error, BlendMode.srcIn),
        ),
        const SizedBox(width: AppSpace.s),
        Expanded(
          child: Text(
            'Usted no cuenta con medios de contacto registrados, por favor '
            'comuníquese con soporte para el registro de medios de contacto.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: visual.error, height: 1.1),
          ),
        ),
      ],
    ),
  );
}
