import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _device;
  Map<String, dynamic>? _telemetry;
  Timer? _timer;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final api = context.read<ApiService>();
    final device = await api.getDevice('esp32-001');
    final telemetry = await api.getLatestTelemetry('esp32-001');
    if (!mounted) return;
    setState(() {
      if (device != null) _device = device;
      if (telemetry != null) _telemetry = telemetry;
      _error = device == null ? 'Không thể kết nối backend. Hãy kiểm tra địa chỉ API.' : null;
    });
  }

  Future<void> _toggleActuator(String action, String label) async {
    if (_device == null || _sending || _device!['status'] != 'ONLINE') return;
    setState(() => _sending = true);
    final sent = await context.read<ApiService>().sendCommand('esp32-001', action);
    if (mounted) {
      setState(() {
        _sending = false;
        if (!sent) _error = 'Gửi lệnh $label thất bại.';
      });
      if (sent) await _fetchData();
    }
  }

  String _reading(dynamic value, String unit) => value is num ? '${value.toStringAsFixed(1)} $unit' : '—';

  Widget _metric(String title, dynamic value, String unit, IconData icon, Color color) {
    return Expanded(child: Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 18),
        Text(title, style: const TextStyle(color: Color(0xFF6A7875))),
        const SizedBox(height: 4),
        Text(_reading(value, unit), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ])),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final online = _device?['status'] == 'ONLINE';
    final temperature = _telemetry?['temperature'];
    final hot = temperature is num && temperature > 35;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F8F7),
        elevation: 0,
        title: const Text('◉ EcoSense', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF18715F))),
        actions: [IconButton(tooltip: 'Đăng xuất', icon: const Icon(Icons.logout), onPressed: api.logout)],
      ),
      body: _device == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: ListView(padding: const EdgeInsets.all(18), children: [
                const Text('Tổng quan môi trường', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Cảm biến cập nhật mỗi 5 giây', style: TextStyle(color: Color(0xFF6A7875))),
                const SizedBox(height: 20),
                if (_error != null) ...[Card(color: const Color(0xFFFFE8E4), child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!))), const SizedBox(height: 12)],
                if (hot) ...[Card(color: const Color(0xFFFFE7CF), child: Padding(padding: const EdgeInsets.all(16), child: Text('Cảnh báo: nhiệt độ ${_reading(temperature, '°C')} vượt ngưỡng 35 °C.'))), const SizedBox(height: 12)],
                Card(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), child: Padding(
                  padding: const EdgeInsets.all(20), child: Row(children: [
                    CircleAvatar(backgroundColor: online ? const Color(0xFFE4F4EC) : const Color(0xFFF0F0F0), child: Icon(Icons.sensors, color: online ? const Color(0xFF18715F) : Colors.grey)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_device?['name'] ?? 'ESP32', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)), const Text('esp32-001', style: TextStyle(color: Color(0xFF6A7875)))])),
                    Text(online ? 'ONLINE' : 'OFFLINE', style: TextStyle(color: online ? const Color(0xFF18715F) : Colors.red, fontWeight: FontWeight.bold)),
                  ]),
                )),
                const SizedBox(height: 16),
                Row(children: [_metric('Nhiệt độ', temperature, '°C', Icons.thermostat, const Color(0xFFDE6F4C)), const SizedBox(width: 10), _metric('Độ ẩm', _telemetry?['humidity'], '%', Icons.water_drop, const Color(0xFF3C91BA))]),
                const SizedBox(height: 10),
                Row(children: [_metric('Ánh sáng', _telemetry?['illuminance'], 'mức', Icons.wb_sunny_outlined, const Color(0xFFD9A442)), const SizedBox(width: 10), _metric('Độ ẩm đất', _telemetry?['soilMoisture'], '%', Icons.grass, const Color(0xFF5B9E75))]),
                const SizedBox(height: 16),
                Card(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), child: Padding(
                  padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Điều khiển thiết bị', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(api.role == 'VIEWER' ? 'Tài khoản viewer chỉ có quyền xem.' : online ? 'Thiết bị sẽ phản hồi bằng ACK.' : 'Thiết bị đang ngoại tuyến.', style: const TextStyle(color: Color(0xFF6A7875))),
                    const SizedBox(height: 10),
                    SwitchListTile(contentPadding: EdgeInsets.zero, secondary: const Icon(Icons.lightbulb_outline), title: Text(_device?['ledState'] == true ? 'LED đang bật' : 'LED đang tắt'), value: _device?['ledState'] == true, onChanged: api.role == 'VIEWER' || !online || _sending ? null : (_) => _toggleActuator(_device?['ledState'] == true ? 'LED_OFF' : 'LED_ON', 'LED')),
                    const Divider(),
                    SwitchListTile(contentPadding: EdgeInsets.zero, secondary: const Icon(Icons.volume_up_outlined), title: Text(_device?['buzzerState'] == true ? 'Còi đang kêu' : 'Còi đang tắt'), value: _device?['buzzerState'] == true, onChanged: api.role == 'VIEWER' || !online || _sending ? null : (_) => _toggleActuator(_device?['buzzerState'] == true ? 'BUZZER_OFF' : 'BUZZER_ON', 'còi')),
                  ]),
                )),
                const SizedBox(height: 12),
                Text('Vai trò: ${api.role ?? '—'}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6A7875))),
              ]),
            ),
    );
  }
}
