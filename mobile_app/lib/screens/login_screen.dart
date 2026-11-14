import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Chế độ màn hình: false = Đăng nhập, true = Đăng ký
  bool _isRegisterMode = false;
  bool _isLoading = false;
  bool _obscurePassword = true; // Mặc định ẩn mật khẩu

  // Controllers cho Đăng nhập & Đăng ký
  final _accountController = TextEditingController(text: '20210001');
  final _passwordController = TextEditingController(text: '123456');

  // Controllers bổ sung khi Đăng ký
  final _fullNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _vehicleModelController = TextEditingController();

  void _handleSubmit() async {
    setState(() => _isLoading = true);
    try {
      if (_isRegisterMode) {
        // Kiểm tra nhập đủ thông tin khi đăng ký
        if (_fullNameController.text.isEmpty ||
            _studentIdController.text.isEmpty ||
            _emailController.text.isEmpty ||
            _passwordController.text.isEmpty) {
          throw Exception('Vui lòng điền đầy đủ các thông tin bắt buộc!');
        }

        await ApiService.register(
          fullName: _fullNameController.text.trim(),
          studentId: _studentIdController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          plateNumber: _plateNumberController.text.trim().isEmpty
              ? 'Chưa cập nhật (${_studentIdController.text.trim()})'
              : _plateNumberController.text.trim(),
          vehicleModel: _vehicleModelController.text.trim().isEmpty
              ? 'Xe máy sinh viên'
              : _vehicleModelController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.green, content: Text('Đăng ký thành công!')),
          );
        }
        widget.onLoginSuccess();
      } else {
        // Xử lý Đăng nhập
        await ApiService.login(
          _accountController.text.trim(),
          _passwordController.text.trim(),
        );
        widget.onLoginSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LOGO PARKING HUST
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFB71C1C).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_parking, color: Color(0xFFB71C1C), size: 64),
              ),
              const SizedBox(height: 16),
              const Text(
                'ParkingHUST',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFB71C1C)),
              ),
              Text(
                _isRegisterMode
                    ? 'Đăng ký tài khoản & Phương tiện sinh viên'
                    : 'Hệ thống đỗ xe thông minh ĐHBK Hà Nội',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 32),

              // --- CÁC Ô NHẬP KHI Ở CHẾ ĐỘ ĐĂNG NHẬP ---
              if (!_isRegisterMode) ...[
                TextField(
                  controller: _accountController,
                  decoration: InputDecoration(
                    labelText: 'Mã số sinh viên hoặc Email',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // --- CÁC Ô NHẬP KHI Ở CHẾ ĐỘ ĐĂNG KÝ ---
              if (_isRegisterMode) ...[
                TextField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: 'Họ và tên sinh viên (*)',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _studentIdController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Mã số sinh viên - MSSV (*)',
                    prefixIcon: const Icon(Icons.numbers),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email trường (*)',
                    hintText: 'vd: ten.sv@sis.hust.edu.vn',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _plateNumberController,
                  decoration: InputDecoration(
                    labelText: 'Biển số xe máy (Optional)',
                    hintText: 'vd: 29-B1 123.45',
                    prefixIcon: const Icon(Icons.two_wheeler),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _vehicleModelController,
                  decoration: InputDecoration(
                    labelText: 'Dòng xe (Optional)',
                    hintText: 'vd: Honda Wave, Vision...',
                    prefixIcon: const Icon(Icons.info_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Ô NHẬP MẬT KHẨU (DÙNG CHUNG CHO CẢ 2 CHẾ ĐỘ)
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu (*)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              // NÚT BẤM CHÍNH (ĐĂNG NHẬP / ĐĂNG KÝ)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _handleSubmit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _isRegisterMode ? 'HOÀN TẤT ĐĂNG KÝ' : 'ĐĂNG NHẬP',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // NÚT CHUYỂN ĐỔI QUA LẠI GIỮA ĐĂNG NHẬP VÀ ĐĂNG KÝ
              TextButton(
                onPressed: () {
                  setState(() {
                    _isRegisterMode = !_isRegisterMode;
                  });
                },
                child: Text(
                  _isRegisterMode
                      ? 'Đã có tài khoản? Quay lại Đăng nhập'
                      : 'Chưa có tài khoản? Đăng ký ngay',
                  style: const TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}