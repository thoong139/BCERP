# Playbook: Review Embedded Code

> **Type**: Agent Skill Playbook
> **Agent**: embedded-engineer
> **Triggered by**: Code review request cho firmware/embedded code
> **Output**: Code review report với phân loại severity, cụ thể file:line

---

## Khi nào dùng playbook này

- Code review PR/MR chứa firmware changes
- Review trước khi merge feature branch vào main
- Security audit cho firmware trước khi production release
- Review firmware của người mới làm embedded (onboarding)

---

## Pre-conditions

```
□ Đọc feature spec (REQ-ID) của code được review
□ Biết MCU target và toolchain (để đánh giá platform-specific concerns)
□ Biết loại ứng dụng: consumer IoT, industrial, medical, automotive (khác nhau về safety requirements)
□ Access vào code files (không chỉ diff — cần context xung quanh)
```

---

## Procedure

### Bước 1: Đọc Context và REQ-ID

```
□ Xác định REQ-ID trong mỗi file được review
□ Map code logic về acceptance criteria trong feature spec
□ Kiểm tra: code có implement đúng spec không? Có thừa/thiếu không?
□ Đọc commit message và PR description để hiểu intent
```

### Bước 2: Memory Safety Review (CRITICAL)

**Severity: P0 (Block merge) cho mọi memory issue**

```
STACK OVERFLOW RISKS:
□ Khai báo large local arrays trong functions: char buf[4096] trên stack → BUG
  → Fix: static buffer, heap allocation, hoặc global
□ Recursive functions → measure max recursion depth × frame size vs stack size
□ Printf/sprintf với format strings: snprintf an toàn hơn sprintf
□ FreeRTOS task stack size: stack usage có < 80% không? (uxTaskGetStackHighWaterMark)

BUFFER OVERFLOW:
□ Tất cả string ops: strcpy → strncpy/strlcpy, strcat → strncat/strlcat
□ sprintf → snprintf với explicit size
□ Array index calculations: len-1 có thể underflow nếu len=0 (uint wrap)
□ memcpy/memset: source bounds check trước khi copy

HEAP ISSUES (nếu dùng malloc):
□ malloc return value luôn phải check (có thể NULL)
□ Không gọi malloc/free từ ISR (not reentrant)
□ Heap fragmentation trong long-running systems: xem xét fixed-size pools
□ Double-free: chỉ free pointer một lần, set = NULL sau free

POINTER ISSUES:
□ Dereference trước khi NULL check: func(*ptr) khi ptr có thể NULL
□ Pointer arithmetic vượt array bounds
□ Dangling pointer: trỏ vào local variable đã out of scope
□ Unaligned pointer cast: (uint32_t*)bytePtr trên ARM = HardFault
```

### Bước 3: Interrupt Safety Review (CRITICAL)

**Severity: P0 cho ISR violations**

```
ISR BEST PRACTICES:
□ ISR execution time < 10 µs (đo bằng GPIO toggle + oscilloscope)
□ Không gọi: HAL_Delay, vTaskDelay, printf, malloc, free từ ISR
□ Không dùng floating-point trong ISR nếu FPU context không được saved
□ Không gọi non-reentrant functions (strtok, rand, ...) từ ISR

SHARED DATA SAFETY:
□ Variables shared giữa ISR và task: khai báo volatile
□ Multi-byte data (struct, array): cần critical section hoặc atomic copy
  Sai: if (g_flag) { process(g_data.x, g_data.y); }  ← g_data có thể partial update
  Đúng: taskENTER_CRITICAL(); localCopy = g_data; taskEXIT_CRITICAL(); process(localCopy)
□ 64-bit values trên 32-bit MCU: không atomic, cần critical section
□ Queue/semaphore operations từ ISR: phải dùng xxxFromISR() variant

RTOS-SPECIFIC:
□ Không gọi xQueueSend() từ ISR → phải là xQueueSendFromISR()
□ Không gọi xSemaphoreGive() từ ISR → phải là xSemaphoreGiveFromISR()
□ portYIELD_FROM_ISR(xHigherPriorityTaskWoken) sau mỗi FromISR call
□ RTOS API không được gọi trước scheduler start (xTaskCreate OK, xSemaphoreTake NOT OK)
```

