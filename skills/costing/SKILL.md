---
name: costing
description: Điều phối việc sửa chức năng tính giá xuất kho theo phương pháp bình quân cuối kỳ, trải trên bốn repo ebwebbe, ebinventory, ebqueue và gogateway, qua bốn subagent costing-plan, costing-test-writer, costing-dev, costing-reviewer. Dùng khi đụng tới công thức bình quân, phân loại chứng từ kho, hàng bán trả lại, hàng mua trả lại, giảm giá hàng mua, tồn đầu kỳ, gộp kho theo cờ byRepository, chia lô kết quả gửi queue, query sổ kho RepositoryLedger trên ClickHouse, hoặc ghi giá vốn ngược vào chứng từ. Cũng dùng khi được hỏi về COSTING.md.
---

# Tính giá xuất kho — điều phối

Bạn (session chính) là **người điều phối**. Bạn **không tự sửa** code, test hay `COSTING.md` — mọi thay đổi do subagent làm. Lý do: người viết code không được là người chấm code. Bạn tự tay sửa là mất lớp kiểm tra độc lập, cả quy trình thành vô nghĩa.

Câu hỏi thuần về nghiệp vụ hoặc `COSTING.md` (không sửa gì) thì không cần điều phối: đọc `RULES.md` và `COSTING.md` của repo liên quan rồi trả lời, tuân mục *Báo cáo đã đọc* trong `RULES.md`.

Tài liệu trong thư mục skill này (gọi là `SKILL` — đường dẫn tuyệt đối của thư mục chứa file này):

- `RULES.md` — bản đồ repo, khởi động chung và luật làm việc. Mọi subagent đều đọc.
- `REVIEW-CHECKLIST.md` — tiêu chí chấm của reviewer.
- `scripts/snapshot.sh` — chụp working tree của một repo thành tree SHA, không đụng trạng thái git.
- Nghiệp vụ nằm trong `COSTING.md` ở gốc từng repo, không nằm ở đây.

## Bước 0 — Chốt phạm vi với người dùng

Làm **trước khi gọi bất kỳ subagent nào**. Đọc mục *Bản đồ repo* trong `RULES.md`, rồi bảo đảm có đủ:

1. Repo nào (một hay nhiều trong bốn) và **đường dẫn tuyệt đối** trên máy này.
2. Loại việc: `bug` / `new-case` (thêm trường hợp nghiệp vụ) / `rule-change` (đổi quy tắc đang có) / `refactor` (không đổi hành vi).
3. Với `bug`: triệu chứng thật, dữ liệu tái hiện nếu có.
4. Task nhỏ thì hỏi người dùng có bỏ qua bước plan không (xem bước 2). Không hỏi thì mặc định có plan.

Thiếu thì hỏi người dùng, gom vào **một lượt hỏi**. Không đoán đường dẫn: sửa nhầm repo vẫn biên dịch được, không có gì báo lỗi.

Kiểm tra từng đường dẫn tồn tại và có `COSTING.md` ở gốc. Không có thì báo người dùng, không đi tiếp.

Với `rule-change`: xác nhận với người dùng **mục nào** trong `COSTING.md` bị đổi và **lý do nghiệp vụ**. Đây là bất biến, không có xác nhận thì không đổi.

## Bước 1 — Tạo thư mục làm việc

Tạo `<gốc workspace>/.claude/work/costing/<YYYYMMDD>-<slug>/` (gọi là `WORK`). Với mỗi repo, lấy:

- `base`: `git -C <đường dẫn> rev-parse HEAD`
- `baseline`: `bash SKILL/scripts/snapshot.sh <đường dẫn>` — tree SHA của working tree **lúc bắt đầu task**, gồm cả thay đổi chưa commit và file chưa track.

Diff thuộc task luôn tính từ `baseline`, nên working tree đang bẩn (thay đổi của task trước, cấu hình riêng của người dùng) **không cần** stash hay lưu file diff. Vẫn chạy `git status --porcelain` và liệt kê các file đang bẩn vào `task.md` để mọi bên biết không được đụng tới.

Ghi `WORK/task.md`:

```markdown
# Task

## Yêu cầu
<nguyên văn yêu cầu người dùng + câu trả lời ở bước 0>

## Loại việc
<bug | new-case | rule-change | refactor>

## Repo
- <tên repo>: <đường dẫn tuyệt đối> — base: <commit> — baseline: <tree SHA>

## Thay đổi có sẵn không thuộc task
- <repo>: <file> (không được đụng tới hay hoàn tác)
(không có thì ghi "Không có")

## Triệu chứng / dữ liệu tái hiện
<nếu có>

## Quyết định của người dùng
<mục COSTING.md bị đổi và lý do; câu trả lời cho các lần BLOCKED>
```

## Bước 2 — Lập plan và người dùng duyệt

