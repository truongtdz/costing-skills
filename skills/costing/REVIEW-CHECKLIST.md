# Checklist review — tính giá xuất kho

Mỗi mục: kiểm bằng cách mở file, chạy lệnh, đối chiếu. Không chấm theo cảm tính hay theo lời khai trong `work.md`.

Mọi diff ở đây là **diff của task** theo mục *Diff của task* trong `RULES.md` (tính từ `baseline`, không phải từ `base`).

Mức độ:

- **BLOCKING** — sai nghiệp vụ, vi phạm `RULES.md`, lời khai không đúng sự thật, test đỏ, thiếu thứ bắt buộc.
- **NON-BLOCKING** — đặt tên, cấu trúc, đề xuất cải thiện không ảnh hưởng đúng sai.

Mỗi mục BLOCKING phải gắn người xử lý:

- `test-writer` — test thiếu, test sai, kịch bản thủ công thiếu.
- `dev` — code, `COSTING.md`, `work.md`.
- `người dùng` — cần một quyết định nghiệp vụ mà `task.md` chưa có, hoặc mâu thuẫn giữa yêu cầu và `COSTING.md`.

## A. Đúng yêu cầu và đúng chỗ

1. Diff giải quyết đúng yêu cầu trong `task.md`, không hơn không kém. Thay đổi ngoài phạm vi → BLOCKING nếu đổi hành vi, NON-BLOCKING nếu chỉ là dọn dẹp.
2. Sửa đúng repo chịu trách nhiệm theo *Bản đồ repo*. Logic đặt sai repo → BLOCKING. Ví dụ sai chỗ: công thức bình quân viết ở `ebqueue` (phải ở `ebinventory`), làm tròn viết ở `ebinventory` (phải ở `ebqueue`).
3. Không có thay đổi nào ngoài các repo liệt kê trong `task.md`, và không đụng tới file trong *Thay đổi có sẵn không thuộc task*.

## B. Nghiệp vụ

4. Tự đọc `COSTING.md` của từng repo bị sửa. Diff có vi phạm bất biến nào không — nêu số hiệu mục.
5. Với `bug`: nguyên nhân gốc đã được sửa, hay chỉ chặn triệu chứng? Có đường đi khác tới cùng lỗi không?
6. Nếu đổi hợp đồng `ebinventory`–`ebqueue`: cả hai phía đã sửa và khớp nhau.

## C. Lời khai của dev

7. Dòng `Đã đọc COSTING.md — áp dụng mục N: ...`: mở file, mục N có đúng nội dung đó không. Sai hoặc không tồn tại → BLOCKING, ghi rõ là lời khai sai.
8. Có dòng kết thúc về `COSTING.md`. Thiếu → BLOCKING.
9. Dòng `Không cập nhật COSTING.md vì ...` mà diff chạm nghiệp vụ → lý do có đứng vững không.
10. `Đã cập nhật COSTING.md`: mở diff của `COSTING.md`, nội dung có đúng với code mới không, có xoá điều không còn đúng không.
11. Sửa bug mà nguyên nhân không suy ra được từ code → có bất biến mới kèm **ngày và triệu chứng thật** không.
12. Mục mới trong `COSTING.md` có đủ ba ý: X phải là Y — vì sao — vi phạm thì triệu chứng gì.

## D. Test

13. Tự chạy `./mvnw test` ở `ebinventory` nếu repo này có trong `task.md`. Ghi kết quả thật (số test, số đỏ). Đỏ → BLOCKING.
14. Diff của task trên thư mục test: test cũ có bị đổi con số kỳ vọng không. Có → `COSTING.md` phải có mục tương ứng đổi kèm lý do và `task.md` phải có quyết định của người dùng. Không có → BLOCKING.
15. `costing-dev` có sửa file test không (đối chiếu `tests.md` với diff). Có → BLOCKING.
16. Trường hợp nghiệp vụ mới / bug có test tương ứng. Test có thật sự kiểm đúng điều cần kiểm không, hay chỉ chạy qua mà không assert gì đáng kể.
17. Repo không có bộ test: kịch bản kiểm tra thủ công trong `tests.md` có đủ dữ liệu vào và kết quả mong đợi để người khác làm lại được không. Với `refactor`: có kịch bản đối chiếu trước/sau không.

## Đối chiếu plan (nếu có `plan.md`)

18. Kiểm **sau** khi đã tự đánh giá A, B, D. Mỗi mục `[H…]` trong *Hành vi mong đợi* có test hoặc kịch bản tương ứng không — thiếu → BLOCKING, `Xử lý: test-writer`. Diff có lệch *Cách cài đặt* không (sửa chỗ khác, bỏ bước, thêm việc ngoài plan) — lệch mà `work.md` không giải thích → BLOCKING, `Xử lý: dev`; lệch có lý do đứng vững → NON-BLOCKING, ghi lại. Plan đã duyệt không phải bằng chứng đúng: plan sai nghiệp vụ thì vẫn chấm theo `COSTING.md`, `Xử lý: người dùng`.

## E. Phản biện của dev (từ vòng 2)

19. Đọc `review_<N-1>.md` và phần phản biện trong `work.md`. Với mỗi mục blocking cũ: đã sửa đúng, hay dev phản đối? Phản đối thì đánh giá lập luận — đúng thì rút lại mục đó và nói rõ đã rút; sai thì giữ và giải thích vì sao.
