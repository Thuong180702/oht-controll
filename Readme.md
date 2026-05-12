# Nguyên lý chương trình App Manual Control & Monitoring OHT

## 1. Mục tiêu hệ thống

Ứng dụng Flutter này được thiết kế để chạy trước tiên trên Windows, phục vụ nhân viên sản xuất và bảo trì trong việc:

- Giám sát trạng thái hoạt động của OHT.
- Kiểm tra trạng thái động cơ, cảm biến và kết nối.
- Điều khiển OHT ở chế độ manual khi cần kiểm tra, căn chỉnh hoặc bảo trì.
- Hiển thị cảnh báo an toàn khi OHT gặp lỗi, mất kết nối hoặc phát hiện vật cản.

OHT trong hệ thống có tổng cộng 6 động cơ và nhiều nhóm cảm biến an toàn. App không thay thế hoàn toàn bộ điều khiển an toàn phần cứng, mà đóng vai trò giao diện vận hành, giám sát và gửi lệnh manual đến bộ điều khiển OHT.

---

## 2. Cấu trúc phần cứng OHT

### 2.1. Nhóm động cơ

OHT có 6 động cơ, chia thành 3 nhóm chính:

| Nhóm | Số lượng | Chức năng |
|---|---:|---|
| Steering Motor | 2 | Rẽ hướng trước và sau |
| Traveling Motor | 2 | Di chuyển trước và sau |
| Hoisting Motor | 2 | Nâng/hạ trước và sau |

Chi tiết:

1. `steer_front`: động cơ rẽ hướng phía trước.
2. `steer_rear`: động cơ rẽ hướng phía sau.
3. `travel_front`: động cơ di chuyển phía trước.
4. `travel_rear`: động cơ di chuyển phía sau.
5. `hoist_front`: động cơ nâng phía trước.
6. `hoist_rear`: động cơ nâng phía sau.

---

### 2.2. Nhóm cảm biến

| Nhóm cảm biến | Số lượng | Chức năng |
|---|---:|---|
| Steering position sensors | 4 | Xác định vị trí trái/phải cho 2 động cơ rẽ hướng |
| Hoist upper limit sensors | 2 | Giới hạn trên cho 2 động cơ nâng |
| Pumper sensors | 2 | Phát hiện trạng thái pumper trước/sau |
| Step lidar sensors | 2 | Phát hiện vật cản phía trước OHT theo 2 mức cảnh báo |

Chi tiết:

1. Cảm biến rẽ hướng:
   - `steer_front_left`
   - `steer_front_right`
   - `steer_rear_left`
   - `steer_rear_right`

2. Cảm biến giới hạn trên:
   - `hoist_front_upper_limit`
   - `hoist_rear_upper_limit`

3. Cảm biến pumper:
   - `pumper_front`
   - `pumper_rear`

4. Cảm biến lidar dạng bậc:
   - `lidar_upper`
   - `lidar_lower`

Mỗi lidar có 3 trạng thái logic:

| Giá trị | Ý nghĩa |
|---:|---|
| 0 | Không phát hiện vật cản |
| 1 | Vùng cảnh báo |
| 2 | Vùng nguy hiểm |

---

## 3. Nguyên lý giao tiếp giữa App và OHT

App giao tiếp với bộ điều khiển OHT qua Wi-Fi. Giao thức có thể dùng một trong hai phương án:

1. WebSocket
2. MQTT

Trong giai đoạn triển khai Windows đầu tiên, nên thiết kế tầng giao tiếp theo dạng interface chung để có thể chuyển đổi giữa WebSocket và MQTT mà không phải sửa toàn bộ giao diện.

Ví dụ cấu trúc service:

```text
CommunicationService
├── WebSocketCommunicationService
└── MqttCommunicationService
```

App chỉ gọi các hàm chung như:

```text
connect()
disconnect()
sendCommand()
listenTelemetry()
```

Phần giao thức cụ thể WebSocket hoặc MQTT được xử lý bên trong service tương ứng.

---

## 4. Luồng dữ liệu chính

### 4.1. Luồng dữ liệu từ OHT về App

Bộ điều khiển OHT gửi dữ liệu trạng thái định kỳ về app, ví dụ mỗi 100 ms đến 500 ms.

Dữ liệu nhận về gồm:

- Trạng thái kết nối.
- Chế độ hoạt động: manual, auto, maintenance, error.
- Trạng thái 6 động cơ.
- Trạng thái toàn bộ cảm biến.
- Mức cảnh báo lidar.
- Mã lỗi nếu có.
- Trạng thái emergency stop nếu có.
- Timestamp của gói dữ liệu.

