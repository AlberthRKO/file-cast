import 'package:flutter/material.dart';

class LoadingButtonWrapper extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color? loadingColor;
  final double loadingSize;

  const LoadingButtonWrapper({
    Key? key,
    required this.child,
    required this.isLoading,
    required this.onPressed,
    this.loadingColor,
    this.loadingSize = 20,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: isLoading ? 0.6 : 1.0,
            child: child,
          ),
          if (isLoading)
            SizedBox(
              width: loadingSize,
              height: loadingSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  loadingColor ?? Theme.of(context).primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SimpleLoadingButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? child;

  const SimpleLoadingButton({
    Key? key,
    this.text = '',
    required this.onPressed,
    required this.isLoading,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onPressed,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: isLoading ? 0.5 : 1.0,
            child: child ?? Text(text),
          ),
          if (isLoading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}