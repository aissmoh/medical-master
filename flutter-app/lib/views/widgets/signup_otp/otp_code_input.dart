import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

class OtpCodeInput extends StatelessWidget {
  const OtpCodeInput({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.focusNode,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final digits = List<String>.generate(4, (index) {
      if (index >= controller.text.length) return '';
      return controller.text[index];
    });

    return SizedBox(
      height: 58,
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              4,
              (index) => Padding(
                padding: EdgeInsets.only(right: index == 3 ? 0 : 12),
                child: _OtpDigitBox(
                  digit: digits[index],
                  isActive: controller.text.length == index,
                  isFilled: digits[index].isNotEmpty,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpDigitBox extends StatelessWidget {
  const _OtpDigitBox({required this.digit, required this.isActive, required this.isFilled});

  final String digit;
  final bool isActive;
  final bool isFilled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isFilled ? const Color(0xFFF2F5FB) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive || isFilled ? kAccent2 : kInputBorder,
          width: isActive || isFilled ? 1.8 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        digit,
        style: const TextStyle(color: kTextPrimary, fontSize: 22, fontWeight: FontWeight.w700),
      ),
    );
  }
}
