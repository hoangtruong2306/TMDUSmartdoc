# TMDUSmartdoc — Tổng hợp luồng API

> Cập nhật: 2026-05-22  
> Backend: FastAPI · Supabase · Gemini 2.5 Flash · Firebase Auth

---

## Tổng quan

```
Base URL: https://<railway-domain>

Prefix          Router file
──────────────  ─────────────────────────────
/documents      backend/app/routers/documents.py
/notebooks      backend/app/routers/notebooks.py
/chat           backend/app/routers/chat.py
/quiz           backend/app/routers/quiz.py
/ping, /health  backend/main.py
```

Mọi endpoint (trừ `/ping`, `/health`) đều yêu cầu header:
```
Authorization: Bearer <Firebase ID Token>
```
Backend xác thực qua `app/auth.py` → lấy `uid` từ Firebase.

---

## 1. Documents — `/documents`

### `POST /documents/upload`

**Mục đích:** Upload file PDF/TXT, extract text, embed vector, lưu DB.

**Request:** `multipart/form-data`
| Field | Kiểu | Bắt buộc | Mô tả |
|-------|------|----------|-------|
| `file` | UploadFile | Có | File PDF hoặc TXT, tối đa 20 MB |
| `notebook_id` | string (Form) | Không | UUID notebook muốn gán vào |

**Luồng xử lý:**
```
1. Validate ext (pdf/txt) + kích thước (≤ 20MB)
2. Validate notebook_id (UUID format + ownership check) nếu có
3. extract_chunks(file_bytes) → List[Chunk], page_count
4. Nếu chunks rỗng → 422
5. INSERT documents (status='processing')
6. Trả response ngay lập tức (non-blocking)
7. [Background Task] _embed_and_store():
   a. embed_texts(chunks) → vector[768]
   b. Batch INSERT chunks (100 rows/batch)
   c. UPDATE documents SET status='ready'
   d. Nếu có notebook_id → generate_notebook_insights()
   e. Nếu lỗi bất kỳ bước trên → UPDATE status='failed'
```

**Response 200:**
```json
{
  "document_id": "uuid",
  "title": "file.pdf",
  "page_count": 42,
  "chunks_count": 87,
  "notebook_id": "uuid | null",
  "status": "processing"
}
```

**Errors:** `400` ext không hợp lệ · `403` notebook không thuộc user · `413` file > 20MB · `422` file rỗng/không đọc được

---

### `GET /documents`

**Mục đích:** Danh sách tài liệu của user, mới nhất trước.

**Response:** `Array<Document>` — các trường: `id, title, page_count, type, created_at, status, notebook_id`

---

## 2. Notebooks — `/notebooks`

### `GET /notebooks`

**Mục đích:** Danh sách notebooks của user, sắp xếp theo `updated_at DESC`.

**Response:** `Array<Notebook>` — các trường: `id, name, color, icon, summary, suggestions, created_at, updated_at`

---

### `POST /notebooks`

**Mục đích:** Tạo notebook mới.

**Request body:**
```json
{
  "name": "Kinh tế vi mô",
  "color": "#6750A4",
  "icon": "school"
}
```

**Luồng:**
```
1. Validate name không rỗng
2. gen UUID
3. INSERT notebooks
4. Trả notebook object
```

**Errors:** `400` tên rỗng · `500` DB lỗi

---

### `PATCH /notebooks/{notebook_id}`

**Mục đích:** Cập nhật tên/màu/icon.

**Request body (ít nhất 1 field):**
```json
{
  "name": "Tên mới",
  "color": "#FF5722",
  "icon": "book"
}
```

**Luồng:**
```
1. Validate UUID format
2. Validate ít nhất 1 field thay đổi
3. Ownership check (404 nếu không tìm thấy)
4. UPDATE notebooks SET updated_at=<ISO now>, ...fields
5. Trả notebook object đã cập nhật
```

**Errors:** `400` UUID lỗi / không có field · `404` không tìm thấy

---

### `DELETE /notebooks/{notebook_id}`

**Mục đích:** Xoá notebook (documents/chunks cascade theo FK).

**Luồng:**
```
1. Validate UUID format
2. Ownership check (404 nếu không tìm thấy)
3. DELETE notebooks WHERE id=? AND user_id=?
   └─ CASCADE: documents → chunks, quiz_sessions (SET NULL)
4. Trả {"deleted": "uuid"}
```

---

## 3. Chat — `/chat`

### `POST /chat/ask`

**Mục đích:** Hỏi đáp RAG, trả lời dạng JSON đầy đủ (không stream).

**Request body:**
```json
{
  "message": "Chi phí cơ hội là gì?",
  "doc_id": null,
  "notebook_id": "uuid",
  "history": [
    {"role": "user", "content": "..."},
    {"role": "model", "content": "..."}
  ]
}
```

