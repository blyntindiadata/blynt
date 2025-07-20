import 'package:flutter/material.dart';
import 'package:startup/homepage.dart';
import 'package:startup/password.dart';
import 'package:startup/signupbutton.dart';
import 'package:startup/signuptextfield.dart';

class LoginScreen extends StatefulWidget {

  final void Function()? onTap;
  
   const LoginScreen({super.key, required this.onTap});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();

   void login(){
    /*

    login code firebase

    */
    Navigator.push(context, MaterialPageRoute(builder: (context) => PasswordPage()));
   }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home:Scaffold(
        backgroundColor: Colors.black,
        body:Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(padding: EdgeInsetsGeometry.only(left:500, top: 175)),
            Container(
              child: Text('sign up', style: TextStyle(
                 color: Colors.amberAccent[400],
                 fontSize: 30, 
                 fontFamily: 'DMSerif'
              ),), 
            ),
            
            Row(
              children: [
                Padding(padding: EdgeInsetsGeometry.only(left: 90, top: 15, bottom: 15)),
                  Text('already have an account? ', style: TextStyle(
                 color: Colors.amberAccent[100],
                 fontSize: 12, 
                 fontFamily: 'Poppins_Regular'
              ),),
              Text('login here', style: TextStyle(
                shadows: [
                  Shadow(
                    color: Colors.amberAccent,
                    offset: Offset(0, -1)
                  )
                ],
                //  color: Colors.amberAccent[200],
                color: Colors.transparent,
                 fontSize: 12, 
                 fontFamily: 'Poppins_Regular',
                 decoration: TextDecoration.underline,
                 decorationColor: Colors.amberAccent,
                 decorationStyle: TextDecorationStyle.dashed
                 
              ),),
              

              ], 
            
            ),
            
            const SizedBox(height: 27),
            SignUpTextField(
              prefixIcon: ImageIcon(
  AssetImage('icons/username.png'),
  // size: 24,
  color: Colors.white12
),

        
              
              controller: usernameController,
              hintText: 'username',
              obscureText: false,
              ),
            //   const SizedBox(height: 25),
            // SignUpTextField(
            //   hintText: 'password',
            //   obscureText:true,
            //   ),
            //   const SizedBox(height: 25),
            // SignUpTextField(
            //   hintText: 'confirm password',
            //   obscureText:true,
            //   ),
            const SizedBox(height: 30),              
            Signupbutton(
              onTap:login,
            ),
            
            // const SizedBox(height: 50),
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 40),
            //   child: Row(children: [
            //     Expanded(child: Divider(
            //       thickness: 0.5,
            //       color: Colors.grey[400],
            //     )),
            //     Padding(
            //       padding: const EdgeInsets.symmetric(horizontal: 10.0),
            //       child: Text('or',
            //       style: TextStyle(
            //         fontFamily: 'Poppins_Regular',
            //         fontSize: 15,
            //         color: Colors.grey[400]
            //       ),),
            //     ),
            //     Expanded(child: Divider(
            //       thickness: 0.5,
            //       color: Colors.grey[400],
            //     ))
            //   ],),
            // )

          ],
        )
      )
    );
  }
}