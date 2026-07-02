import 'package:flutter/material.dart';

class CustomDateField extends StatelessWidget {
  const CustomDateField({
    required this.label,
    required this.color,
    required this.onChanged,
    super.key,
  });
  final String label;
  final Color color;
  final void Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color,
        ),
      ),
      child: InkWell(
        onTap: onChanged,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12),
            ),
            Icon(
              Icons.calendar_month,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
