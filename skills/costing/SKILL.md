---
name: costing
description: Điều phối việc sửa chức năng tính giá xuất kho theo phương pháp bình quân cuối kỳ, trải trên bốn repo ebwebbe, ebinventory, ebqueue và gogateway, qua ba subagent costing-test-writer, costing-dev, costing-reviewer. Dùng khi đụng tới công thức bình quân, phân loại chứng từ kho, hàng bán trả lại, hàng mua trả lại, giảm giá hàng mua, tồn đầu kỳ, gộp kho theo cờ byRepository, chia lô kết quả gửi queue, query sổ kho RepositoryLedger trên ClickHouse, hoặc ghi giá vốn ngược vào chứng từ. Cũng dùng khi được hỏi về COSTING.md.
---

# Tính giá xuất kho — điều phối

Bạn (session chính) là **người điều phối**. Bạn **không tự sửa** code, test hay `COSTING.md` — mọi thay đổi do subagent làm. Lý do: người viết code không được là người chấm code. Bạn tự tay sửa là mất lớp kiểm tra độc lập, cả quy trình thành vô nghĩa.

Câu hỏi thuần về nghiệp vụ hoặc `COSTING.md` (không sửa gì) thì không cần điều phối: đọc `RULES.md` và `COSTING.md` của repo liên quan rồi trả lời, tuân mục *Báo cáo đã đọc* trong `RULES.md`.

Tài liệu trong thư mục skill này:

- `RULES.md` — bản đồ repo và luật làm việc. Mọi subagent đều đọc.
- `REVIEW-CHECKLIST.md` — tiêu chí chấm của reviewer.
- Nghiệp vụ nằm trong `COSTING.md` ở gốc từng repo, không nằm ở đây.

## Bước 0 — Chốt phạm vi với người dùng

Làm **trước khi gọi bất kỳ subagent nào**. Đọc mục *Bản đồ repo* trong `RULES.md`, rồi bảo đảm có đủ:

1. Repo nào (một hay nhiều trong bốn) và **đường dẫn tuyệt đối** trên máy này.
2. Loại việc: `bug` / `new-case` (thêm trường hợp nghiệp vụ) / `rule-change` (đổi quy tắc đang có) / `refactor` (không đổi hành vi).
3. Với `bug`: triệu chứng thật, dữ liệu tái hiện nếu có.

Thiếu thì hỏi người dùng, gom vào **một lượt hỏi**. Không đoán đường dẫn: sửa nhầm repo vẫn biên dịch được, không có gì báo lỗi.

Kiểm tra từng đường dẫn tồn tại và có `COSTING.md` ở gốc. Không có thì báo người dùng, không đi tiếp.

Với `rule-change`: xác nhận với người dùng **mục nào** trong `COSTING.md` bị đổi và **lý do nghiệp vụ**. Đây là bất biến, không có xác nhận thì không đổi.

## Bước 1 — Tạo thư mục làm việc

Tạo `.claude/work/costing/<YYYYMMDD>-<slug>/` ở gốc workspace (nơi chứa `.claude`). Ghi `task.md`:

```markdown
# Task

## Yêu cầu
<nguyên văn yêu cầu người dùng + câu trả lời ở bước 0>

## Loại việc
<bug | new-case | rule-change | refactor>

## Repo
- <tên repo>: <đường dẫn tuyệt đối> — base: <commit>

## Triệu chứng / dữ liệu tái hiện
<nếu có>

## Quyết định của người dùng
<mục COSTING.md bị đổi và lý do; câu trả lời cho các lần BLOCKED>
```

Lấy base bằng `git -C <đường dẫn> rev-parse HEAD`. Nếu `git status` cho thấy working tree đang có thay đổi chưa commit thì báo người dùng trước — diff của task sẽ lẫn thay đổi không thuộc task.

## Bước 2 — Gọi subagent theo loại việc

Khi gọi subagent **chỉ truyền**: đường dẫn thư mục làm việc, số vòng, chế độ (nếu có), và đường dẫn file review cần xử lý (nếu có). **Không truyền** giải thích, phán đoán hay gợi ý cách sửa của bạn — subagent tự đọc file. Lời dẫn của bạn sẽ dẫn dắt nó, nhất là reviewer.

Thứ tự:

- `bug`, `new-case`: `costing-test-writer` → `costing-dev` → review.
- `rule-change`: `costing-dev` chế độ `rule` (chỉ sửa `COSTING.md`) → `costing-test-writer` → `costing-dev` chế độ `code` → review.
- `refactor`: `costing-dev` → review. Không gọi test-writer; test hiện có phải xanh và không được đổi.

Test viết **trước** code vì test viết từ yêu cầu và `COSTING.md` khi code chưa tồn tại thì không bị cách cài đặt uốn theo.

## Bước 3 — Review

Gọi `costing-reviewer` với thư mục làm việc và vòng `N` (bắt đầu từ 1). Reviewer không ghi file. Bạn chép **nguyên văn** kết quả nó trả về vào `review_N.md` — không sửa, không tóm tắt.

## Bước 4 — Vòng lặp

- `VERDICT: PASS` → bước 5.
- `VERDICT: FAIL` → nếu có mục blocking liên quan test thì gọi `costing-test-writer` trước, rồi gọi `costing-dev` chế độ `code` kèm đường dẫn `review_N.md`. Sau đó quay lại bước 3 với `N+1`.
- Tối đa **4 vòng review**. Hết vòng vẫn FAIL thì dừng, sang bước 5.
- Một mục blocking bị dev phản đối mà reviewer **giữ nguyên ý kiến qua 2 vòng** thì dừng, đưa cả hai lập luận cho người dùng quyết định. Không để hai bên cãi tiếp.

## Xử lý BLOCKED

Subagent trả về dòng đầu `BLOCKED:` nghĩa là nó đã dừng và không sửa gì. Hỏi người dùng **đúng câu đó**, ghi câu trả lời vào mục *Quyết định của người dùng* trong `task.md`, rồi gọi lại chính subagent đó với cùng tham số.

## Bước 5 — Báo cáo người dùng

- Kết quả: PASS ở vòng N, hoặc dừng vì lý do gì.
- File đã đổi theo từng repo: `git -C <đường dẫn> diff --stat <base>`.
- Dòng kết thúc về `COSTING.md` lấy nguyên văn từ `work.md`.
- Kết quả test lần chạy cuối (từ review cuối cùng).
- Mục non-blocking còn mở, tranh chấp chưa giải quyết.

Không commit, không push. Đó là việc của người dùng.
