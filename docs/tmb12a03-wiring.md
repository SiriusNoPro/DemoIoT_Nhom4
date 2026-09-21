# Cắm và điều khiển còi TMB12A03

TMB12A03 là còi điện từ chủ động 3 V. Chỉ cần cấp điện DC để còi phát âm; firmware đóng cắt nguồn bằng `GPIO7` và transistor NPN.

## Linh kiện

- Còi TMB12A03 3 V
- Transistor NPN S8050, 2N2222 hoặc BC547
- Điện trở Base 1 kΩ
- Điện trở kéo xuống 10 kΩ
- Diode 1N4148 hoặc 1N4007

## Đấu dây

| Điểm nối | Kết nối |
|---|---|
| Cực `+` của còi | `3V3` ESP32-S3 |
| Cực `-` của còi | Collector transistor |
| GPIO7 | Qua điện trở 1 kΩ đến Base transistor |
| Base transistor | Qua điện trở 10 kΩ xuống GND |
| Emitter transistor | GND |
| Diode cathode, đầu có vạch | Cực `+` còi/3V3 |
| Diode anode | Cực `-` còi/Collector |

Kiểm tra datasheet hoặc chữ in của transistor trước khi cắm vì thứ tự E-B-C thay đổi theo loại. GND của ESP32 và mạch còi phải nối chung.

## Điều khiển

- Web và Android gửi `BUZZER_ON` để bật.
- Web và Android gửi `BUZZER_OFF` để tắt.
- ESP32 trả ACK kèm trường `buzzer` và backend lưu `buzzerState`.
- Khi reset, GPIO7 được đưa về LOW nên còi mặc định tắt.
