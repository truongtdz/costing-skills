# Task

## Yêu cầu
Tính giá xuất kho bình quân cuối kỳ (luồng ebinventory → ebqueue → store `update_InventoryCosting_TVP`) đang khoá bảng và deadlock khi ghi kết quả. Người dùng chốt thay đổi kiến trúc như sau (nguyên văn ý người dùng, đã thảo luận và xác nhận):

1. **Chia lô theo chứng từ cha.** ebinventory chia kết quả sao cho **không có chứng từ cha nào nằm ở 2 lô**. Chứng từ cha xác định bằng `ReferenceID` của dòng sổ kho:
   - 411: `ReferenceID` = phiếu kho của hoá đơn (`SAInvoice.RSInwardOutwardID`), quan hệ 1-1.
   - 403: `ReferenceID` = phiếu kho của chứng từ hàng bán trả lại, người dùng xác nhận "có ứng tương tự" (1-1).
   - 410, 412, 414, 415: `ReferenceID` = chính phiếu kho.
   - 420, 421, 422: `ReferenceID` = `RSTransfer.ID`.
   Một chứng từ cha có số dòng lớn hơn kích thước lô thì **cho phép lô đó vượt kích thước quy định**, không được cắt chứng từ (người dùng: "trước mắt cho lô đó được hơn so với quy định").
2. **Theo dõi tiến trình bằng TaskLogDetail theo từng lô, bỏ phụ thuộc vào message cuối.**
   - ebwebbe (BE) **chỉ tạo TaskLog**, không tạo TaskLogDetail nữa.
   - ebqueue khi nhận một lô kết quả thì **lưu một TaskLogDetail** tương ứng lô đó.
   - Xử lý xong lô thì cập nhật trạng thái TaskLogDetail của lô, rồi kiểm tra các TaskLogDetail khác của cùng TaskLog: tất cả đã xong thì chuyển TaskLog sang hoàn thành; có lô lỗi thì chuyển TaskLog sang lỗi.
   - Không còn dựa vào cờ `messageFinal` để biết lô nào là lô cuối.
   - Tiêu chí chấp nhận: khi nhiều lô xử lý xong cùng lúc trên nhiều consumer, TaskLog không được đóng sớm khi còn lô chưa xong, và cũng không được bỏ sót việc đóng.
3. ebqueue được chạy **nhiều consumer song song** cho queue kết quả tính giá (người dùng đã đặt 5 trong `application-dev.yml`).
4. Store `update_InventoryCosting_TVP` giữ nguyên cách tính tổng tiền header bằng `SUM` trong cùng lô. Lý do: khi lô không cắt chứng từ cha thì mọi dòng được tính giá của một chứng từ nằm cùng lô, các dòng còn lại không lô nào sửa, nên `SUM` trong lô cho ra tổng cuối cùng đúng, kể cả trường hợp chỉ tính giá một phần vật tư của chứng từ.

Sau khi triển khai, người dùng sẽ tự chạy kiểm thử tải trên DB test và đo lại khoá bảng/deadlock.

## Loại việc
rule-change

## Repo
- ebinventory: D:\_AppInventory\ebinventory — base: 27109e2e130bf8c6add1291e9a93e7f5b200c0a0 (branch prod)
- ebqueue: D:\_AppAll\200133ebqueue — base: cb28526f908203ce5792fd23f80acff91e6865f6 (branch features/truongtd/tgxk)
- ebwebbe: D:\_AppAll\200133ebwebbe — base: c31c22d4b445c61981c5af2bb3bb205ba82fc829 (branch features/truongtd/tgxk)
- gogateway: không sửa (dữ liệu DWH đã có `ReferenceID`).

Working tree có sẵn thay đổi chưa commit, KHÔNG thuộc task này, không được đụng tới hay hoàn tác:
- ebinventory: `src/main/resources/config/application-worker.yml` và `ApplicationProperties.java` (`result-batch-size` / `resultBatchSize` đổi sang 200 để thử nghiệm; giữ nguyên giá trị 200).
- ebqueue: `libs/core-model.jar`, `src/main/resources/config/application-dev.yml` (đã đặt `rabbitmqinventorycosting` 5 consumer), `src/main/resources/config/application-prod.yml`.
- ebwebbe: `libs/core-model.jar`, `src/main/resources/config/application-dev.yml`, `src/main/java/vn/softdreams/ebweb/service/impl/AsyncCalculateOWPriceServiceImpl.java` (đã comment đoạn kiểm cờ `COSTING_CODE` ở dòng 705-707). File này có thể phải sửa trong task (bỏ tạo TaskLogDetail); khi sửa không được hoàn tác phần comment có sẵn.