**Luồng:**
```
1. Validate message không rỗng
2. [Cache] Nếu history rỗng → kiểm tra in-memory cache (uid+question+source_key)
3. embed_query(question) → vector[768]
   └─ Lỗi → trả MOCK_QA (không crash)
4. pgvector RPC (TOP_K=5):
   - notebook_id có → match_chunks_by_notebook
   - doc_id có     → match_chunks_by_doc
   - còn lại       → match_chunks (toàn user)
   └─ Lỗi → trả MOCK_QA
5. chunks rỗng → trả thông báo "không tìm thấy tài liệu"
6. Build context (≤4000 ký tự) + citations
7. _call_gemini() với system_prompt + history (tối đa 8 tin cuối):
   a. Chat session (giữ history) — timeout 15s
   b. Fallback: generate_content (không history) — timeout 15s
   c. Fallback: trả None → trả MOCK_QA
8. [Cache] Nếu history rỗng → lưu kết quả vào cache
9. Trả {answer, citations}
```

**Response 200:**
```json
{
  "answer": "Chi phí cơ hội là... [1]",
  "citations": [
    {
      "label": "Nguồn 1",
      "value": "12",
      "snippet": "Chi phí cơ hội xuất hiện khi...",
      "filename": "giao_trinh_ktvm.pdf"
    }
  ]
}
```

---

### `POST /chat/stream`

**Mục đích:** Hỏi đáp RAG dạng SSE streaming (token by token).

**Request body:** Giống `/chat/ask`

**Luồng SSE:**
```
1. Gửi headers ngay lập tức (tránh Flutter timeout)
2. yield {type:'processing'}          ← typing indicator
3. embed_query → lỗi: yield error + done
4. yield {type:'ping'}               ← keep-alive
5. pgvector RPC → lấy chunks
6. yield {type:'citations', citations:[...]}
7. Gemini stream (chat_session.send_message_stream):
   └─ mỗi token: yield {type:'token', text:'...'}
8. yield {type:'done', full_text:'...'}
```

**Event types:**
| type | Payload | Mô tả |
|------|---------|-------|
| `processing` | — | Server đã nhận, đang xử lý |
| `ping` | — | Keep-alive giữa các bước |
| `citations` | `citations: []` | Nguồn tài liệu |
| `token` | `text: string` | Một đoạn text Gemini stream |
| `done` | `full_text: string` | Kết thúc, toàn bộ câu trả lời |
| `error` | `message: string` | Lỗi |

---

## 4. Quiz — `/quiz`

### `POST /quiz/generate`

**Mục đích:** Sinh câu hỏi trắc nghiệm từ nội dung notebook bằng Gemini.

**Request body:**
```json
{
  "notebook_id": "uuid",
  "num_questions": 5,
  "difficulty": "medium"
}
```

