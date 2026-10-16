# Review vòng 2

## Đã kiểm
Đã đọc COSTING.md (ebinventory). Đối chiếu các mục:
- Mục 1: công thức bình quân. Nhóm tính giá nay ghi theo cờ gộp kho, khớp với mục 10.
- Mục 4: chỉ 412, 230/231/232, 403 có luật riêng. Có thêm dòng trỏ sang 10a cho chuyển kho.
- Mục 7: hợp đồng ba trường. Diff không đổi hợp đồng.
- Mục 10: chỉ gộp kho khi nhận đúng `false`; `null` giữ cách tính riêng từng kho.
- Mục 10a: khi gộp kho thì bỏ 420/421/422 khỏi cả tử số lẫn mẫu số, dòng xuất vẫn được gán giá. Khi `true`/`null` thì giữ cách cũ, có UT_071, UT_072 ghi nhận hiện trạng.
- Mục 11: tổng 72 test, có bảng mã, bảng phủ và định nghĩa "phủ" bằng cài lỗi.

Đã đọc COSTING.md (ebqueue) — mục 2: 420/421/422 → `RSTransferDetail.ID` (dòng 37).
Đã đọc COSTING.md (gogateway) — mục 1: `ORDER BY MaterialGoodsID, RepositoryID, IsOpeningStock DESC, PostedDate`. Đã đối chiếu với `D:\_AppInventory\gogateway\internal\datasets\tinh-gia-xuat-kho\query.sql`: câu này không lọc TypeID, nên dòng chuyển kho ở cả kho đi lẫn kho đến đều đi vào ebinventory.

Đối chiếu thêm `D:\_AppAll\200133ebwebbe\src\main\java\vn\softdreams\ebweb\rabbitmq\rabbitmqinventorycosting\RabbitMQInventoryCostingSenderServiceImpl.java:84-86`. Khi `byRepository` khác `TRUE` thì `repositoryIDs` là danh sách rỗng, tức lấy mọi kho. Như vậy khi gộp kho, cả hai đầu của chứng từ chuyển kho luôn nằm trong dữ liệu. Điều này giải quyết mục "Không chắc" số 2 của vòng 1.

Test: chạy `JAVA_HOME="C:/Program Files/Eclipse Adoptium/jdk-21.0.10.7-hotspot" ./mvnw test` ở `D:\_AppInventory\ebinventory` → 72 test, 0 đỏ (CostingServiceImplTest 47, CostingResultSenderServiceImplTest 10, CostingQueueListenerTest 15), BUILD SUCCESS. Lần chạy bằng JDK mặc định bị enforcer chặn và không tính.

Diff:
- ebinventory: 4 file.
  - `COSTING.md`: sửa mục 1, 4, 11; thêm mục 10a.
  - `CostingServiceImpl.java`: thêm tham số `byRepository` cho `calculateByGroup`, thêm nhánh `!byRepository && isTransfer`, thêm hàm `isTransfer`.
  - `CostingServiceImplTest.java`: thêm UT_068 đến UT_072 và các hàm trợ giúp.
  - `CostingTestData.java`: thêm `transferOutward` và `transferInward`.
- ebwebbe, ebqueue, gogateway: HEAD trùng base. Working tree chỉ có các file đã có sẵn từ trước mà task.md đã liệt kê.
- Line ending: core.autocrlf=true. Working tree là CRLF đồng nhất, git diff không báo đổi toàn file.

## BLOCKING
Không có

## NON-BLOCKING
- [N1] Javadoc của UT_068 (`CostingServiceImplTest.java`, khối trên `allRepositories_transferExcludedFromAverage`) ghi "Hệ thống đang ra 19.920". UT_069 ghi "hệ thống đang ra 400.000 / 25 = 16.000". Sau bản sửa, hệ thống không còn ra các số này nữa. Chữ "đang" nên đổi thành "code trước bản sửa ra ...", tránh người đọc sau hiểu là hành vi hiện tại. Bằng chứng: test diff, các dòng javadoc tương ứng. Số học vẫn đúng: 498.000/25 = 19.920.

## Phản biện vòng trước (từ vòng 2)
- [B1 vòng 1] Đã sửa đúng.
  - UT_071 (`true`) và UT_072 (`null`) dùng `ledgerWithTransferBetweenRepositories`.
  - Tự tính lại: K1 = 200.000/20 = 10.000. K2 = (300.000 + 100.000)/20 = 20.000.
  - Nếu xoá vế `!byRepository &&` ở `CostingServiceImpl.java:173` thì dòng nhập kho đến bị bỏ ở nhóm K2. Khi đó K2 = 300.000/10 = 30.000 và X2 đỏ. Kết quả này khớp với lời khai cài lỗi trong tests.md vòng 2 ("expected 20000 but was 30000").
  - COSTING.md mục 11 đã thêm UT_071, UT_072 vào bảng mã, bảng phủ 10a và danh sách test ghi nhận hiện trạng. Javadoc của hai test ghi rõ chỉ ghi nhận hiện trạng.
- [N1 vòng 1] Đã sửa: 10a tách "Triệu chứng thật" (chỉ 19.600) khỏi đoạn "Cơ chế (suy ra, không quan sát trực tiếp)" (90.000, 16.000).
- [N2 vòng 1] Đã sửa: mục 1 nay ghi nhóm theo cờ gộp kho.
- [N3 vòng 1] Đã sửa: câu ở mục 11 đã thêm phần trừ (mục 5) và trỏ tới danh sách test ghi nhận hiện trạng. Câu cuối 10a không còn trái với mục 11.

Lời khai trong work.md / tests.md vòng 2 đã đối chiếu:
- Các mục COSTING được trích dẫn có thật và đúng nội dung: ebinventory 10, 10a, 11; ebqueue 2; gogateway 1.
- work.md có dòng kết thúc "Đã cập nhật COSTING.md".
- Dev không sửa code ở vòng 2. Diff `src/main` chỉ gồm thay đổi của vòng 1.
- Số test 72 khớp với kết quả tôi tự chạy.
- Test cũ không bị đổi con số kỳ vọng: diff test chỉ có thêm, không có dòng `-` nào.

## Không chắc
- Luồng cũ ebwebbe → ebqueue (proc tính giá cũ, dành cho công ty chưa chuyển sang ebinventory) chưa được kiểm. Nếu còn công ty chạy luồng cũ thì bug gộp kho có thể vẫn còn ở đó. Cần người giao việc xác nhận phạm vi.
- Kịch bản thủ công bước 3–5 trong tests.md chưa chạy trên môi trường thật: cả hai dòng CK có thành tiền 100.000, chạy lại lần hai vẫn ra 20.000. Cần chạy để xác nhận đầu-cuối, gồm việc store ghi `IWAmount` cho dòng nhập kho đến theo `DetailID`.

VERDICT: PASS
