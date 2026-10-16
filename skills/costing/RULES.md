# Luật làm việc — tính giá xuất kho bình quân cuối kỳ

File này là **quy trình làm việc**. Quy tắc nghiệp vụ không nằm ở đây — chúng nằm trong `COSTING.md` ở **gốc repo đang sửa**, mỗi repo một bản với nội dung riêng.

Không chép nghiệp vụ vào đây. File này nói *làm theo trình tự nào*, `COSTING.md` nói *đúng sai ra sao*.

## Bản đồ repo

```
ebwebbe ──RabbitMQ──> ebinventory ──RabbitMQ──> ebqueue ──> MSSQL
                           │
                           ├── đọc sổ kho thô: gogateway (ClickHouse)
                           └── hỏi phân loại hàng bán trả lại: ebwebbe
```

- `gogateway` — query DWH, ClickHouse, dựng dữ liệu sổ kho thô.
- `ebinventory` — công thức bình quân, phân loại trường hợp nghiệp vụ, gom nhóm.
- `ebqueue` — ghi kết quả vào chứng từ, làm tròn, ranh giới giao dịch.
- `ebwebbe` — màn hình tính giá, store cập nhật chứng từ, luồng cũ.

## Phân vai

- `costing-test-writer`: chỉ sửa file test.
- `costing-dev`: sửa code và `COSTING.md`. **Không sửa file test.**
- `costing-reviewer`: không sửa gì.
- Session chính: điều phối, ghi `task.md` và `review_N.md`, không sửa code/test/`COSTING.md`.

## Dừng và hỏi — giao thức BLOCKED

Subagent không hỏi được người dùng. Gặp một trong các trường hợp sau thì **dừng, không sửa gì**, trả về với dòng đầu tiên là:

    BLOCKED: <một câu hỏi cụ thể, đủ để người dùng trả lời ngay>

Các trường hợp bắt buộc BLOCKED:

1. `task.md` không nói rõ repo hoặc đường dẫn, hoặc đường dẫn không tồn tại.
2. Việc được giao **mâu thuẫn** với một bất biến trong `COSTING.md` mà mục *Quyết định của người dùng* chưa cho phép đổi. Nêu rõ mục nào, mâu thuẫn ra sao. Không tự ý đổi bất biến.
3. Không xác định được hành vi đúng từ `task.md` và `COSTING.md`.

Không được đoán rồi làm tiếp.

## Báo cáo đã đọc — và chỉ báo khi thật sự đã đọc

Đọc `COSTING.md` rồi thì ghi vào báo cáo, kèm **số hiệu mục đã áp dụng và tóm tắt nội dung mục đó**:

    Đã đọc COSTING.md (ebinventory) — áp dụng mục 3: dòng tồn đầu kỳ phải cộng dồn, không ghi đè.

**Chưa mở file thì tuyệt đối không ghi dòng này.** Ghi mà chưa đọc là nói dối, và nguy hiểm hơn im lặng vì người đọc sẽ tin rằng đã có người kiểm tra. Chưa đọc thì nói thẳng là chưa đọc.

Lý do phải trích số hiệu mục kèm nội dung: đó là thứ **mở file ra đối chiếu trong vài giây là biết thật hay bịa**. Reviewer sẽ đối chiếu.

## Cập nhật COSTING.md — bắt buộc khi chạm nghiệp vụ

Thay đổi nào **chạm vào nghiệp vụ** thì phải cập nhật `COSTING.md` **trong cùng lần sửa**, không để lần sau.

Nguyên tắc: sửa xong thì `COSTING.md` phải mô tả đúng hệ thống **như nó đang là**. Điều đã đổi thì sửa lại, điều đúng mà chưa có thì thêm vào, điều không còn đúng nữa thì xoá đi. Tự xét theo nguyên tắc này cho mọi thay đổi, kể cả loại chưa từng gặp — đây không phải danh sách đóng.

Trường hợp dễ bỏ sót: vừa sửa một bug mà **nguyên nhân không suy ra được từ code** thì phải thêm một bất biến mới, **kèm ngày và triệu chứng thật**. Đó là loại kiến thức mất đi là không lấy lại được.

**Không** cập nhật khi chỉ đổi tên biến, format, refactor nội bộ, thêm log, sửa chính tả và những việc tương tự. `COSTING.md` chứa điều **không suy ra được từ code**, không phải bản mô tả code.

## Viết một mục mới theo dạng nào

Mỗi mục phải trả lời đủ ba ý: **X phải là Y** — **vì sao** — **vi phạm thì triệu chứng gì**.

Câu kiểu *"hãy cẩn thận"*, *"nhớ kiểm tra kỹ"* là vô dụng, không đưa vào.

## Sửa COSTING.md của repo nào

Sửa `COSTING.md` của **đúng repo chịu trách nhiệm**, theo bản đồ ở trên.

**Không chép nội dung sang repo khác.** Ngoại lệ duy nhất là hợp đồng giữa `ebinventory` và `ebqueue`: chủ sở hữu là `ebinventory`, đổi thì phải sửa cả hai phía và nói rõ trong báo cáo.

## Bộ test

`ebinventory` có bộ test đơn vị cho phần tính giá. Chạy `./mvnw test` ở gốc repo, mất khoảng hai giây, không cần DB hay queue. Chi tiết xem mục *Bộ test tự động* trong `COSTING.md` của `ebinventory`.

- **Sửa phần tính giá thì đổi code, không đổi test.** Test đỏ nghĩa là đã làm lệch nghiệp vụ, kể cả khi code mới nhìn gọn hơn và biên dịch sạch.
- Muốn đổi một con số kỳ vọng thì mục tương ứng trong `COSTING.md` phải được sửa **trước**, kèm lý do nghiệp vụ. Không sửa test cho vừa code.
- Thêm trường hợp nghiệp vụ mới thì **thêm test trong cùng lần sửa**.
- Repo không có bộ test tự động thì ghi rõ như vậy và mô tả kịch bản kiểm tra thủ công (dữ liệu vào, kết quả mong đợi, cách kiểm).

## Dòng kết thúc của costing-dev

Mỗi lần sửa, `work.md` phải có một trong hai dòng:

- `Đã cập nhật COSTING.md: <repo> — <mục nào, thêm hay sửa>`
- `Không cập nhật COSTING.md vì <lý do>`

Thiếu dòng này nghĩa là chưa làm xong.
