import 'package:flutter/material.dart';

@immutable
final class LoginVerificationTheme
    extends ThemeExtension<LoginVerificationTheme> {
  const LoginVerificationTheme({
    required this.background,
    required this.surface,
    required this.primary,
    required this.primarySoft,
    required this.text,
    required this.mutedText,
    required this.error,
    required this.telegram,
  });

  final Color background;
  final Color surface;
  final Color primary;
  final Color primarySoft;
  final Color text;
  final Color mutedText;
  final Color error;
  final Color telegram;

  static LoginVerificationTheme of(BuildContext context) =>
      Theme.of(context).extension<LoginVerificationTheme>()!;

  @override
  LoginVerificationTheme copyWith({
    Color? background,
    Color? surface,
    Color? primary,
    Color? primarySoft,
    Color? text,
    Color? mutedText,
    Color? error,
    Color? telegram,
  }) => LoginVerificationTheme(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    primary: primary ?? this.primary,
    primarySoft: primarySoft ?? this.primarySoft,
    text: text ?? this.text,
    mutedText: mutedText ?? this.mutedText,
    error: error ?? this.error,
    telegram: telegram ?? this.telegram,
  );

  @override
  LoginVerificationTheme lerp(
    covariant LoginVerificationTheme? other,
    double t,
  ) {
    if (other == null) return this;
    return LoginVerificationTheme(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      text: Color.lerp(text, other.text, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      error: Color.lerp(error, other.error, t)!,
      telegram: Color.lerp(telegram, other.telegram, t)!,
    );
  }
}