**Difficulty map (Bloom's Taxonomy):**
| Giá trị | Mức độ |
|---------|--------|
| `easy` | Nhớ & hiểu (Level 1-2) |
| `medium` | Vận dụng & phân tích (Level 3-4) |
| `hard` | Đánh giá & tổng hợp (Level 5-6) |

**Luồng:**
```
1. Validate num_questions (1–20)
2. Ownership check notebook (404 nếu không thuộc user)
3. Lấy chunks: SELECT content, page_num WHERE notebook_id=? AND user_id=?
               ORDER BY page_num LIMIT 15 → join[:5000 chars]
   └─ chunks rỗng → trả MOCK_QUIZ (is_mock: true)
4. _generate_with_gemini(context, num_questions, difficulty):
   a. Build prompt yêu cầu JSON thuần (không markdown)
   b. Gọi gemini-2.5-flash
   c. Strip code fence ```json...```
   d. json.loads()
   e. Validate: questions list, 4 options/câu, correct ∈ {A,B,C,D}
   └─ JSON lỗi / Gemini lỗi → trả MOCK_QUIZ (is_mock: true)
5. Trả result + {notebook_name, is_mock: false}
```

**Response 200:**
```json
{
  "questions": [
    {
      "question": "Nội dung câu hỏi?",
      "options": ["A. ...", "B. ...", "C. ...", "D. ..."],
      "correct": "B",
      "explanation": "Giải thích..."
    }
  ],
  "notebook_name": "Kinh tế vi mô",
  "is_mock": false
}
```

> `is_mock: true` → Flutter hiện banner cảnh báo "câu hỏi mẫu".

---

### `POST /quiz/save`

**Mục đích:** Lưu kết quả sau khi user hoàn thành bài quiz.

**Request body:**
```json
{
  "notebook_id": "uuid | null",
  "notebook_name": "Kinh tế vi mô",
  "difficulty": "medium",
  "is_mock": false,
  "questions": [{"question":"...", "options":[...], "correct":"A", "explanation":"..."}],
  "answers": [{"question_index": 0, "user_answer": "A"}]
}
```

**Luồng:**
```
1. Tính điểm phía server (tránh giả mạo):
   correct_map = {index: correct_letter}
   correct_count = count(user_answer == correct_map[index])
   score_pct = round(correct_count / total * 100)
2. INSERT quiz_sessions (1 row)
3. Bulk INSERT quiz_questions (tất cả câu hỏi + đáp án user)
   └─ Lỗi bước 3 → log nhưng không raise (session đã lưu)
4. Trả {session_id, score_pct, correct_count}
```

**Response 200:**
```json
{
  "session_id": "uuid",
  "score_pct": 80,
  "correct_count": 4
}
```

---

### `GET /quiz/history`

**Mục đích:** Lịch sử các lần làm quiz, mới nhất trước.

**Query params:**
| Param | Kiểu | Mô tả |
|-------|------|-------|
| `notebook_id` | string (optional) | Lọc theo notebook |
| `limit` | int (default 20, max 50) | Số session trả về |

**Response:** `Array<QuizSession>` — `id, notebook_id, notebook_name, difficulty, total_questions, correct_count, score_pct, is_mock, created_at`

---

### `GET /quiz/session/{session_id}`

**Mục đích:** Chi tiết 1 session quiz (dùng cho màn hình xem lại câu sai).

**Luồng:**
```
1. SELECT quiz_sessions WHERE id=? AND user_id=? (ownership check)
   └─ Không thấy → 404
2. SELECT quiz_questions WHERE session_id=? ORDER BY question_index
3. Trả {...session, questions: [...]}
```

**Response 200:**
```json
{
  "id": "uuid",
  "notebook_name": "Kinh tế vi mô",
  "score_pct": 80,
  "questions": [
    {
      "question_index": 0,
      "question": "...",
      "options": ["A. ...", "B. ...", "C. ...", "D. ..."],
      "correct": "A",
      "explanation": "...",
      "user_answer": "B",
      "is_correct": false
    }
  ]
}
```

---

## 5. Utility — `main.py`

### `GET|HEAD /ping`

```json
{"status": "ok", "service": "TDMU SmartDoc API"}
```

### `GET /health`

Kiểm tra kết nối 3 dịch vụ:

```json
{
  "gemini": "ok (dims=768)",
  "supabase": "ok",
  "firebase": "ok",
  "env": {
    "GEMINI_API_KEY": "set",
    "SUPABASE_URL": "set",
    "SUPABASE_SERVICE_KEY": "set",
    "FIREBASE_SERVICE_ACCOUNT_JSON": "set"
  }
}
```

---

## 6. Bảng tổng hợp nhanh

| Method | Path | Auth | Bảng ghi | Mô tả |
|--------|------|------|----------|-------|
| POST | `/documents/upload` | Có | documents, chunks | Upload & embed file |
| GET | `/documents` | Có | — | Danh sách documents |
| GET | `/notebooks` | Có | — | Danh sách notebooks |
| POST | `/notebooks` | Có | notebooks | Tạo notebook |
| PATCH | `/notebooks/{id}` | Có | notebooks | Sửa notebook |
| DELETE | `/notebooks/{id}` | Có | notebooks | Xoá notebook |
| POST | `/chat/ask` | Có | — | Q&A RAG (JSON) |
| POST | `/chat/stream` | Có | — | Q&A RAG (SSE stream) |
| POST | `/quiz/generate` | Có | — | Sinh câu hỏi quiz |
| POST | `/quiz/save` | Có | quiz_sessions, quiz_questions | Lưu kết quả |
| GET | `/quiz/history` | Có | — | Lịch sử quiz |
| GET | `/quiz/session/{id}` | Có | — | Chi tiết session |
| GET\|HEAD | `/ping` | Không | — | Health check nhanh |
| GET | `/health` | Không | — | Kiểm tra chi tiết |

---

## 7. Fallback Strategy (chống crash)

| Tình huống | Hành vi |
|-----------|---------|
| Gemini timeout (>15s) | Thử lại không history → nếu vẫn lỗi → trả MOCK_QA |
| Embed lỗi (chat) | Trả MOCK_QA ngay |
| pgvector RPC lỗi | Trả MOCK_QA |
| Chunks rỗng (quiz) | Trả MOCK_QUIZ, `is_mock: true` |
| Gemini JSON lỗi (quiz) | Trả MOCK_QUIZ, `is_mock: true` |
| Embed lỗi (upload bg) | UPDATE documents SET status='failed' |
| quiz_questions insert lỗi | Log, không raise (quiz_sessions đã lưu) |
