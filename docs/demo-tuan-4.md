# Hướng dẫn demo tuần 4 — ESP32 + DHT22 3 chân + LED

## 1. Trạng thái đã chuẩn bị

- Web: `http://localhost:3000`
- Backend/Swagger: `http://localhost:8080/swagger-ui/index.html`
- EMQX Dashboard: `http://localhost:18084` — `admin / public`
- MQTT cho ESP32: `10.32.83.195:1884`
- Thiết bị: `esp32-001`
- Tài khoản demo: `operator / Operator@123`

Nếu máy đổi Wi-Fi, chạy `ipconfig`, lấy dòng **IPv4 Address** của Wi-Fi và sửa `MQTT_BROKER_URL` trong `esp32-firmware/main/main.c`.

Để thiết bị trong mạng LAN truy cập được MQTT/API, mở **PowerShell bằng Run as administrator** một lần rồi chạy:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure-firewall.ps1
```

Phiên thiết lập tự động hiện tại không có quyền Administrator để tạo rule firewall. Kiểm tra cục bộ cho thấy cả cổng 1884 và 8080 đang lắng nghe.

## 2. Cắm DHT22 loại 3 chân

Hãy nhìn **chữ in cạnh chân trên module**. Không dựa vào thứ tự trái/phải vì module của các hãng có thể đảo chân.

| Chân ghi trên DHT22 | Cắm vào ESP32 |
|---|---|
| `VCC`, `+` hoặc `3V3` | `3V3` |
| `DATA`, `OUT` hoặc `S` | `GPIO15` |
| `GND` hoặc `-` | `GND` |

Module 3 chân thường đã có điện trở kéo lên trên bo mạch. Chỉ thêm điện trở **4.7–10 kΩ giữa DATA và 3V3** nếu module đọc lỗi liên tục. Dùng nguồn 3V3 để an toàn.

## 3. Cắm LED rời

```text
GPIO2 ── điện trở 220–330 Ω ── chân dài LED (+)
GND   ──────────────────────── chân ngắn LED (-)
```

- Chân dài là anode `+`.
- Chân ngắn và cạnh bẹt trên vỏ LED là cathode `-`.
- Bắt buộc dùng điện trở hạn dòng; chiều đặt điện trở trước hay sau LED đều được.
- Tất cả thiết bị phải dùng chung GND.
- Nếu board có LED tích hợp ở GPIO2, có thể demo bằng LED tích hợp mà không cắm LED rời.

## 4. Trình tự chạy demo

### Demo bằng simulator

```powershell
cd "D:\Coder\IoT\Tuan 4\reference"
docker compose up -d
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\smoke-test.ps1
```

Mở web, đăng nhập operator, xem dữ liệu và thử LED. Trước khi chuyển sang ESP32 thật:

```powershell
docker compose stop simulator
```

### Cấu hình và flash ESP32

Mở ESP-IDF terminal tại `esp32-firmware`:

```powershell
idf.py menuconfig
```

Vào **Example Connection Configuration**, nhập SSID và mật khẩu Wi-Fi. Máy tính và ESP32 phải cùng mạng. Sau đó:

```powershell
idf.py build
idf.py -p COMx flash monitor
```

Thay `COMx` bằng cổng xuất hiện sau khi cắm ESP32. Log đúng phải có `MQTT_EVENT_CONNECTED`, `Published ONLINE status`, telemetry DHT22 và ACK khi bấm LED.

## 5. Kịch bản trình bày nhanh

1. Chỉ dây DHT22 và LED theo bảng trên.
2. Cho thấy container simulator đã dừng.
3. Reset ESP32 và chỉ log ONLINE.
4. Mở web, chỉ nhiệt độ và độ ẩm thật cập nhật sau khoảng 5 giây.
5. Bật/tắt LED từ web và chỉ LED vật lý cùng ACK.
6. Rút nguồn ESP32 để trạng thái chuyển OFFLINE, cắm lại để ONLINE.

Nếu ESP32 không kết nối MQTT, kiểm tra lại IP Wi-Fi của máy, cổng 1884, Windows Firewall và đảm bảo mạng không bật client isolation.