App nhận dữ liệu, parse thành model nội bộ, sau đó cập nhật UI theo thời gian thực.

---

### 4.2. Luồng lệnh từ App xuống OHT

Khi người dùng nhấn nút điều khiển manual, app gửi lệnh xuống bộ điều khiển OHT.

Ví dụ các nhóm lệnh:

- Di chuyển tiến/lùi.
- Dừng di chuyển.
- Rẽ trái/phải.
- Dừng rẽ.
- Nâng/hạ.
- Dừng nâng/hạ.
- Reset lỗi.
- Bật/tắt chế độ manual.
- Emergency stop.

Lệnh gửi xuống nên có cấu trúc rõ ràng, ví dụ:

```json
{
  "type": "command",
  "command": "travel_forward",
  "target": "both",
  "speed": 30,
  "requestId": "cmd_0001",
  "timestamp": 1710000000000
}
```

Bộ điều khiển OHT nên phản hồi lại kết quả thực hiện lệnh:

```json
{
  "type": "ack",
  "requestId": "cmd_0001",
  "success": true,
  "message": "Command accepted"
}
```

---

## 5. Nguyên tắc an toàn khi điều khiển manual

Ứng dụng phải ưu tiên an toàn khi vận hành OHT. Các nguyên tắc chính:

1. Chỉ cho phép điều khiển khi OHT đang ở chế độ manual.
2. Nếu mất kết nối, app phải tự động chuyển UI sang trạng thái không cho gửi lệnh.
3. Nếu lidar báo vùng nguy hiểm, app phải hiển thị cảnh báo rõ ràng và không cho phép tiếp tục di chuyển về phía nguy hiểm.
4. Nếu cảm biến giới hạn trên của motor nâng đang kích hoạt, không cho phép tiếp tục nâng theo hướng vượt giới hạn.
5. Các nút điều khiển nên hoạt động theo kiểu nhấn giữ, thả ra thì gửi lệnh dừng.
6. Lệnh emergency stop phải luôn hiển thị rõ ràng, dễ nhấn và có độ ưu tiên cao nhất.
7. Tất cả lệnh manual nên có timeout hoặc heartbeat để tránh trường hợp OHT tiếp tục chạy khi app bị treo hoặc mất mạng.

---

## 6. Thiết kế màn hình chính

Màn hình chính nên chia thành các vùng chức năng:

### 6.1. Header trạng thái

Hiển thị:

- Tên hệ thống.
- Trạng thái kết nối.
- IP hoặc broker đang kết nối.
- Chế độ hiện tại của OHT.
- Nút Connect/Disconnect.
- Nút Emergency Stop.

### 6.2. Panel điều khiển manual

Gồm các nhóm nút:

1. Travel Control:
   - Forward
   - Backward
   - Stop

2. Steering Control:
   - Front Left
   - Front Right
   - Rear Left
   - Rear Right
   - Stop Steering

3. Hoist Control:
   - Front Up
   - Front Down
   - Rear Up
   - Rear Down
   - Stop Hoist

Có thể thêm slider điều chỉnh tốc độ hoặc phần trăm công suất.

### 6.3. Panel trạng thái động cơ

Hiển thị 6 card động cơ:

- Tên động cơ.
- Trạng thái running/stopped/error.
- Chiều chuyển động.
- Tốc độ hiện tại.
- Dòng điện hoặc lỗi nếu dữ liệu có sẵn.

### 6.4. Panel trạng thái cảm biến

Hiển thị toàn bộ cảm biến theo dạng đèn trạng thái:

- Xanh: bình thường.
- Vàng: cảnh báo.
- Đỏ: nguy hiểm hoặc lỗi.
- Xám: không có dữ liệu hoặc mất kết nối.

### 6.5. Panel cảnh báo và log

Hiển thị:

- Cảnh báo lidar.
- Cảnh báo giới hạn hành trình.
- Lỗi mất kết nối.
- Log các lệnh đã gửi.
- Log phản hồi từ OHT.

---

## 7. Kiến trúc phần mềm đề xuất

Cấu trúc thư mục Flutter nên tách rõ theo chức năng:

