import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _password.text.trim());
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on FirebaseAuthException {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid email or password'), backgroundColor: kEmergency));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kNavy;
    final mutedColor = isDark ? kDarkMuted : const Color(0xFF52647D);
    return Scaffold(
    backgroundColor: isDark ? kDarkBackground : const Color(0xFFF8FBFA),
    body: SafeArea(
      child: Stack(children: [
        const Positioned(left: -52, top: 44, child: _SoftCircle(size: 132)),
        const Positioned(right: -42, bottom: -48, child: _SoftCircle(size: 154)),
        Center(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18), child: Form(key: _formKey, child: Column(children: [
          const SizedBox(height: 44),
          SizedBox(width: 86, height: 70, child: Stack(alignment: Alignment.center, children: [
            const Icon(Icons.groups_rounded, color: kEmerald, size: 58),
            const Positioned(right: 4, top: 0, child: Icon(Icons.favorite, color: Color(0xFFFF8B7C), size: 25)),
          ])),
          const SizedBox(height: 17),
          Text('Family Emergency', style: TextStyle(fontSize: 25, height: 1, fontWeight: FontWeight.bold, color: titleColor)),
          const SizedBox(height: 8),
          Text('Together. Safer. Always.', style: TextStyle(fontSize: 14, color: mutedColor)),
          const SizedBox(height: 29),
          _field(_email, 'Email', Icons.mail_outline_rounded, type: TextInputType.emailAddress, validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null),
          const SizedBox(height: 12),
          _field(_password, 'Password', Icons.lock_outline_rounded, obscure: _hidePassword, validator: (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null, trailing: IconButton(onPressed: () => setState(() => _hidePassword = !_hidePassword), icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF64748B), size: 20))),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(Icons.check_box_outline_blank_rounded, size: 20, color: mutedColor),
              const SizedBox(width: 7),
              Text('Remember me', style: TextStyle(fontSize: 12, color: mutedColor)),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: const Text('Forgot Password?', style: TextStyle(fontSize: 12, color: Color(0xFF087F6C))),
              ),
            ],
          ),
          const SizedBox(height: 11),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _loading ? null : _login, style: ElevatedButton.styleFrom(backgroundColor: kEmerald, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 18),
          Row(children: [Expanded(child: Divider(color: isDark ? const Color(0xFF233846) : const Color(0xFFE2E8F0))), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('OR', style: TextStyle(color: mutedColor, fontSize: 12))), Expanded(child: Divider(color: isDark ? const Color(0xFF233846) : const Color(0xFFE2E8F0)))]),
          const SizedBox(height: 17),
          SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(onPressed: () {}, icon: const Text('G', style: TextStyle(color: Colors.red, fontSize: 22, fontWeight: FontWeight.bold)), label: Text('Continue with Google', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)), style: OutlinedButton.styleFrom(side: BorderSide(color: isDark ? const Color(0xFF233846) : const Color(0xFFE2E8F0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("Don't have an account? ", style: TextStyle(fontSize: 12, color: mutedColor)), TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())), style: TextButton.styleFrom(foregroundColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB), backgroundColor: isDark ? const Color(0x1A60A5FA) : const Color(0x142563EB), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))), child: const Text('Sign Up', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: .15, decoration: TextDecoration.underline, decorationThickness: 1.5)))])
        ]))))
      ]),
    ),
  );
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {TextInputType? type, bool obscure = false, Widget? trailing, String? Function(String?)? validator}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? kDarkMuted : const Color(0xFF64748B);
    return TextFormField(controller: controller, validator: validator, keyboardType: type, obscureText: obscure, style: TextStyle(color: isDark ? Colors.white : kNavy), decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: mutedColor, fontSize: 13), prefixIcon: Icon(icon, color: mutedColor, size: 20), suffixIcon: trailing, filled: true, fillColor: isDark ? kDarkCard : Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 15), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: isDark ? const Color(0xFF233846) : const Color(0xFFE2E8F0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: kEmerald))));
  }
}

class _SoftCircle extends StatelessWidget {
  final double size;
  const _SoftCircle({required this.size});
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: const BoxDecoration(color: Color(0x1410B981), shape: BoxShape.circle));
}
