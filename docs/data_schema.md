# TMDUSmartdoc — Tổng hợp Data Schema

> Cập nhật: 2026-05-22

---

## 1. Tổng quan quan hệ bảng

```
notebooks
  ├── documents  (FK: notebook_id → notebooks.id, SET NULL on delete)
  │     └── chunks  (FK: document_id → documents.id, CASCADE delete)
  │           └── FK: notebook_id → notebooks.id (denormalized for fast search)
  └── quiz_sessions  (FK: notebook_id → notebooks.id, SET NULL on delete)
        └── quiz_questions  (FK: session_id → quiz_sessions.id, CASCADE delete)
```

---

## 2. Bảng Database (Supabase PostgreSQL)

Nguồn: `backend/supabase_setup.sql`, `backend/migrations/quiz_history.sql`

---

### 2.1 `notebooks`

| Cột | Kiểu | Ràng buộc | Mô tả |
|-----|------|-----------|-------|
| `id` | UUID | PK, default: gen_random_uuid() | |
| `user_id` | text | NOT NULL | Firebase UID hoặc Supabase user id |
| `name` | text | NOT NULL | Tên notebook |
| `color` | text | default: `'#6750A4'` | Màu hiển thị (hex) |
| `icon` | text | default: `'school'` | Tên icon Material |
| `summary` | text | default: `''` | Tóm tắt nội dung notebook (AI-generated) |
| `suggestions` | JSONB | default: `'[]'` | Danh sách gợi ý câu hỏi (AI-generated) |
| `created_at` | timestamptz | default: NOW() | |
| `updated_at` | timestamptz | default: NOW() | Tự cập nhật qua trigger |

---

### 2.2 `documents`

| Cột | Kiểu | Ràng buộc | Mô tả |
|-----|------|-----------|-------|
| `id` | UUID | PK, default: gen_random_uuid() | |
| `user_id` | text | NOT NULL | |
| `title` | text | NOT NULL | Tên file tài liệu |
| `page_count` | int | | Số trang (PDF) |
| `type` | text | default: `'pdf'` | Loại file: `'pdf'`, `'txt'`, ... |
| `status` | text | default: `'processing'` | `'processing'` → `'ready'` hoặc `'failed'` |
| `notebook_id` | UUID | FK → notebooks(id), SET NULL | |
| `created_at` | timestamptz | default: NOW() | |

**Index:** `documents_notebook_idx` trên `notebook_id`

---

### 2.3 `chunks`

| Cột | Kiểu | Ràng buộc | Mô tả |
|-----|------|-----------|-------|
| `id` | UUID | PK, default: gen_random_uuid() | |
| `document_id` | UUID | FK → documents(id), CASCADE delete | |
| `user_id` | text | NOT NULL | |
| `content` | text | NOT NULL | Nội dung đoạn văn bản |
| `page_num` | int | default: 0 | Số trang trong tài liệu gốc |
| `embedding` | vector(768) | | Vector embedding (Gemini model) |
| `notebook_id` | UUID | FK → notebooks(id), SET NULL | Denormalized để search nhanh |
| `created_at` | timestamptz | default: NOW() | |

**Index:**
- `chunks_embedding_idx`: HNSW trên `embedding` (cosine similarity)
- `chunks_notebook_idx` trên `notebook_id`

**RPC Functions (vector search):**

| Tên hàm | Tham số | Mô tả |
|---------|---------|-------|
| `match_chunks` | `query_embedding`, `match_count`, `user_id_filter` | Tìm kiếm toàn bộ chunks của user |
| `match_chunks_by_doc` | + `doc_id_filter` | Giới hạn theo 1 document |
| `match_chunks_by_notebook` | + `notebook_id_filter` | Giới hạn theo 1 notebook |

---

### 2.4 `quiz_sessions`

| Cột | Kiểu | Ràng buộc | Mô tả |
|-----|------|-----------|-------|
| `id` | UUID | PK, default: gen_random_uuid() | |
| `user_id` | text | NOT NULL | |
| `notebook_id` | UUID | FK → notebooks(id), SET NULL | |
| `notebook_name` | text | NOT NULL | Snapshot tên notebook lúc làm bài |
| `difficulty` | text | CHECK: `'easy'\|'medium'\|'hard'` | Mức độ |
| `total_questions` | int | NOT NULL | Tổng số câu |
| `correct_count` | int | NOT NULL | Số câu đúng |
| `score_pct` | int | CHECK: 0–100 | Điểm phần trăm |
| `is_mock` | boolean | default: FALSE | TRUE = chế độ thi thử |
| `created_at` | timestamptz | default: NOW() | |

**Index:**
- `idx_quiz_sessions_user_id` trên `(user_id, created_at DESC)`
- `idx_quiz_sessions_notebook` trên `(notebook_id, user_id)`

---

### 2.5 `quiz_questions`

| Cột | Kiểu | Ràng buộc | Mô tả |
|-----|------|-----------|-------|
| `id` | UUID | PK, default: gen_random_uuid() | |
| `session_id` | UUID | FK → quiz_sessions(id), CASCADE delete | |
| `question_index` | int | NOT NULL | Thứ tự câu trong session (0-based) |
| `question` | text | NOT NULL | Nội dung câu hỏi |
| `options` | JSONB | NOT NULL | `["A. ...", "B. ...", "C. ...", "D. ..."]` |
| `correct` | text | NOT NULL | Đáp án đúng: `"A"\|"B"\|"C"\|"D"` |
| `explanation` | text | | Giải thích đáp án |
| `user_answer` | text | nullable | Đáp án người dùng chọn (null = bỏ qua) |
| `is_correct` | boolean | NOT NULL | Kết quả đúng/sai |
| `created_at` | timestamptz | default: NOW() | |

