import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart'; // adjust path if needed

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _showPassword = false;

  // 🔐 ایڈمن ای میل (Firebase Auth میں موجود ہونی چاہیے)
  static const String _adminEmail = 'ammarafzal075@gmail.com';

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final password = _passwordCtrl.text.trim();

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _adminEmail,
        password: password,
      );

      if (!mounted) return;

      // ✅ کامیاب لاگ اِن → ہوم اسکرین
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String msg = "لاگ اِن ناکام ہو گیا";

      if (e.code == 'wrong-password') {
        msg = "غلط پاس ورڈ";
      } else if (e.code == 'user-not-found') {
        msg = "ایڈمن صارف موجود نہیں";
      } else {
        msg = e.message ?? msg;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خرابی: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: isWide ? 60 : 48,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        "ایڈمن لاگ اِن",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "ڈیش بورڈ تک رسائی کے لیے ایڈمن پاس ورڈ درج کریں",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),

                      const SizedBox(height: 24),

                      // 🔑 پاس ورڈ فیلڈ
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: "ایڈمن پاس ورڈ",
                          prefixIcon: const Icon(Icons.password),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onFieldSubmitted: (_) => _handleLogin(),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "پاس ورڈ درج کرنا ضروری ہے";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleLogin,
                          icon: _isLoading
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.login),
                          label: Text(
                            _isLoading ? "چیک ہو رہا ہے..." : "لاگ اِن کریں",
                          ),
                          style: ElevatedButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      const Text(
                        "طلحہ کلاتھ ہاؤس – ایڈمن پینل",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
