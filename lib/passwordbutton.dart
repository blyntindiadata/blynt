import 'package:flutter/material.dart';

class Passwordbutton extends StatelessWidget {
  final Function()?onTap;
  const Passwordbutton({super.key,
  required this.onTap,
});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child:Container(
      padding: EdgeInsets.all(17),
      margin: EdgeInsets.symmetric(horizontal: 70),
      decoration: BoxDecoration(
        color: Colors.amberAccent[400],
        borderRadius: BorderRadius.circular(9),
      ),
      child: Center(
        child: Text("CONFIRM",
        
        style: TextStyle(
          letterSpacing: 2.3,
          color: Colors.black,
          fontSize: 14,
          fontFamily: 'Poppins_Medium',
        ),
        ),
      ),
    ),
    );
  }
}