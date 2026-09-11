# Playbook: Implement Firmware Feature

> **Type**: Agent Skill Playbook
> **Agent**: embedded-engineer
> **Triggered by**: /wf-implement-feature khi implement tính năng firmware/embedded
> **Output**: Firmware code (C/C++) với HAL, unit tests, REQ-ID annotation

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi task liên quan đến firmware, driver, hoặc MCU peripheral
- Khi cần implement driver mới (GPIO, UART, SPI, I2C, CAN, ADC)
- Khi cần thêm RTOS task, queue, hoặc semaphore
- Khi cần implement application-layer firmware logic (sensor reading, actuator control, state machine)

---

## Pre-conditions (BẮT BUỘC TRƯỚC KHI BẮT ĐẦU)

```
□ Đọc hardware datasheet của peripheral/MCU liên quan
□ Xác nhận pin assignment từ schematic hoặc board definition
□ Đọc feature spec từ phase2-features/ (REQ-ID, acceptance criteria)
□ Kiểm tra HAL interface đã có chưa (xem design-hardware-abstraction.md)
□ Nếu chưa có HAL interface → chạy design-hardware-abstraction.md TRƯỚC
```

---

## Procedure

### Bước 1: Đọc Feature Spec và Hardware Context

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2 (features), PHASE3 (architecture)

Cần xác định:
□ REQ-ID và FEAT-ID của tính năng cần implement
□ Hardware target: MCU model, peripheral registers (từ datasheet)
□ Pin assignment: GPIO port/pin, alternate function number
□ Timing constraints: baud rate, clock frequency, latency budget
□ Power constraints: có sleep mode không, wakeup sources
□ Interface với components khác: protocol, data format, error codes
```

### Bước 2: Kiểm tra Code Hiện tại (Safety Gate — CORE-020)

```
Search trong codebase trước khi viết code mới:

□ Tìm tên entity: grep -r "driver_name\|PERIPHERAL_Init\|TaskName" src/
□ Tìm file có thể liên quan: find . -name "*.c" | xargs grep -l "REQ_ID"
□ Kiểm tra HAL interface đã implement chưa

Nếu tìm thấy code liên quan:
  → Đọc code hiện tại
  → Xác định implementation_strategy: VERIFY_ONLY | COMPLETE_EXISTING | IMPLEMENT_NEW
  → Nếu strategy mismatch task spec → DỪNG + báo cáo user

Nếu LEGACY_MODE (project-context.md > 500 bytes):
  → Đọc task file → lấy implementation_strategy
  → Follow strategy nghiêm ngặt
```

### Bước 3: Thiết kế HAL Interface (nếu chưa có)

```
Tham khảo: .claude/references/team-expert/engineering/embedded-peripheral-drivers.md §8

Định nghĩa abstract interface trong header file:
  □ Function signatures rõ ràng (init, deinit, read, write, get_status)
  □ Error codes: enum hoặc int return values
  □ Callback typedefs cho interrupt-driven operations
  □ Platform-agnostic data types (stdint.h types: uint8_t, uint32_t, etc.)

Ví dụ path: src/hal/hal_[peripheral].h
```

### Bước 4: Implement Driver / Module

```
Tham khảo knowledge files khi cần:
  - MCU peripheral: .claude/references/team-expert/engineering/embedded-peripheral-drivers.md
  - RTOS patterns: .claude/references/team-expert/engineering/embedded-rtos-patterns.md
  - IoT protocols: .claude/references/team-expert/engineering/embedded-iot-protocols.md

Implementation checklist:
□ REQ-ID comment ở đầu file:
    // REQ-ID: REQ-[DEPT]-[NNN]
    // FEAT-ID: FEAT-[SYS]-[MOD]-[NNN]
□ Không gọi hardware-specific API trực tiếp trong application layer
□ Error handling đầy đủ — không ignore return codes từ HAL functions
□ Mọi shared data với ISR phải khai báo volatile
□ Nếu dùng RTOS: không gọi blocking API từ ISR context
□ Timeout cho mọi blocking operations (không portMAX_DELAY ở production)
□ Watchdog feed nếu operation có thể mất nhiều thời gian

Cấu trúc file chuẩn:
  src/
  ├── hal/
  │   ├── hal_[peripheral].h      ← abstract interface
  │   ├── hal_[peripheral]_stm32.c  ← platform implementation
  │   └── hal_[peripheral]_esp32.c  ← platform implementation
  ├── drivers/
  │   └── [sensor_name].c         ← sensor/peripheral driver
  └── app/
      └── [feature_name].c        ← application logic