```text
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   ├── enums/
│   ├── theme/
│   └── utils/
├── features/
│   └── oht_manual/
│       ├── data/
│       │   ├── models/
│       │   └── services/
│       ├── domain/
│       │   ├── entities/
│       │   └── repositories/
│       └── presentation/
│           ├── screens/
│           ├── widgets/
│           └── controllers/
└── mock/
    └── mock_oht_data.dart
```

Trong giai đoạn đầu, nên có chế độ mock/simulation để test UI khi chưa kết nối OHT thật.

---

## 8. Model dữ liệu gợi ý

### 8.1. OHT telemetry

```json
{
  "type": "telemetry",
  "mode": "manual",
  "connected": true,
  "emergencyStop": false,
  "motors": {
    "steerFront": {"state": "stopped", "direction": "left", "speed": 0},
    "steerRear": {"state": "stopped", "direction": "right", "speed": 0},
    "travelFront": {"state": "running", "direction": "forward", "speed": 30},
    "travelRear": {"state": "running", "direction": "forward", "speed": 30},
    "hoistFront": {"state": "stopped", "direction": "up", "speed": 0},
    "hoistRear": {"state": "stopped", "direction": "up", "speed": 0}
  },
  "sensors": {
    "steerFrontLeft": false,
    "steerFrontRight": true,
    "steerRearLeft": false,
    "steerRearRight": true,
    "hoistFrontUpperLimit": false,
    "hoistRearUpperLimit": false,
    "pumperFront": false,
    "pumperRear": false,
    "lidarUpper": 0,
    "lidarLower": 1
  },
  "errors": [],
  "timestamp": 1710000000000
}
```

### 8.2. Manual command

```json
{
  "type": "command",
  "command": "travel_forward",
  "target": "both",
  "speed": 30,
  "requestId": "cmd_0001",
  "timestamp": 1710000000000
}
```

---

## 9. Nguyên lý xử lý mất kết nối

App cần kiểm tra heartbeat hoặc timestamp của telemetry.

Nếu quá một khoảng thời gian nhất định không nhận được dữ liệu mới, ví dụ 2 giây:

1. Đánh dấu trạng thái là disconnected.
2. Disable toàn bộ nút điều khiển manual.
3. Hiển thị cảnh báo mất kết nối.
4. Ghi log sự kiện.
5. Yêu cầu người dùng kết nối lại trước khi điều khiển tiếp.

---

## 10. Nguyên lý phát triển theo giai đoạn

### Giai đoạn 1: Windows UI + Mock Data

- Tạo giao diện chính.
- Tạo model dữ liệu OHT.
- Tạo mock telemetry.
- Hiển thị trạng thái động cơ và cảm biến.
- Cho phép nhấn nút manual nhưng chỉ ghi log, chưa gửi xuống OHT thật.

### Giai đoạn 2: WebSocket

- Thêm WebSocket service.
- Kết nối đến IP của bộ điều khiển OHT.
- Nhận telemetry thật.
- Gửi command thật.
- Xử lý ACK/NACK.

### Giai đoạn 3: MQTT

- Thêm MQTT service nếu cần.
- Thiết kế topic:
  - `oht/telemetry`
  - `oht/command`
  - `oht/ack`
  - `oht/error`

### Giai đoạn 4: Safety & Maintenance Mode

- Thêm rule interlock.
- Thêm cảnh báo chi tiết.
- Thêm log lưu file local.
- Thêm màn hình cấu hình kết nối.
- Thêm màn hình diagnostic cho bảo trì.

---

## 11. Nguyên tắc thiết kế UI

UI cần rõ ràng, dễ nhìn trong môi trường sản xuất:

- Ưu tiên chữ lớn.
- Màu trạng thái rõ ràng.
- Nút điều khiển lớn, dễ bấm.
- Emergency Stop luôn nổi bật.
- Không nhồi quá nhiều thông tin vào một màn hình nhỏ.
- Trạng thái lỗi phải dễ nhận biết trong vài giây.
- Có chế độ dark theme để dùng trong khu vực nhà máy.

---

## 12. Ghi chú triển khai ban đầu

Trong phiên bản đầu tiên, app nên chạy ổn định trên Windows trước. Sau khi hoàn thành logic và giao diện desktop, có thể mở rộng sang Android tablet hoặc thiết bị khác nếu cần.

Các phần cần ưu tiên trước:

1. Kiến trúc project sạch.
2. UI dashboard manual dễ dùng.
3. Mock data để test nhanh.
4. Tầng giao tiếp có thể thay WebSocket/MQTT.
5. Safety interlock cơ bản.
6. Log điều khiển và cảnh báo.
