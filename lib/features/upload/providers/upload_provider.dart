// =============================================================================
// UPLOAD PROVIDER — Bộ quản lý trạng thái màn hình Upload tài liệu
// =============================================================================
// LUỒNG THUẬT TOÁN CHÍNH:
//
//   [Người dùng chọn file PDF/TXT]
//         ↓
//   uploadFile(fileName, fileBytes)
//         ↓
//   [Bắt đầu animation progress: 0 → 0.4 trong 3 giây]  ← giả lập chờ server
//         ↓
//   [Gọi POST /documents/upload (multipart/form-data)]
//         ↓
//   Backend nhận file → trích xuất text → trả về ngay { document_id, status: "processing" }
//   (Backend tiếp tục embed + lưu Supabase ở background — không block HTTP)
//         ↓
//   [Animate progress 0.4 → 0.85 trong 2 giây]  ← giả lập AI đang tạo embeddings
//         ↓
//   [Animate progress → 1.0, hiển thị "Hoàn tất!"]
//
// THUẬT TOÁN ANIMATION (nội suy tuyến tính):
//   Mỗi 50ms cập nhật 1 lần. Tổng steps = durationMs / 50.
//   Tại bước tick thứ i: progress = start + diff × (i / steps)
//   Đây là Linear Interpolation (lerp): f(t) = A + (B - A) × t, với t ∈ [0, 1]
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants.dart';

class UploadProvider extends ChangeNotifier {
  // _isUploading = true → đang trong quá trình tải lên (hiển thị UploadingCard)
  bool _isUploading = false;

  // _progress ∈ [0.0, 1.0] → tiến độ thanh progress bar
  double _progress = 0.0;

  // Thông điệp mô tả bước hiện tại ("Đang gửi tài liệu...", "Đang tạo embeddings...")
  String _currentStep = '';

  // Tên file đang được tải lên (hiển thị trên UI)
  String _currentFileName = '';

  // Timer dùng cho thuật toán nội suy tuyến tính của progress bar
  Timer? _progressTimer;

  String? _lastDocumentId;

  bool get isUploading => _isUploading;
  double get progress => _progress;
  String get currentStep => _currentStep;
  String get currentFileName => _currentFileName;
  String? get lastDocumentId => _lastDocumentId;

