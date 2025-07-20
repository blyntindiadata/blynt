import 'package:flutter/material.dart';

class SignUpTextField extends StatelessWidget {
  final String hintText;
  final bool obscureText;
  final TextEditingController controller;
  final Widget? prefixIcon;
  final VoidCallback? onToggleVisibility;
  final bool isPassword;
  final Widget? suffixIcon; 

  const SignUpTextField({
    super.key,
    required this.hintText,
    required this.controller,
    this.prefixIcon,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleVisibility,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 35.0),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? obscureText : false,
        cursorColor: Colors.yellowAccent,
        style: const TextStyle(
          color: Colors.yellow,
          fontFamily: 'Poppins_Regular',
          fontSize: 16,
        ),
        decoration: InputDecoration(
          prefixIcon: prefixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 8, right: 7),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: prefixIcon,
                  ),
                )
              : null,
          prefixIconConstraints: const BoxConstraints(minWidth: 18, minHeight: 18),
          suffixIcon: isPassword
    ? Padding(
        padding: const EdgeInsets.only(right: 8.0, top: 4.0),
        child: SizedBox(
          width: 20,
          height: 20,
          child: GestureDetector(
            onTap: onToggleVisibility,
            child: Icon(
              obscureText ? Icons.visibility_off : Icons.visibility,
              size: 20,
              color: Colors.grey,
            ),
          ),
        ),
      )
    : suffixIcon,

          suffixIconConstraints: const BoxConstraints(minWidth: 20, minHeight: 20),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.yellowAccent),
          ),
          // enabledBorder: OutlineInputBorder(
          //   borderSide: BorderSide(color: Colors.yellowAccent.withOpacity(0.5)),
          // ),
          fillColor: Colors.grey[900],
          filled: true,
          hintText: hintText,
          hintStyle: const TextStyle(
            fontFamily: 'Poppins_Regular',
            fontSize: 13,
            color: Colors.white54,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        maxLines: 1,
      ),
    );
  }
}
