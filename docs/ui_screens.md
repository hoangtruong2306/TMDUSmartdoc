# TMDUSmartdoc — Tổng hợp Giao diện (UI Screens)

> Cập nhật: 2026-05-22  
> Stack: Flutter · GoRouter · Provider · Material 3

---

## Sơ đồ điều hướng tổng thể

```
/splash
  ├─ user đã đăng nhập  → /home
  └─ chưa đăng nhập     → /login

/login
  ├─ /register
  └─ /forgot-password

┌── ShellRoute (MainScaffold — BottomNavigationBar) ──────────────┐
│   /home         Tab 1 – Tài liệu                               │
│   /notebooks    Tab 2 – Notebooks                              │
│   /upload       Tab 3 – Tải lên                                │
│   /chat         Tab 4 – Chat AI                                │
│   /profile      Tab 5 – Hồ sơ                                  │
└─────────────────────────────────────────────────────────────────┘

/notebook/:id                       → NotebookDetailScreen
/notebook/:id/upload                → UploadScreen (từ notebook)
/quiz/:notebookId                   → QuizScreen
/quiz/history/:notebookId           → QuizHistoryScreen
/quiz/review/:sessionId             → QuizReviewScreen
/flashcards/:notebookId             → FlashCardSetupScreen → FlashCardStudyScreen
/flashcards/history/:notebookId     → FlashCardHistoryScreen
```

**Auth Guard:** Mọi route `protected` (`/home`, `/notebooks`, `/notebook`, `/upload`, `/chat`, `/profile`, `/quiz`, `/flashcards`) → redirect `/login` nếu chưa đăng nhập.

**Page transition:** `FadeTransition` + `SlideTransition` (y: 0.04 → 0) — hiệu ứng "trôi nhẹ lên" cho tất cả màn hình.

---

## 1. Màn hình Splash — `/splash`

**File:** `lib/features/splash/splash_screen.dart`

| Thành phần | Mô tả |
|-----------|-------|
| Background | Gradient `primaryDark → primary → #3B82F6` (top-left → bottom-right) |
| Icon sách | `Icons.auto_stories_rounded` — scale từ 0.3 → 1 (Elastic Out) + xoay lắc lư lặp lại |
| Glow rings | 2 vòng tròn trắng mờ pulse thay đổi scale liên tục |
| App name | "TDMU SmartDoc" — fadeIn + slideY (delay 700ms) |
| Tagline | "Trợ lý Học tập AI của Bạn" — fadeIn (delay 1000ms) |
| Loading dots | 3 chấm tròn bounce lên xuống lệch nhau 150ms |
| Logic | Chờ 2.4s + `FirebaseAuth.authStateChanges` → điều hướng `/home` hoặc `/login` |

---

## 2. Đăng nhập — `/login`

**File:** `lib/features/auth/login_screen.dart`

| Thành phần | Mô tả |
|-----------|-------|
| Icon | `Icons.auto_awesome` màu primary, scale-in animation |
| Tiêu đề | "Chào mừng quay trở lại" |
| Form card | Email field + Password field (có toggle ẩn/hiện) |
| Link | "Quên mật khẩu?" → `/forgot-password` |
| Error banner | Hiện lỗi Firebase Auth với nền đỏ nhạt |
| Nút | "Đăng nhập" (FilledButton, loading spinner khi đang xử lý) |
| Link đăng ký | "Chưa có tài khoản? Đăng ký" → push `/register` |
| Divider | "HOẶC" |
| Google button | OutlinedButton "Tiếp tục với Google" (Google Sign-In) |
| Responsive | `maxWidth: 420` (compact) / `460` (wide) |

---

## 3. Đăng ký — `/register`

**File:** `lib/features/auth/register_screen.dart`

| Thành phần | Mô tả |
|-----------|-------|
| Icon | `Icons.auto_awesome` màu primary |
| Tiêu đề | "Tạo tài khoản" |
| Form card | Họ tên + Email + Mật khẩu + Xác nhận mật khẩu |
| Validation | Mật khẩu ≥ 6 ký tự; xác nhận khớp (client-side) |
| Error banner | Lỗi Firebase hiển thị trong form |
| Nút | "Đăng ký" → tạo tài khoản + điều hướng `/home` |
| Link | "Đã có tài khoản? Đăng nhập" → pop về `/login` |

---

## 4. Quên mật khẩu — `/forgot-password`

**File:** `lib/features/auth/forgot_password_screen.dart`

| State | Mô tả |
|-------|-------|
| **Nhập email** | Icon `Icons.lock_reset` + field email + nút "Gửi email đặt lại" |
| **Đã gửi** | Icon `Icons.mark_email_read_outlined` + thông báo kiểm tra email (kể cả spam) + nút "Gửi lại" |
| Quay lại | TextButton "Quay lại đăng nhập" → pop |