## Triệu chứng / dữ liệu tái hiện
Đo trên DB test EB99_GR2 ngày 15/10/2026:
- Đợt 1 (lô 1.000, 1 consumer): 201 lô / 195.358 dòng. Theo dõi 100 lần đọc (5 giây/lần) thấy khoá X cấp bảng do ebqueue giữ: `RepositoryLedger` 61 lần, `GeneralLedger` 54, `GeneralLedgerDetail` 46, `RSInwardOutward` 21; 10 phiên khác bị chặn chờ `LCK_M_IX` tới 6,5 giây. Công ty lớn nhất 154 lô mất 27 phút, các công ty khác xếp hàng chờ vì chỉ 1 consumer.
- Đợt 2 (lô 1.000, 5 consumer): khoá bảng giảm mạnh nhưng phát sinh deadlock trong `update_InventoryCosting_TVP` (log ebqueue 19:09 ngày 15/10: "Transaction (Process ID 773/822) was deadlocked ... chosen as the deadlock victim", lô 116/370, TaskLog 886029 chuyển Fail). Deadlock graph không còn trong system_health nên chưa chứng minh được tài nguyên tranh chấp; khả năng cao là header chứng từ (hai lô cùng cập nhật tổng tiền một chứng từ cha).
- Ngoài ra khi 5 consumer chạy, lô mang `messageFinal` có thể xong trước các lô khác nên tiến trình đóng sớm.

## Quyết định của người dùng
- Đổi bất biến `COSTING.md` mục 5 của ebqueue ("một bản tin là một lô, một transaction, xử lý tuần tự", 1 consumer, đóng tiến trình theo lô cuối): cho phép nhiều consumer song song, điều kiện là lô không cắt ngang chứng từ cha; đóng tiến trình theo trạng thái TaskLogDetail của từng lô. Lý do: khoá bảng ảnh hưởng toàn hệ thống, chạy tuần tự làm công ty lớn chặn hàng chờ, deadlock khi song song do hai lô cùng chạm chứng từ cha.
- Đổi/bổ sung `COSTING.md` mục 8 của ebinventory (chia lô kết quả): lô không được cắt ngang chứng từ cha (theo `ReferenceID`), chứng từ lớn hơn kích thước lô thì lô được phép vượt kích thước.
- Chấp nhận trong lúc đang tính giá, tổng tiền header có thể tạm chưa khớp với chi tiết.
- `result-batch-size` giữ 200 như đang đặt trong working tree (thử nghiệm); người dùng chưa chốt giá trị lâu dài.
- Người tạo TaskLogDetail theo lô: ebqueue (khi nhận message lô).
- (Bổ sung sau vòng rule 1) Điều kiện đóng TaskLog là **đã có đủ `batchTotal` lô** ở trạng thái hoàn thành (không phải "mọi TaskLogDetail đang tồn tại đã xong", vì TaskLogDetail chỉ được tạo khi lô tới). Đây là diễn giải đúng ý người dùng "kiểm tra tất cả detail khác đã xong chưa".
- (Trả lời B1 vòng review 1) Chọn phương án A: khi ebqueue nhận **bất kỳ** lô nào của một TaskLog, trong một transaction ngắn, khoá dòng TaskLog bằng `UPDLOCK` (tuần tự hoá giữa các consumer của cùng task), rồi tạo **đủ `batchTotal` TaskLogDetail** ở trạng thái chờ nếu còn thiếu (không tạo trùng), commit. Mỗi lô xử lý xong cập nhật TaskLogDetail của chính lô đó. Nhờ có đủ detail ngay từ lô đầu tiên, logic tự đóng TaskLog của màn hình "Tiến trình dữ liệu" (ebwebfe) và `TaskLogServiceImpl` (ebwebbe) — "mọi detail đang có đều xong" — không còn đóng sớm. Không sửa ebwebfe.
- Không tách message riêng để tạo TaskLogDetail (người dùng đã cân nhắc và bỏ: không bảo đảm thứ tự giữa các consumer).
- Không thêm unique index/cột mới cho mã lô trên TaskLogDetail; chống trùng dựa vào bước khoá `UPDLOCK`.
- Comment cũ trong khối `rabbitmqinventorycosting` của `application-dev.yml`/`application-prod.yml` (ebqueue) — người dùng chưa trả lời; vẫn coi là thay đổi có sẵn, không đụng tới.
- (Dữ liệu, kiểm trên EB99_GR2 ngày 16/10/2026) Số lệnh lắp ráp/tháo dỡ có hơn một phiếu xuất nguyên vật liệu (`RSInwardOutwardDetail` có `RSAssemblyDismantlementDetailID` khác NULL, đếm `DISTINCT RSInwardOutwardID` theo `RSAssemblyDismantlementID`): **0**. Số phiếu kho gắn với hơn một hoá đơn (`SAInvoice.RSInwardOutwardID`): **0**. Mẫu 20.000 dòng xuất 411: 100% `ReferenceID` là phiếu kho của hoá đơn; 420/421/422: 100% `ReferenceID` là `RSTransfer.ID`.