**Index:** `idx_quiz_questions_session` trên `(session_id, question_index)`

---

## 3. Dart Models (Client-side)

### 3.1 Quiz Models — `lib/features/quiz/models/quiz_model.dart`

| Class | Trường | Mô tả |
|-------|--------|-------|
| `QuizQuestion` | `question`, `options` (List\<String>), `correct`, `explanation` | Câu hỏi từ AI |
| `QuizResult` | `questions`, `notebookName`, `isMock` | Response từ `POST /quiz/generate` |
| `QuizSession` | `id`, `notebookId?`, `notebookName`, `difficulty`, `totalQuestions`, `correctCount`, `scorePct`, `isMock`, `createdAt` | Tóm tắt một lần làm bài |
| `QuizQuestionRecord` | `id`, `questionIndex`, `question`, `options`, `correct`, `explanation`, `userAnswer?`, `isCorrect` | Chi tiết từng câu có kèm đáp án user |
| `QuizSessionDetail` | extends `QuizSession` + `questionRecords` | Chi tiết session (dùng cho màn hình xem lại) |

**Computed fields của `QuizSession`:** `scoreColor`, `scoreLabel`

**Computed fields của `QuizSessionDetail`:** `wrongQuestions` (lọc câu sai)

---

### 3.2 Flashcard Models — `lib/features/flashcards/models/flashcard_model.dart`

| Class | Trường | Mô tả |
|-------|--------|-------|
| `FlashCard` | `id`, `front`, `back`, `hint?`, `category?` | Một thẻ flashcard |
| `FlashCardDeck` | `id`, `notebookId`, `notebookName`, `title`, `cards`, `isMock`, `createdAt` | Bộ thẻ từ AI |
| `CardResult` (enum) | `mastered`, `review`, `skipped` | Kết quả học từng thẻ |
| `FlashCardResult` | `cards`, `answers` (Map\<int, CardResult?>) | Kết quả sau khi học xong deck |
| `FlashCardSession` | `id`, `notebookId?`, `notebookName`, `deckTitle`, `totalCards`, `masteredCount`, `reviewCount`, `skippedCount`, `scorePct`, `isMock`, `createdAt` | Lịch sử phiên học flashcard |

**Computed fields của `FlashCardResult`:** `masteredCount`, `reviewCount`, `skippedCount`, `completedCount`, `scorePct`

**Computed fields của `FlashCardSession`:** `scoreColor`, `scoreLabel`

> **Lưu ý:** FlashCard hiện chưa có bảng DB riêng — dữ liệu được generate on-demand và lưu tạm trong `FlashCardSession`.

---

## 4. Python Pydantic Models (Backend)

### 4.1 Notebook — `backend/app/routers/notebooks.py`

| Class | Trường |
|-------|--------|
| `NotebookCreate` | `name` (str), `color?` (str), `icon?` (str) |
| `NotebookUpdate` | `name?`, `color?`, `icon?` — tất cả Optional |

### 4.2 Chat — `backend/app/routers/chat.py`

| Class | Trường |
|-------|--------|
| `HistoryMessage` | `role` (`"user"\|"model"`), `content` (str) |
| `AskRequest` | `message`, `doc_id?`, `notebook_id?`, `history` (List\<HistoryMessage>) |

### 4.3 Quiz — `backend/app/routers/quiz.py`

| Class | Trường |
|-------|--------|
| `QuizRequest` | `notebook_id`, `num_questions` (1–20, default 5), `difficulty?` |
| `QuizAnswerItem` | `question_index` (int), `user_answer?` (None = bỏ qua) |
| `QuizSaveRequest` | `notebook_id?`, `notebook_name`, `difficulty`, `is_mock`, `questions` (List\<dict>), `answers` (List\<QuizAnswerItem>) |

---

## 5. Mapping API ↔ Bảng DB

| Endpoint | Method | Bảng đọc/ghi |
|----------|--------|--------------|
| `/documents/upload` | POST | `documents` (write), `chunks` (write) |
| `/documents/{id}` | DELETE | `documents`, `chunks` (cascade) |
| `/notebooks` | GET | `notebooks` |
| `/notebooks` | POST | `notebooks` |
| `/notebooks/{id}` | PATCH | `notebooks` |
| `/notebooks/{id}` | DELETE | `notebooks`, `documents`, `chunks` (cascade) |
| `/chat/ask` | POST | `chunks` (via RPC match_chunks*) |
| `/quiz/generate` | POST | `chunks` (read), `notebooks` (read) |
| `/quiz/save` | POST | `quiz_sessions` (write), `quiz_questions` (write) |
| `/quiz/history` | GET | `quiz_sessions` (read) |
| `/quiz/session/{id}` | GET | `quiz_sessions`, `quiz_questions` (read) |
| `/flashcards/generate` | POST | `chunks` (read), `notebooks` (read) |

---

## 6. Tóm tắt

| | Tổng |
|--|------|
| Bảng DB | **5** (`notebooks`, `documents`, `chunks`, `quiz_sessions`, `quiz_questions`) |
| Dart model classes | **9** |
| Python Pydantic models | **7** |
| RPC functions (vector search) | **3** |
| JSONB fields | **2** (`notebooks.suggestions`, `quiz_questions.options`) |
| Vector dimension | **768** (Gemini embedding) |