  /// Tải file lên backend và cập nhật trạng thái UI theo từng bước.
  ///
  /// [fileName] — tên file (vd: "bai_giang.pdf")
  /// [fileBytes] — nội dung file dưới dạng bytes (đọc từ FilePicker)
  ///
  /// Trả về true nếu thành công, false nếu lỗi.
  /// Upload file vào notebook cụ thể.
  ///
  /// [notebookId] REQUIRED — mỗi file phải thuộc 1 notebook (document isolation)
  Future<bool> uploadFile(
    String fileName,
    List<int> fileBytes, {
    required String notebookId,  // REQUIRED — backend yêu cầu
  }) async {
    if (notebookId.isEmpty) {
      _currentStep = 'Lỗi: Chưa chọn notebook';
      _isUploading = false;
      notifyListeners();
      return false;
    }

    _isUploading = true;
    _progress = 0.0;
    _currentFileName = fileName;
    _currentStep = 'Đang gửi tài liệu lên server...';
    notifyListeners();

    // Giai đoạn 1: Animate progress 0% → 40% trong 3 giây
    // Mục đích: cho người dùng thấy "có gì đó đang xảy ra" khi đợi HTTP request
    _startProgressAnimation(to: 0.4, durationMs: 3000);

    try {
      // Kiểm tra người dùng đã đăng nhập chưa
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _reset();
        return false;
      }

      // Lấy Firebase ID Token để đính kèm vào header Authorization
      final idToken = await user.getIdToken();

      // Xác định Content-Type dựa trên phần mở rộng file
      // Backend (PyMuPDF) cần biết loại file để xử lý đúng cách
      final ext = fileName.split('.').last.toLowerCase();
      final contentType = ext == 'pdf'
          ? MediaType('application', 'pdf')    // MIME type: application/pdf
          : MediaType('text', 'plain');          // MIME type: text/plain

      // Tạo multipart request — định dạng gửi file qua HTTP
      // multipart/form-data: mỗi phần có header riêng (name, filename, content-type)
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.backendBaseUrl}/documents/upload'),
      )
        ..headers['Authorization'] = 'Bearer $idToken'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: contentType,
        ))
        // notebook_id REQUIRED — backend yêu cầu document phải thuộc notebook
        ..fields['notebook_id'] = notebookId;

      _currentStep = 'Đang tải lên và trích xuất dữ liệu...';
      notifyListeners();

      // Gửi request, timeout 60 giây (file PDF lớn có thể mất nhiều thời gian)
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final body = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        // Response: { "document_id": "uuid", "status": "processing" }
        try {
          final json = jsonDecode(body);
          _lastDocumentId = json['document_id'] as String?;
        } catch (_) {}


        // Giai đoạn 2: Animate 40% → 85% trong 2 giây
        // Giả lập "AI đang tạo embeddings" (thực ra backend làm async)
        _progressTimer?.cancel();
        _currentStep = 'Đang tạo embeddings AI...';
        _startProgressAnimation(to: 0.85, durationMs: 2000);
        await Future.delayed(const Duration(seconds: 2));

        // Giai đoạn 3: Hoàn tất — set progress = 100% ngay lập tức
        _progressTimer?.cancel();
        _currentStep = 'Hoàn tất!';
        _progress = 1.0;
        _isUploading = false;
        notifyListeners();
        return true;
      } else {
        debugPrint('Upload thất bại [${streamedResponse.statusCode}]: $body');
        _reset();
        return false;
      }
    } catch (e) {
      debugPrint('Lỗi tải lên: $e');
      _reset();
      return false;
    }
  }

  /// Thuật toán nội suy tuyến tính (Linear Interpolation) cho progress bar.
  ///
  /// Công thức: progress(t) = start + (to - start) × t, với t ∈ [0, 1]
  ///
  /// Ví dụ: start=0.0, to=0.4, durationMs=3000
  ///   → steps = 3000 / 50 = 60 bước
  ///   → Mỗi 50ms tăng thêm 0.4/60 ≈ 0.0067
  ///   → Sau 3 giây (60 bước): progress = 0.4
  ///
  /// Lý do dùng Timer.periodic thay vì AnimationController:
  ///   Provider không có BuildContext nên không dùng được vsync.
  ///   Timer.periodic chạy ở Dart event loop, không cần Widget tree.
  void _startProgressAnimation({required double to, required int durationMs}) {
    _progressTimer?.cancel(); // Huỷ animation cũ nếu đang chạy

    final start = _progress;          // Giá trị bắt đầu (điểm A)
    final diff = to - start;          // Khoảng cần đi (B - A)
    final steps = (durationMs / 50).round(); // Tổng số bước (mỗi bước = 50ms)
    int tick = 0;                     // Bộ đếm bước hiện tại

    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      tick++;

      // Nội suy tuyến tính: tỷ lệ hoàn thành = tick / steps ∈ [0, 1]
      _progress = start + diff * (tick / steps);

      if (tick >= steps) {
        // Đã đạt đích → gán chính xác (tránh lỗi float) và dừng timer
        _progress = to;
        t.cancel();
      }

      notifyListeners(); // Thông báo UI cập nhật thanh progress
    });
  }

  /// Reset toàn bộ trạng thái về ban đầu (khi lỗi hoặc huỷ).
  void _reset() {
    _progressTimer?.cancel();
    _isUploading = false;
    _progress = 0.0;
    _currentStep = '';
    notifyListeners();
  }

  /// Cho phép người dùng huỷ upload đang diễn ra.
  void cancelUpload() => _reset();

  @override
  void dispose() {
    _progressTimer?.cancel(); // Quan trọng: dừng timer khi Provider bị huỷ
    super.dispose();
  }
}
