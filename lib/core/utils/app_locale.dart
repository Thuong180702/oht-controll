class AppLocale {
  const AppLocale._();

  static String _languageCode = 'vi';

  static void setLanguage(String languageCode) {
    _languageCode = languageCode == 'en' ? 'en' : 'vi';
  }

  static bool get isEnglish => _languageCode == 'en';

  static String t(String viText) {
    if (!isEnglish) return viText;
    return _english[viText] ?? viText;
  }

  static String eventCount(int count) {
    return isEnglish ? '$count events recorded' : '$count sự kiện đã ghi nhận';
  }

  static const Map<String, String> _english = {
    // Login
    'Đăng nhập hệ thống': 'System Login',
    'Mã Terminal: VN-40': 'Terminal ID: VN-40',
    'MÃ NGƯỜI VẬN HÀNH': 'OPERATOR ID',
    'Nhập mã nhân viên vận hành': 'Enter operator ID',
    'Nhập tên đăng nhập': 'Enter username',
    'MÃ KHÓA BẢO MẬT': 'SECURITY KEY',
    'Nhập mật khẩu': 'Enter password',
    'Hiện mật khẩu': 'Show password',
    'Ẩn mật khẩu': 'Hide password',
    'ĐANG XÁC THỰC...': 'AUTHENTICATING...',
    'XÁC THỰC VÀ ĐĂNG NHẬP': 'VERIFY AND LOGIN',
    'Ổn định': 'Stable',
    'Hệ Thống Điều khiển\nOHT': 'OHT Control\nSystem',
    'Hệ thống vận chuyển tự động Overhead Hoist Transport trong nhà máy sản xuất, hỗ trợ vận hành thủ công và giám sát an toàn theo thời gian thực.':
        'Automatic Overhead Hoist Transport control system for factory operation, manual control, and real-time safety monitoring.',
    'PHIÊN BẢN': 'VERSION',
    'Sai tên đăng nhập hoặc mật khẩu.': 'Invalid username or password.',

    // Common/top bar
    'DỪNG KHẨN CẤP': 'EMERGENCY STOP',
    'Dừng khẩn cấp': 'Emergency stop',
    'Ngắt kết nối': 'Disconnect',
    'Đăng xuất': 'Log out',
    'Đổi mật khẩu': 'Change password',

    // Connection
    'Không kết nối được. Không nhận dữ liệu trong 3 giây.':
        'Connection failed. No data received within 3 seconds.',
    'Trạng thái hiện tại': 'Current Status',
    'KẾT NỐI': 'CONNECT',
    'Mạng không dây (WLAN)\nBảo mật & Chứng chỉ':
        'Wireless network (WLAN)\nSecurity & Certificates',
    'Cấu hình giao thức kết nối': 'Connection Protocol',
    'ĐỊA CHỈ IP / HOST': 'IP ADDRESS / HOST',
    'CỔNG (PORT)': 'PORT',
    'CẤU TRÚC TOPIC CƠ BẢN / BASE TOPIC': 'BASE TOPIC STRUCTURE',
    'Yêu cầu xác thực': 'Require authentication',
    'TÊN ĐĂNG NHẬP': 'USERNAME',
    'MẬT KHẨU': 'PASSWORD',
    'Chế độ Mock (Demo)': 'Mock Mode (Demo)',
    'ĐANG KẾT NỐI...': 'CONNECTING...',
    'Giao tiếp thời gian thực qua WebSocket.':
        'Real-time communication through WebSocket.',
    'Tối ưu cho gateway và broker.': 'Optimized for gateway and broker.',
    'Mô phỏng cục bộ để kiểm thử.': 'Local simulation for testing.',

    // Dashboard
    'Trực tuyến': 'Online',
    'Ngoại tuyến': 'Offline',
    'NGUY HIỂM': 'DANGER',
    'CẢNH BÁO': 'WARNING',
    'CHẾ ĐỘ': 'MODE',
    'TỌA ĐỘ': 'COORDINATES',
    'VỊ TRÍ Z': 'Z POSITION',
    'TỐC ĐỘ': 'SPEED',
    'LỖI': 'ERRORS',
    'HƯỚNG LÁI': 'STEERING',
    'TRẠNG THÁI': 'STATUS',
    'Trạng Thái (Telemetry)': 'Telemetry Status',
    'Điều Khiển Thủ Công': 'Manual Control',
    'TIẾN': 'FORWARD',
    'TRÁI': 'LEFT',
    'PHẢI': 'RIGHT',
    'LÙI': 'BACKWARD',
    'NÂNG': 'UP',
    'HẠ': 'DOWN',
    'Bản Đồ Hệ Thống': 'System Map',
    'Đường Rail OHT': 'OHT Rail',
    'Vùng an toàn': 'Safe Zone',
    'Lỗi hệ thống': 'System Fault',
    'Thiết bị đang dừng/lỗi. Nhấn Clear Error để reset.':
        'Device is stopped or in fault. Press Clear Error to reset.',
    'ĐANG SẠC': 'CHARGING',

    // Diagnostics
    'Chẩn đoán phần cứng': 'Hardware Diagnostics',
    'Giám sát 6 động cơ và cảm biến an toàn theo thời gian thực':
        'Monitor 6 motors and safety sensors in real time',
    'ĐIỀU KHIỂN NÂNG CAO': 'ADVANCED CONTROL',
    'Động cơ di chuyển': 'Travel Motors',
    'Động cơ rẽ hướng': 'Steering Motors',
    'Động cơ nâng hạ': 'Hoist Motors',
    'Di chuyển trước': 'Travel Front',
    'Di chuyển sau': 'Travel Rear',
    'Rẽ hướng trước': 'Steer Front',
    'Rẽ hướng sau': 'Steer Rear',
    'Nâng hạ trước': 'Hoist Front',
    'Nâng hạ sau': 'Hoist Rear',
    'ĐỘ CAO': 'HEIGHT',
    'VỊ TRÍ': 'POSITION',
    'VẬN TỐC': 'VELOCITY',
    'Lidar trên': 'Upper Lidar',
    'Lidar dưới': 'Lower Lidar',
    'Bumper trước': 'Front Bumper',
    'Bumper sau': 'Rear Bumper',
    'Rẽ trước trái': 'Front Steer Left',
    'Rẽ trước phải': 'Front Steer Right',
    'Rẽ sau trái': 'Rear Steer Left',
    'Rẽ sau phải': 'Rear Steer Right',
    'Nâng trước trên': 'Front Hoist Upper',
    'Nâng sau trên': 'Rear Hoist Upper',
    'Cảm biến vật cản': 'Obstacle Sensors',
    'Giới hạn rẽ hướng': 'Steering Limits',
    'Giới hạn nâng hạ': 'Hoist Limits',
    'Điều khiển riêng 6 động cơ với chiều chạy và vận tốc độc lập':
        'Control 6 motors independently by direction and speed',
    'Đóng': 'Close',
    'Tiến': 'Forward',
    'Lùi': 'Backward',
    'Trái': 'Left',
    'Phải': 'Right',
    'Nâng': 'Up',
    'Hạ': 'Down',
    'Vận tốc': 'Speed',

    // Logs
    'Tất cả': 'All',
    'Thông tin': 'Info',
    'Cảnh báo': 'Warning',
    'Lỗi/Nghiêm trọng': 'Fault/Critical',
    'Nhật ký hệ thống': 'System Log',
    'Xóa log': 'Clear Log',
    'Không có sự kiện phù hợp': 'No matching events',
    'Tìm kiếm nhật ký...': 'Search logs...',
    'Tất cả hệ thống': 'All systems',
    'XUẤT NHẬT KÝ': 'EXPORT LOG',
    'Đã tải log Excel': 'Excel log exported',
    'Không thể tải log Excel': 'Could not export Excel log',

    // Settings
    'Cài đặt hệ thống': 'System Settings',
    'Tài khoản vận hành, kết nối và giới hạn an toàn':
        'Operator account, connection, and interface preferences',
    'Tài khoản vận hành, kết nối và giao diện':
        'Operator account, connection, and interface preferences',
    'Hệ thống chung': 'General System',
    'Định danh đơn vị': 'Unit ID',
    'Ngôn ngữ giao diện': 'Interface Language',
    'Tiếng Việt': 'Vietnamese',
    'Giao diện': 'Appearance',
    'Sáng': 'Light',
    'Tối': 'Dark',
    'Múi giờ': 'Time Zone',
    'Giao thức': 'Protocol',
    'Thông tin vận hành': 'Operator Information',
    'Người vận hành': 'Operator',
    'Cập nhật firmware': 'Firmware Update',
    'Phiên bản hiện tại': 'Current Version',
    'Trạng thái': 'Status',
    'Đã cập nhật': 'Up to date',
    'Kênh phát hành': 'Release Channel',
    'Kiểm tra cập nhật': 'Check for updates',
    'Phiên làm việc': 'Session',
    'Ngắt kết nối để quay lại màn cấu hình giao thức.':
        'Disconnect to return to the protocol configuration screen.',
    'HỦY BỎ THAY ĐỔI': 'CANCEL CHANGES',
    'ÁP DỤNG CẤU HÌNH': 'APPLY CONFIGURATION',
  };
}