---

## 5. Trang chủ — Tài liệu — `/home`

**File:** `lib/features/home/home_screen.dart`

| Thành phần | Mô tả |
|-----------|-------|
| AppBar area | Tiêu đề "Tài liệu" + subtitle + avatar tròn |
| Search bar | TextField tìm kiếm realtime (clear button khi có text) |
| Section label | "Tài liệu gần đây" + đếm tổng |
| **Loading** | Grid skeleton 6 cards (DocumentCardSkeleton) |
| **Rỗng** | EmptyState với icon + CTA "Tải lên" |
| **Có dữ liệu** | Responsive grid (cột tự động theo breakpoint) |
| Document card | Icon loại file (PDF đỏ / TXT tím) + tên + số trang + ngày + ⋮ menu · Tap → điều hướng `/chat` với context tài liệu |
| FAB | `FloatingActionButton.extended` "Tải lên" → `/upload` |
| Pull-to-refresh | `RefreshIndicator` |

---

## 6. Notebooks — `/notebooks`

**File:** `lib/features/notebooks/notebooks_screen.dart`

| Thành phần | Mô tả |
|-----------|-------|
| Header | "Notebooks" + subtitle "Gom nhóm tài liệu và nhận tóm tắt từ AI" |
| **Loading** | Grid skeleton 4 cards |
| **Rỗng** | Illustration + CTA "Tạo notebook đầu tiên" |
| **Có dữ liệu** | Responsive grid (`childAspectRatio: 1.05`) |
| FAB | "Tạo mới" → mở dialog |

### Notebook Card
- Thanh màu (6px) trên đầu card theo màu notebook
- Icon lĩnh vực (12 loại: school, book, science, math, economics, computer, medical, history, art, language, law, idea)
- Tên notebook (2 dòng max)
- Summary AI (nếu có, 3 dòng max)
- Badge "N gợi ý" (nếu có suggestions)
- ⋮ menu → bottom sheet: **Xoá notebook** / **Chat với notebook này**

### Chế độ chọn nhiều (Selection Mode)
- Long press → activate selection mode
- AppBar đổi sang: `X đã chọn` + nút **Xoá** (màu đỏ)
- FAB ẩn đi
- Card hiện checkbox overlay

### Dialog tạo notebook
- TextField tên
- Bộ chọn màu: 6 màu tròn (tím/xanh/hồng/đỏ/xanh lá/cam)
- Bộ chọn icon: 12 icon dạng grid với nhãn
- Nút Huỷ / Tạo

---

## 7. Notebook Detail — `/notebook/:id`

**File:** `lib/features/notebook/screens/notebook_detail_screen.dart`

| Thành phần | Mô tả |
|-----------|-------|
| AppBar | Màu accent của notebook + icon + tên + back button |
| **Summary section** | Nền accent nhạt · icon `auto_awesome` · "Tóm tắt AI" + text (AI-generated) |
| **Suggestion chips** | Tối đa 4 chip câu hỏi gợi ý → tap → điều hướng Chat và gửi ngay câu hỏi |
| **Danh sách tài liệu** | Header "Tài liệu" + nút "Thêm" → `/notebook/:id/upload` |
| Loading | 3 DocumentCardSkeleton |
| Rỗng | Illustration + "Tải tài liệu lên" |
| Document tile | Icon PDF/TXT + tên + số trang + trailing icon |
| **Selection mode** | Long press → AppBar đổi + checkbox |
| **Bottom action bar** | 3 nút: `Chat AI` (filled) · `Flashcard` (outlined) · `Luyện thi` (outlined) |
| Polling | Auto poll mỗi 5s khi summary chưa có, dừng khi có |

---

## 8. Upload — `/upload` & `/notebook/:id/upload`

**File:** `lib/features/upload/upload_screen.dart`

### State: Idle
| Thành phần | Mô tả |
|-----------|-------|
| Drop zone | Vùng tap lớn với border dashed (primary 35%) + icon upload + "Nhấp hoặc kéo thả file" |
| Nút | "Chọn tệp tin" → `FilePicker` (PDF/TXT, tối đa 20MB) |
| Format chips | Row 2 chip: PDF (đỏ) · TXT (tím) |
| Notebook selector | Dropdown chọn notebook (optional) + màu chấm tròn |
| Tip box | Info "AI sẽ đọc và lập chỉ mục..." |

### State: Uploading
| Thành phần | Mô tả |
|-----------|-------|
| Header | AI pulse icon (scale animation) + tên file + % |
| Progress bar | `LinearProgressIndicator` (value từ 0→1) |
| Step badges | 4 badge: Tải lên / Trích xuất / Nhúng AI / Hoàn tất (active khi qua threshold) |
| Nút Hủy | OutlinedButton → `cancelUpload()` |
| Chuyển state | `AnimatedSwitcher` Idle ↔ Uploading (fade 350ms) |

