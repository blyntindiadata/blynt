import 'package:flutter/material.dart';
import 'package:startup/aboutuser.dart';
import 'package:startup/homepage.dart';
import 'package:startup/passwordbutton.dart';
import 'package:startup/shakewidget.dart';
import 'package:startup/signuptextfield.dart';

class CreateAccount extends StatefulWidget {
  const CreateAccount({Key? key}) : super(key: key);

  @override
  State<CreateAccount> createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccount> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool _obscureText1 = true;
  bool _obscureText2 = true;

  String? _usernameError;
  String? _passwordError;
  String? _confirmPasswordError;

  bool _isValidPassword(String password) {
    return password.length >= 6 &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
  }

  bool get _isPasswordValidAndMatching {
    return _isValidPassword(passwordController.text) &&
        passwordController.text == confirmPasswordController.text &&
        passwordController.text.isNotEmpty &&
        confirmPasswordController.text.isNotEmpty;
  }

  void confirmPassword() {
    setState(() {
      _usernameError = usernameController.text.isEmpty ? 'please enter a username' : null;

      if (passwordController.text.isEmpty) {
        _passwordError = 'please enter a password';
      } else if (!_isValidPassword(passwordController.text)) {
        _passwordError = 'password is too weak';
      } else {
        _passwordError = null;
      }

      if (confirmPasswordController.text.isEmpty) {
        _confirmPasswordError = 'please confirm your password';
      } else if (confirmPasswordController.text != passwordController.text) {
        _confirmPasswordError = 'passwords do not match';
      } else {
        _confirmPasswordError = null;
      }
    });

    if (_usernameError == null && _passwordError == null && _confirmPasswordError == null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => RecommendationScreen(userId: '$usernameController',)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.amber[300],
            expandedHeight: 220,
            pinned: true,
            centerTitle: false,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 32, bottom: 10),
              background: Container(color: Colors.amber[400]),
              title: Align(
                alignment: Alignment.bottomLeft,
                child: const Text(
                  'create account',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 25,
                    fontFamily: 'DMSerif',
                  ),
                ),
              ),
            ),
          ),

          // Username label
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 35, top: 25),
              child: Text(
                'CREATE USERNAME',
                style: TextStyle(
                  fontFamily: 'Poppins_Medium',
                  fontSize: 14,
                  letterSpacing: 2.0,
                  color: Colors.white38,
                ),
              ),
            ),
          ),

          // Username input with shake
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
              child: ShakeWidget(
                shake: _usernameError != null,
                child: SignUpTextField(
                  prefixIcon: const ImageIcon(
                    AssetImage('icons/username.png'),
                    color: Colors.white12,
                  ),
                  controller: usernameController,
                  hintText: 'username',
                  obscureText: false,
                ),
              ),
            ),
          ),

          if (_usernameError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 35, bottom: 5),
                child: Text(
                  _usernameError!,
                  style: const TextStyle(
                    fontFamily: 'Poppins_Regular',
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),

          // Password label
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 35, top: 25),
              child: Text(
                'CREATE PASSWORD',
                style: TextStyle(
                  fontFamily: 'Poppins_Medium',
                  fontSize: 14,
                  letterSpacing: 2.0,
                  color: Colors.white38,
                ),
              ),
            ),
          ),

          // Password requirements hint
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 5),
              child: Text(
                'your password must have six characters including lowercase, uppercase and numbers as well',
                style: TextStyle(
                  fontFamily: 'Poppins_Regular',
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: Colors.white38,
                ),
              ),
            ),
          ),

          // Password input with shake
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
              child: ShakeWidget(
                shake: _passwordError != null,
                child: SignUpTextField(
                  prefixIcon: const ImageIcon(
                    AssetImage('icons/password1.png'),
                    color: Colors.white12,
                  ),
                  isPassword: true,
                  obscureText: _obscureText1,
                  onToggleVisibility: () {
                    setState(() {
                      _obscureText1 = !_obscureText1;
                    });
                  },
                  controller: passwordController,
                  hintText: 'password',
                ),
              ),
            ),
          ),

          if (_passwordError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 35, bottom: 5),
                child: Text(
                  _passwordError!,
                  style: const TextStyle(
                    fontFamily: 'Poppins_Regular',
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),

          // Confirm Password input with shake
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
              child: ShakeWidget(
                shake: _confirmPasswordError != null,
                child: SignUpTextField(
                  prefixIcon: const ImageIcon(
                    AssetImage('icons/password2.png'),
                    color: Colors.white12,
                  ),
                  isPassword: true,
                  obscureText: _obscureText2,
                  onToggleVisibility: () {
                    setState(() {
                      _obscureText2 = !_obscureText2;
                    });
                  },
                  controller: confirmPasswordController,
                  hintText: 'confirm password',
                ),
              ),
            ),
          ),

          if (_confirmPasswordError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 35, bottom: 5),
                child: Text(
                  _confirmPasswordError!,
                  style: const TextStyle(
                    fontFamily: 'Poppins_Regular',
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),

          // Continue Button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 16),
              child: Passwordbutton(
                onTap: confirmPassword,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