Gọi `costing-plan` với `SKILL`, `WORK` và vòng plan `N` (bắt đầu từ 1). Plan không ghi file. Bạn chép **nguyên văn** kết quả vào `WORK/plan.md` (vòng sau ghi đè vòng trước, góp ý cũ đã được plan xử lý).

Đưa plan cho người dùng duyệt, kèm các câu trong *Câu hỏi mở*:

- Duyệt → ghi câu trả lời cho *Câu hỏi mở* vào *Quyết định của người dùng* trong `task.md`, sang bước 3.
- Có góp ý → ghi nguyên văn góp ý vào cuối `plan.md` dưới tiêu đề `## Góp ý của người dùng`, gọi lại `costing-plan` với `N+1`.

Không gọi test-writer hay dev khi plan chưa được duyệt.

**Bỏ qua plan** chỉ khi task nhỏ (ví dụ bug sửa vài dòng trong một repo, không đụng bất biến) **và người dùng đồng ý bỏ qua**. Hỏi rõ ở bước 0, ghi `Plan: bỏ qua — người dùng đồng ý` vào *Quyết định của người dùng*. Không tự quyết bỏ qua.

## Bước 3 — Gọi subagent theo loại việc

Khi gọi subagent **chỉ truyền**: `SKILL`, `WORK` (cả hai là đường dẫn tuyệt đối), số vòng, chế độ (nếu có), và đường dẫn file review cần xử lý (nếu có). **Không truyền** giải thích, phán đoán hay gợi ý cách sửa của bạn — subagent tự đọc file. Lời dẫn của bạn sẽ dẫn dắt nó, nhất là reviewer.

Thứ tự:

- `bug`, `new-case`: `costing-test-writer` → `costing-dev` → review.
- `rule-change`: `costing-dev` chế độ `rule` (chỉ sửa `COSTING.md`) → `costing-test-writer` → `costing-dev` chế độ `code` → review.
- `refactor`: `costing-dev` → review. Repo có bộ test tự động: không gọi test-writer, test hiện có phải xanh và không được đổi. Task có repo **không** có bộ test tự động: gọi `costing-test-writer` trước để viết kịch bản đối chiếu trước/sau (cùng dữ liệu vào, kết quả phải giống hệt).

Test viết **trước** code vì test viết từ yêu cầu và `COSTING.md` khi code chưa tồn tại thì không bị cách cài đặt uốn theo.

## Bước 4 — Review

Gọi `costing-reviewer` với `SKILL`, `WORK` và vòng `N` (bắt đầu từ 1). Reviewer không ghi file. Bạn chép **nguyên văn** kết quả nó trả về vào `WORK/review_N.md` — không sửa, không tóm tắt.

## Bước 5 — Vòng lặp

- `VERDICT: PASS` → bước 6.
- `VERDICT: FAIL` → định tuyến theo trường `Xử lý:` mà reviewer gắn cho từng mục BLOCKING, không tự phán đoán:
  1. Có mục `Xử lý: người dùng` → hỏi người dùng đúng nội dung mục đó, ghi câu trả lời vào *Quyết định của người dùng* trong `task.md` trước khi gọi tiếp.
  2. Có mục `Xử lý: test-writer` → gọi `costing-test-writer` kèm đường dẫn `review_N.md`.
  3. Gọi `costing-dev` chế độ `code` kèm đường dẫn `review_N.md` (luôn gọi, kể cả khi chỉ có mục test-writer — test mới có thể đỏ chờ dev).
  4. Quay lại bước 4 với `N+1`.
- Tối đa **4 vòng review**. Hết vòng vẫn FAIL thì dừng, sang bước 6.
- Một mục blocking bị dev phản đối mà reviewer **giữ nguyên ý kiến qua 2 vòng** thì dừng, đưa cả hai lập luận cho người dùng quyết định. Không để hai bên cãi tiếp.

## Xử lý BLOCKED

Subagent trả về dòng đầu `BLOCKED:` nghĩa là nó đã dừng và không sửa gì. Hỏi người dùng **đúng câu đó**, ghi câu trả lời vào mục *Quyết định của người dùng* trong `task.md`, rồi gọi lại chính subagent đó với cùng tham số.

## Bước 6 — Báo cáo người dùng

- Kết quả: PASS ở vòng N, hoặc dừng vì lý do gì.
- File đã đổi theo từng repo: `git -C <đường dẫn> diff --stat <baseline> $(bash SKILL/scripts/snapshot.sh <đường dẫn>)`.
- Dòng kết thúc về `COSTING.md` lấy nguyên văn từ `work.md`.
- Kết quả test lần chạy cuối (từ review cuối cùng).
- Mục non-blocking còn mở, tranh chấp chưa giải quyết.

Không commit, không push. Đó là việc của người dùng.