---

## 9. Chat AI — `/chat`

**File:** `lib/features/chat/chat_screen.dart`

| Thành phần | Mô tả |
|-----------|-------|
| AppBar | Icon AI + "SmartDoc AI" + subtitle (tên notebook/doc đang chat) + nút 🕓 lịch sử |
| Bubble list | `ListView.builder` — `UserChatBubble` (phải) · `AIChatBubble` (trái, có citations) |
| Typing indicator | `TypingIndicator` khi AI đang xử lý |
| Loading history | 3 `ChatBubbleSkeleton` khi tải lịch sử |

### Input area
| Element | Mô tả |
|---------|-------|
| Context chip | Hiện khi đã chọn doc/notebook: icon + tên + nút ✕ bỏ chọn · Tap → đổi ngữ cảnh |
| `+` button | Mở BottomSheet chọn nguồn hỏi đáp (đổi sang icon swap khi đã chọn) |
| Text field | Multiline (1-5 dòng) · Enter = gửi · hint thay đổi theo context |
| Voice button | `_VoiceButton` — tap để bật/tắt nhận giọng nói tiếng Việt · nền đỏ nhấp nháy khi đang nghe · pause 3s → tự gửi |
| Send button | Circle, ẩn xám khi không có text, sáng primary khi có text |

### Context Picker (BottomSheet)
- Section "Notebooks": list notebook có màu accent + summary
- Section "Tài liệu": list document có icon loại + số trang
- Nút "Bỏ chọn" nếu đã chọn nguồn
- Highlight item đang active

### Conversations Drawer (end drawer)
- AppBar "Hội thoại" + nút đóng
- List các cuộc hội thoại trước (docId + tiêu đề + tin nhắn cuối + thời gian)
- Empty state với CTA "Tải tài liệu lên"

---

## 10. Hồ sơ — `/profile`

**File:** `lib/features/profile/profile_screen.dart`

| Thành phần | Mô tả |
|-----------|-------|
| Avatar | `CircleAvatar` 96px · Tap → bottom sheet (chọn ảnh / xoá ảnh) · Upload lên Firebase Storage |
| Tên | `displayName` + icon edit · Tap → dialog đổi tên |
| Email | Hiển thị email Firebase |
| Stat card | Card "N Notebooks" |
| Menu card | Đổi tên · Đổi mật khẩu (chỉ email account) · Trợ giúp |
| Đăng xuất | OutlinedButton → confirm dialog → logout + clear state + về `/login` |

---

## 11. Quiz — Luyện thi — `/quiz/:notebookId`

**File:** `lib/features/quiz/screens/quiz_screen.dart`

**State machine:**
```
[setup] → [loading] → [questioning] → [result]
              ↓                           ↓
           [error]              [làm lại / bộ mới / lịch sử]
```

### View: Setup
| Thành phần | Mô tả |
|-----------|-------|
| Header | Icon quiz + "Cài đặt bài luyện thi" |
| Số câu | 4 chip: **5 / 10 / 15 / 20** (animated highlight) |
| Độ khó | 3 card radio: **Dễ** (xanh) · **Trung bình** (cam) · **Khó** (đỏ) + mô tả Bloom |
| Nút | "Bắt đầu luyện thi" (FilledButton) |

### View: Loading
- Spinner 52px + "AI đang phân tích tài liệu..." + "Tạo N câu · Mức X" + "Thường mất 5-15 giây"

### View: Question
| Thành phần | Mô tả |
|-----------|-------|
| Progress bar | `TweenAnimationBuilder` — animate từ index/N → (index+1)/N |
| Mock banner | Banner cam "Câu hỏi mẫu" nếu `is_mock: true` |
| Question card | Nền primary container + "Câu X/N" + nội dung câu |
| Options A-D | 4 option · Tap → lock chọn · Color coding: ✓ xanh / ✗ đỏ / còn lại giữ nguyên |
| Explanation | AnimatedSize: xuất hiện sau khi chọn đáp án |
| Nút Next | AnimatedSlide (trượt lên từ dưới khi đã chọn) · "Câu tiếp theo" / "Xem kết quả" (câu cuối) |
| Exit confirm | Dialog khi back/close giữa chừng |

### View: Result
| Thành phần | Mô tả |
|-----------|-------|
| Score circle | Vòng tròn 128px · màu theo điểm (xanh ≥80% / cam ≥60% / đỏ <60%) · `X/N · Y%` |
| Score label | "Xuất sắc 🎉" / "Khá tốt 💪" / "Cần ôn thêm 📚" |
| Detail list | Mỗi câu: icon ✓/✗ + nội dung rút gọn + "Bạn chọn: X · Đúng: Y" nếu sai |
| Saving status | Spinner "Đang lưu kết quả..." → ✓ "Đã lưu vào lịch sử" |
| Actions | Làm lại bộ này · Tạo bộ câu hỏi mới · Xem chi tiết bài làm · Xem lịch sử |

