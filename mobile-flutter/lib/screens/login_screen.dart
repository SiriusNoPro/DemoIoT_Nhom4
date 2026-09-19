import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() { _isLoading = true; _error = null; });
    final success = await context.read<ApiService>().login(
      _usernameController.text.trim(), _passwordController.text);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (!success) _error = 'Đăng nhập thất bại. Kiểm tra tài khoản hoặc kết nối API.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F7),
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.sensors, size: 56, color: Color(0xFF18715F)),
            const SizedBox(height: 18),
            const Text('EcoSense', textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFF18715F))),
            const SizedBox(height: 6),
            const Text('Trạm môi trường thông minh', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6A7875))),
            const SizedBox(height: 36),
            Card(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Đăng nhập', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextFormField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Tên đăng nhập', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)), validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập tên đăng nhập' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)), validator: (value) => value == null || value.isEmpty ? 'Vui lòng nhập mật khẩu' : null),
                if (_error != null) ...[const SizedBox(height: 14), Text(_error!, style: const TextStyle(color: Colors.red))],
                const SizedBox(height: 22),
                FilledButton(onPressed: _isLoading ? null : _login, child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_isLoading ? 'Đang đăng nhập...' : 'Đăng nhập'))),
              ])),
            )),
            const SizedBox(height: 18),
            const Text('Tài khoản demo: operator / Operator@123', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6A7875))),
          ],
        )),
      ))),
    );
  }
}
