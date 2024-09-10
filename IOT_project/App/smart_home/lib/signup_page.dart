import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final pinController = TextEditingController();
  String errorMessage = '';

  final String correctPin = '1234'; // Define your pin here

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    pinController.dispose();
    super.dispose();
  }

  Future<void> signUp() async {
    setState(() {
      errorMessage = ''; // Reset error message before attempting sign-up
    });

    // Validate password and confirmation
    if (passwordController.text.trim() != confirmPasswordController.text.trim()) {
      setState(() {
        errorMessage = 'Passwords do not match';
      });
      return;
    }

    // Validate PIN
    if (pinController.text.trim() != correctPin) {
      setState(() {
        errorMessage = 'Incorrect PIN';
      });
      return;
    }

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      // Navigate to the home page or show success message
      Navigator.of(context).pop(); // Navigate back to login page or home page
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Sign Up'),
    ),
    body: SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 40),
          TextField(
            controller: emailController,
            cursorColor: Colors.white,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Email',
              errorText: errorMessage.contains('Email') ? errorMessage : null,
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: passwordController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Password',
              errorText: errorMessage.contains('Password') ? errorMessage : null,
            ),
            obscureText: true,
          ),
          SizedBox(height: 8),
          TextField(
            controller: confirmPasswordController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              errorText: errorMessage.contains('Password') ? errorMessage : null,
            ),
            obscureText: true,
          ),
          SizedBox(height: 8),
          TextField(
            controller: pinController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'PIN',
              errorText: errorMessage.contains('PIN') ? errorMessage : null,
            ),
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: Size.fromHeight(50),
            ),
            icon: Icon(Icons.lock_open, size: 32),
            label: Text(
              'Sign Up',
              style: TextStyle(fontSize: 24),
            ),
            onPressed: signUp,
          ),
          if (errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                errorMessage,
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
        ],
      ),
    ),
  );
}