```

### Bước 5: Implement Interrupt Handler (nếu cần)

```
ISR Design Rules (BẮT BUỘC):
□ ISR càng ngắn càng tốt — mục tiêu < 10 µs execution time
□ Không gọi blocking functions: HAL_Delay, vTaskDelay, printf
□ Không dùng floating-point operations (nếu FPU không save/restore trong ISR)
□ Set flag hoặc push vào queue → task xử lý logic nặng

Pattern chuẩn:
  // ISR: nhận data → push queue
  void USART2_IRQHandler(void) {
    HAL_UART_IRQHandler(&huart2);
  }
  
  void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart) {
    BaseType_t xWoken = pdFALSE;
    xQueueSendFromISR(xRxQueue, &rxByte, &xWoken);
    portYIELD_FROM_ISR(xWoken);
  }
  
  // Task: process data từ queue
  void vUartProcessTask(void *pv) {
    uint8_t byte;
    while (1) {
      xQueueReceive(xRxQueue, &byte, portMAX_DELAY);
      ProcessByte(byte); // logic nặng ở đây
    }
  }
```

### Bước 6: Unit Testing với Mock HAL

```
Framework: Unity + CMock
Tham khảo: .claude/references/team-expert/engineering/embedded-peripheral-drivers.md §9

Tạo test file: tests/test_[feature_name].c

Test structure:
  #include "unity.h"
  #include "mock_hal_[peripheral].h"  // CMock generated
  #include "[driver].h"
  
  void setUp(void) { /* reset mocks, init test state */ }
  void tearDown(void) { /* cleanup */ }
  
  // Test case: happy path
  void test_[Feature]_[Scenario]_[ExpectedResult](void) {
    // Arrange: setup mock expectations
    HAL_[Peripheral]_[Function]_ExpectAndReturn(..., HAL_OK);
    
    // Act: call the function under test
    Result_t result = Feature_DoSomething();
    
    // Assert: verify output
    TEST_ASSERT_EQUAL(EXPECTED_VALUE, result);
  }

Test cases bắt buộc:
□ Happy path: normal operation, correct output
□ Error path: HAL returns error → driver propagates error correctly
□ Timeout path: HAL times out → driver handles gracefully
□ Edge cases: min/max values, boundary conditions
□ ISR simulation: test queue/semaphore behavior với mock ISR trigger
```

### Bước 7: Integration Testing trên Hardware (nếu có board)

```
Sau khi unit tests pass:

□ Flash firmware lên board: arm-none-eabi-objcopy + OpenOCD/st-flash/esptool
□ Verify peripheral initialization với logic analyzer hoặc oscilloscope:
    - UART: baud rate correct, parity, stop bits
    - SPI: clock polarity/phase (CPOL/CPHA), CS timing
    - I2C: ACK/NACK, clock stretching, addressing
□ Verify functional behavior: outputs match spec
□ Verify timing: measure latency với GPIO toggle + oscilloscope
□ Stress test: run cho nhiều giờ để phát hiện memory leak hoặc race condition
□ Power measurement: đo mA/mW ở các operating modes

Log để verify:
  // Trong firmware: toggle GPIO trước/sau critical section
  HAL_GPIO_WritePin(DEBUG_GPIO_Port, DEBUG_Pin, GPIO_PIN_SET);
  // ... operation ...
  HAL_GPIO_WritePin(DEBUG_GPIO_Port, DEBUG_Pin, GPIO_PIN_RESET);
```

### Bước 8: REQ-ID Annotation và Documentation

```
□ Thêm REQ-ID vào đầu mỗi source file:
    // REQ-ID: REQ-[DEPT]-[NNN]
    // FEAT-ID: FEAT-[SYS]-[MOD]-[NNN]
    // Description: [Mô tả ngắn module này làm gì]

□ Update req-registry.json impl_status: "in_progress" → "done"
□ Ghi brief note về hardware-specific assumptions vào header file:
    // NOTE: Assumes APB1 = 42MHz for baud rate calculation
    // NOTE: CS pin is active-low, controlled via GPIO (not hardware NSS)
```

---

## Output

```
Ghi code vào path do skill cung cấp.
Fallback:
  src/hal/hal_[peripheral].h           ← HAL interface
  src/hal/hal_[peripheral]_[platform].c ← Platform implementation
  src/drivers/[sensor_name].c          ← Driver
  src/app/[feature].c                  ← Application layer
  tests/test_[feature].c               ← Unit tests
```

---

## Checklist trước khi submit

```
□ REQ-ID reference ở đầu mỗi file chính
□ HAL interface tách biệt khỏi application code
□ Unit tests pass (Unity runner: make test)
□ Không có blocking calls trong ISR
□ Tất cả shared data với ISR khai báo volatile
□ Flash/RAM usage đã check với arm-none-eabi-size
□ Error codes propagated đúng — không ignore HAL errors
□ Watchdog feed nếu cần cho long operations
□ impl_status cập nhật trong req-registry.json
```
