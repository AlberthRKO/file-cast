import 'package:flutter/material.dart';

class CustomDateField extends StatelessWidget {
  const CustomDateField({
    super.key,
    required this.label,
    required this.color,
    required this.onChanged,
  });
  final String label;
  final Color color;
  final void Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: color,
          width: 1.0,
        ),
      ),
      child: InkWell(
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
          onTap: () => onChanged()),
    );
  }
}