---

## 12. Lịch sử Quiz — `/quiz/history/:notebookId`

**File:** `lib/features/quiz/screens/quiz_history_screen.dart`

| Thành phần | Mô tả |
|-----------|-------|
| AppBar | "Lịch sử luyện thi" + subtitle tên notebook + nút refresh |
| **Loading** | 5 SessionCardSkeleton |
| **Rỗng** | Icon + "Chưa có lần luyện thi nào" |
| **Có dữ liệu** | ListView các session card |
| Session card | Score circle (màu theo điểm) + tên notebook + badge mức khó (màu) + "Đúng X/N · label" + ngày giờ + mũi tên |
| Badge "Mẫu" | Hiện nếu `is_mock: true` |
| Tap | → `/quiz/review/:sessionId` |

---

## 13. Xem lại bài làm — `/quiz/review/:sessionId`

**File:** `lib/features/quiz/screens/quiz_review_screen.dart`

| Thành phần | Mô tả |
|-----------|-------|
| SliverAppBar | "Xem lại bài làm" (pinned) + summary card (score circle + tên + badge mức khó + ngày) |
| TabBar | **"Tất cả N câu"** · **"Câu sai M câu"** (badge đỏ số lượng) |
| Question card | Header (✓ xanh / ✗ đỏ / — bỏ qua) + nội dung câu + 4 options color coded + explanation |
| Empty wrong tab | "🎉 Không có câu sai! Bạn đã trả lời đúng tất cả." |
| Answer badge | "Bạn chọn: X" / "Bỏ qua" |

---

## 14. Flashcard Setup — `/flashcards/:notebookId`

**File:** `lib/features/flashcards/screens/flashcard_setup_screen.dart`

| Thành phần | Mô tả |
|-----------|-------|
| Header | Icon `Icons.style_rounded` + "Học Flashcards" |
| Số thẻ | 3 chip: **10 / 20 / 50** |
| Mẹo học | 3 tip items: lật thẻ · ôn lại · vuốt |
| **Loading** | Spinner + "AI đang tạo flashcards..." |
| Nút | "Bắt đầu học" → generate deck → navigate `FlashCardStudyScreen` |
| Chuyển state | `AnimatedSwitcher` Setup ↔ Loading (fade 280ms) |

---

## 15. Tóm tắt số màn hình

| Nhóm | Màn hình | Tổng |
|------|---------|------|
| Onboarding / Auth | Splash, Login, Register, ForgotPassword | **4** |
| Shell (BottomNav) | Home, Notebooks, Upload, Chat, Profile | **5** |
| Notebook | NotebookDetail, Upload từ notebook | **2** |
| Quiz | QuizScreen, QuizHistory, QuizReview | **3** |
| Flashcard | FlashCardSetup, FlashCardStudy, FlashCardResult, FlashCardHistory | **4** |
| **Tổng cộng** | | **18** |

---

## 16. Shared Widgets tái sử dụng

| Widget | Mô tả |
|--------|-------|
| `AppCard` | Card với shadow + border |
| `CustomButton` | Button với variant (filled/outline) + loading state |
| `CustomTextField` | Text field với prefix icon + password toggle |
| `GlassCard` | Card hiệu ứng kính |
| `LoadingWidget` | Spinner chuẩn |
| `EmptyState` | Empty state có type enum |
| `CitationChip` | Chip hiển thị nguồn trích dẫn |
| `AIChatBubble` | Bubble AI với markdown + citations |
| `UserChatBubble` | Bubble user |
| `TypingIndicator` | Ba chấm nhảy |
| `DocumentCardSkeleton` | Skeleton card loading |
| `ChatBubbleSkeleton` | Skeleton bubble loading |
| `MainScaffold` | Shell với BottomNavigationBar 5 tab |

---

## 17. Animation & Motion System

| Constant | Giá trị | Dùng cho |
|----------|---------|---------|
| `AppMotion.fast` | 150ms | Hover, toggle |
| `AppMotion.normal` | 300ms | Transition thông thường |
| `AppMotion.slow` | 500ms | Splash, entrance lớn |
| `AppMotion.page` | 250ms | Page transition GoRouter |
| `AppMotion.curve` | `easeOutCubic` | Tất cả animation |
| `AppMotion.stagger(i)` | `i * 50ms` | Grid/list item entrance delay |
| `.appEntrance(delay)` | Extension Widget | fadeIn + slideY |
| `.appScaleIn(delay)` | Extension Widget | scale từ 0.8 → 1.0 |
