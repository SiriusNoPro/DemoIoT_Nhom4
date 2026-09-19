# Đối chiếu với Hướng dẫn Project IoT Chương 5

Tài liệu đối chiếu: `Huong_dan_Project_IoT_Chuong_5.docx`.

| Yêu cầu trong tài liệu | Kết quả | Minh chứng trong dự án |
|---|---|---|
| Docker Compose gồm PostgreSQL, EMQX, Spring Boot, React và simulator | Đạt | `docker-compose.yml` và smoke test |
| Tắt simulator khi dùng ESP32 thật | Đạt | `run-all-real.ps1` chỉ chạy `postgres emqx backend web` |
| ESP32/ESP32-S3, DHT22 GPIO15, LED GPIO2 | Đạt | `esp32-firmware/main/main.c`, `dht22.c` |
| Telemetry mỗi 5 giây, số thực và cảm biến chưa lắp là null | Đạt | Firmware gửi temperature, humidity, illuminance null và soilMoisture null |
| MQTT topic, QoS và retain đúng contract | Đạt | Telemetry QoS 0; command/ACK/status QoS 1; status retained |
| Parse command bằng cJSON và giữ nguyên commandId trong ACK | Đạt | `handle_command()` trong firmware |
| SNTP và timestamp ISO 8601 UTC | Đạt | `esp_netif_sntp` và `utc_now()` |
| ONLINE retained và OFFLINE retained bằng Last Will | Đạt | Cấu hình `session.last_will` trước khi start MQTT |
| Web và Flutter xem dữ liệu, điều khiển LED | Đạt | Đã kiểm thử ONLINE, telemetry, LED_ON/OFF và ACK trên ESP32 thật |
| Viewer không được điều khiển | Đạt | API trả HTTP 403 trong smoke test |
| Chức năng nâng cao | Đạt | Cảnh báo nhiệt độ trên 35 °C ở web và mobile |
| README, sơ đồ chân và báo cáo PDF | Đạt | `README.md`, `docs/demo-tuan-4.md`, `docs/bao-cao-trien-khai.pdf` |

## Khác biệt có chủ đích

- Board thực tế là ESP32-S3 nên target là `esp32s3`; tài liệu cho phép ESP32 hoặc ESP32-S3 phù hợp firmware.
- Web dùng cổng `3000`, MQTT host dùng `1884`, EMQX Dashboard dùng `18084` để tránh xung đột cổng trên máy. Cổng nội bộ Docker vẫn là `80`, `1883` và `18083`.
- Android Emulator dùng `http://10.0.2.2:8080/api/v1`, đúng yêu cầu tài liệu.

## Minh chứng còn cần quay hoặc chụp khi nộp

- Rút nguồn ESP32 để ghi lại trạng thái OFFLINE do Last Will, sau đó cắm lại để ONLINE.
- Chụp website và mobile cùng hiển thị dữ liệu DHT22 thật.
- Video 5–7 phút theo đúng trình tự trong tài liệu.