### Bước 4: Timing và Determinism Review

```
BLOCKING IN REAL-TIME CONTEXT:
□ High-priority tasks không bị block bởi low-priority ops (I/O, network)
□ vTaskDelay trong critical path: xem xét event-driven thay polling
□ Polling loops: có timeout chưa? Infinite loop = deadlock nếu hardware fail
□ HAL timeout values: đủ lớn cho worst-case nhưng không quá lớn → system unresponsive

PRIORITY ANALYSIS:
□ Priority assignment logic (xem bảng priorities trong embedded-rtos-patterns.md)
□ Priority inversion: low-priority task giữ resource mà high-priority task cần → dùng mutex
□ Starvation: có task nào never get CPU time không? (tất cả tasks ở cùng priority, task dài không yield)
□ configTICK_RATE_HZ phù hợp với timing requirements chưa?

DEADLINE MISS DETECTION:
□ Có mechanism để detect khi task miss deadline không? (timestamp check, watchdog)
□ HardFault, MemFault, UsageFault handlers có catch và log không?
```

### Bước 5: Power Management Review

```
SLEEP MODES:
□ MCU vào sleep mode đúng không? (WFI, Stop mode, Standby mode)
□ Wakeup sources đủ không? (RTC alarm, GPIO interrupt, UART IDLE)
□ Peripheral clocks disabled trước sleep? (tắt ADC clock, SPI clock để tiết kiệm điện)
□ Current measurement sau khi add feature: vẫn đáp ứng power budget?

ACTIVE MODE OPTIMIZATION:
□ Không bận chờ (busy-wait) nếu có thể dùng interrupt/DMA
□ DMA thay polling cho large data transfers
□ Clock gating: disable peripheral clock khi không dùng

RTOS POWER:
□ FreeRTOS tickless idle: configUSE_TICKLESS_IDLE = 1 nếu low-power
□ Idle task hook: vApplicationIdleHook() → WFI nếu không có task nào ready
```

### Bước 6: Error Handling Review

```
RETURN CODE CHECKING:
□ Mọi HAL function return value được check
□ Error codes propagated lên caller (không bị swallowed silently)
□ Ví dụ sai: HAL_I2C_Mem_Read(...); // ignore return value
□ Ví dụ đúng: if (HAL_I2C_Mem_Read(...) != HAL_OK) { return ERR_I2C_READ; }

HARDWARE FAULT HANDLERS:
□ HardFault_Handler có ít nhất: disable watchdog + log registers + halt
□ MemManage_Handler, BusFault_Handler đã implement chưa?
□ Infinite loop trong fault handlers (không return — return = undefined behavior)

WATCHDOG:
□ Watchdog timer được feed không? Nếu có loop dài → feed ngay trước/sau
□ Feed watchdog KHÔNG được trong ISR nếu ISR có thể bị blocked
□ Watchdog timeout hợp lý: đủ dài cho worst-case normal operation, đủ ngắn để detect freeze

PERIPHERAL ERRORS:
□ I2C BUSY state: có recovery (deinit + re-init) khi bus bị stuck không?
□ SPI transmission failure: retry logic nếu cần
□ CAN bus-off: recovery procedure đã implement chưa?
```

### Bước 7: MISRA-C Compliance (Safety-Critical Only)

```
Áp dụng khi: medical devices, automotive (ISO 26262), industrial safety (IEC 61508)
Không bắt buộc cho: consumer IoT, maker projects

MISRA-C:2012 REQUIRED RULES (tối thiểu):
□ Rule 14.4: if condition phải là boolean (nếu dùng int, cast hoặc compare với 0 explicitly)
□ Rule 15.5: return chỉ ở cuối function (một return point)
□ Rule 17.1: không dùng <stdarg.h> (variadic functions)
□ Rule 18.3: không compare pointers từ different arrays/objects
□ Rule 22.1: tất cả memory được allocated phải được freed trước hết scope
□ Không dùng goto (Rule 15.1) — ngoại lệ: error handling trong C

TOOL SUPPORT:
  - PC-lint (commercial)
  - Cppcheck (free) với MISRA addon
  - IAR MISRA checker
  - GCC: -Wextra, -Wshadow, -Wcast-align bắt một phần
```

