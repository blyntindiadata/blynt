import 'package:flutter/material.dart';
import 'package:startup/aboutuser.dart';
import 'package:startup/homepage.dart';
import 'package:startup/passwordbutton.dart';
import 'package:startup/signupbutton.dart';
import 'package:startup/signupscreen.dart';
import 'package:startup/signuptextfield.dart';

class PasswordPage extends StatefulWidget {
  //  final Function()?onTap;
  PasswordPage({super.key,});

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  
  final TextEditingController passwordController = TextEditingController();

  final TextEditingController confirmpasswordController = TextEditingController();

  void confirmPassword(){
    /*

    password code firebase

    */
    Navigator.push(context, MaterialPageRoute(builder: (context) => RecommendationScreen(userId: "user123")));
   }
   void goBack(){
    Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen(onTap: (){},)));
   }
   bool _obscureText1 = true;
  bool _obscureText2 = true;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // onTap: onTap,
      debugShowCheckedModeBanner: false,
      home:Scaffold(
        backgroundColor: Colors.black,
        body:Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(padding: EdgeInsetsGeometry.only(left:500, top: 50)),


          GestureDetector(
              onTap: () {
                  Navigator.pop(context);
                },
          
            child: Container(
              // padding: EdgeInsets.only(top:30),
              // padding:EdgeInsetsGeometry.all(20),
              // margin: EdgeInsets.only(top: 80),
              // onTap:goBack,
              height: 30,
              child : Image.asset('icons/backbutton.png',
              color: Colors.amberAccent[400],),
              padding: EdgeInsets.only(right: 350), 
              

            ),
          ),
            // Container(
            //    padding: EdgeInsets.only(top:95),
            //   child: Text('welcome to blynt,', 
             
            //   style: TextStyle(
            //      color: Colors.amberAccent[100],
            //      fontSize: 30, 
            //      fontFamily: 'DMSerif'
            //   ),), 
            // ),
            // Container(
               
            //   child: Text('rishii_0507', 
             
            //   style: TextStyle(
            //      color: Colors.amberAccent[400],
            //      fontSize: 30, 
            //      fontFamily: 'DMSerif',
            //      letterSpacing: 1.4,
            //   ),), 
            // ),
            // Container(
            //    padding: EdgeInsets.only(top:10),
            //   child: Text('create a strong password', 
             
            //   style: TextStyle(
            //      color: Colors.grey[400],
            //      fontSize: 10, 
            //      fontFamily: 'Poppins_Regular',
            //      letterSpacing: 1.4,
            //   ),), 
            // ),
            Container(
               padding: EdgeInsets.only(top:95),
              child: Text('create password', 
             
              style: TextStyle(
                 color: Colors.amberAccent[400],
                 fontSize: 30, 
                 fontFamily: 'DMSerif'
              ),), 
            ),
            Container(
               padding: EdgeInsets.only(top:10),
              child: Text('password must be etc etc', 
             
              style: TextStyle(
                 color: Colors.grey[400],
                 fontSize: 10, 
                 fontFamily: 'Poppins_Regular',
                 letterSpacing: 1.4,
              ),),), 

              const SizedBox(height: 25),
            SignUpTextField(
               prefixIcon: ImageIcon(
  AssetImage('icons/password1.png'),
  // size: 24,
  color: Colors.white12
),
isPassword: true,
          obscureText: _obscureText1,
          onToggleVisibility: () {
            setState(() {
              _obscureText1 = !_obscureText1;
            });
          },
              controller:passwordController,
              hintText: 'password',
              // obscureText:true,
              ),
              const SizedBox(height: 25),
            SignUpTextField(
              prefixIcon: ImageIcon(
  AssetImage('icons/password2.png'),
  // size: 24,
  color: Colors.white12
),
              isPassword: true,
              obscureText: _obscureText2,
          onToggleVisibility: () {
            setState(() {
              _obscureText2 = !_obscureText2;
            });
          },
              controller:confirmpasswordController,
              hintText: 'confirm password',
              // obscureText:true,
              ),
            const SizedBox(height: 30),
           
            Passwordbutton(
              onTap:confirmPassword,
            ),
           

          ],
        )
      )
    );
  }
}