### Bước 8: Security Review

```
CREDENTIALS:
□ Không hardcode WiFi SSID/password trong source code
□ Không hardcode MQTT username/password, API keys, device certificates
□ Secrets phải được lưu trong NVS với encryption hoặc được provisioned tại factory

OTA UPDATE SECURITY:
□ OTA update phải verify signature trước khi flash
□ Rollback mechanism nếu firmware mới crash sau boot
□ HTTPS cho OTA download (không HTTP)
□ Version check: từ chối downgrade nếu không có ý nghĩa security

FLASH PROTECTION:
□ Read protection enabled trên MCU (RDPROT = Level 1 hoặc 2)?
□ Flash encryption enabled cho sensitive firmware?
□ Debug interface disabled trong production builds? (JTAG disabled via option bytes)

NETWORK SECURITY:
□ TLS certificate validation bật không? (không skip verify)
□ Certificate pinning nếu backend server cố định
□ Không dùng self-signed certs trong production
□ MQTT QoS và retain settings hợp lý

INPUT VALIDATION:
□ Downlink data (từ server, BLE, UART) được validate trước khi parse
□ Buffer size check trước khi copy data nhận được vào buffer
□ Protocol state machine chỉ accept valid transitions
```

### Bước 9: REQ-ID Traceability Review

```
□ Mọi source file có REQ-ID comment không?
    // REQ-ID: REQ-[DEPT]-[NNN]
□ REQ-ID trong file tương ứng với feature spec không?
□ Code implement đúng requirements trong spec không? (check acceptance criteria)
□ Không có undocumented features (code không có REQ-ID tương ứng trong registry)
□ impl_status trong req-registry.json phản ánh đúng thực trạng
```

---

## Output Format

```markdown
## Code Review Report — [Module/PR Name]

**Reviewer**: embedded-engineer agent
**Date**: [YYYY-MM-DD]
**Target**: [MCU, firmware type, REQ-IDs]

---

### P0 — Block Merge (phải fix trước khi merge)

| # | File:Line | Issue | Fix |
|---|-----------|-------|-----|
| 1 | `src/driver/uart.c:45` | `xQueueSend()` được gọi từ ISR context — phải dùng `xQueueSendFromISR()` | Đổi thành `xQueueSendFromISR()` + thêm `portYIELD_FROM_ISR()` |
| 2 | `src/app/config.c:12` | WiFi password hardcoded trong source code | Move vào NVS provisioning |

### P1 — Nên fix trong PR này

| # | File:Line | Issue | Recommendation |
|---|-----------|-------|----------------|
| 1 | `src/driver/spi.c:78` | Không check return value của `HAL_SPI_Transmit()` | Add error check + propagate to caller |

### P2 — Để sau (tech debt)

| # | File:Line | Issue | Note |
|---|-----------|-------|------|
| 1 | `src/app/main.c:156` | Polling loop với HAL_Delay — có thể dùng interrupt-driven | Low priority nếu timing không critical |

### ✅ Điểm tốt

- REQ-ID comment đầy đủ trong tất cả files
- ISR handler ngắn gọn, chỉ set flag
- HAL interface rõ ràng, tách biệt platform code

### Kết luận

- **Quyết định**: ❌ REQUEST_CHANGES / ⚠️ APPROVE_WITH_COMMENTS / ✅ APPROVE
- **P0 count**: N
- **P1 count**: N
```

---

## Checklist trước khi submit review

```
□ Đã review memory safety (stack, heap, buffer bounds)
□ Đã review interrupt safety (ISR-safe APIs, volatile, critical sections)
□ Đã review timing/determinism (blocking ops, priorities, starvation)
□ Đã review error handling (return codes, fault handlers, watchdog)
□ Đã review security (credentials, OTA, TLS, input validation)
□ Đã review REQ-ID traceability
□ Report có file:line cụ thể cho mỗi issue
□ Mỗi P0 issue có suggested fix
□ Điểm tốt cũng được ghi nhận (không chỉ negative)
```
