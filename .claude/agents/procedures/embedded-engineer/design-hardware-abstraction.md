# Playbook: Design Hardware Abstraction Layer (HAL)

> **Type**: Agent Skill Playbook
> **Agent**: embedded-engineer
> **Triggered by**: Khi cần thiết kế HAL layer trước khi implement drivers
> **Output**: HAL interface headers, BSP definition, portability checklist

---

## Khi nào dùng playbook này

- Trước khi implement bất kỳ driver nào trong project mới
- Khi cần port firmware sang MCU platform khác
- Khi cần enable unit testing không cần hardware thật
- Trong phase Architecture (Phase 3) khi advisor cho embedded system

---

## Pre-conditions

```
□ Xác định tất cả peripherals cần sử dụng (từ feature spec và hardware BOM)
□ Xác định các MCU platforms target (1 hay nhiều platforms?)
□ Xác định testing strategy: host-based unit tests vs HIL (hardware-in-the-loop)
□ Đọc feature spec và architecture docs để biết interface requirements
```

---

## Procedure

### Bước 1: Inventory Peripherals và Interfaces

```
Liệt kê tất cả hardware interfaces cần abstract:

Peripherals:
  □ Communication: UART, SPI, I2C, CAN, USB
  □ I/O: GPIO (input/output/interrupt), ADC, DAC, PWM
  □ Timers: hardware timer, watchdog timer
  □ Memory: Flash read/write (for config storage), NVS

System services:
  □ Delay/Timing: ms delay, us delay, get tick count
  □ Interrupt control: enable/disable global interrupts
  □ Critical sections (RTOS-aware)
  □ Logging/Debug output

External devices (cần driver, build trên HAL):
  □ Sensors: temperature, pressure, accelerometer...
  □ Actuators: relay, motor driver, servo
  □ Displays: OLED, TFT
  □ Comms: MQTT client, BLE stack
```

### Bước 2: Thiết kế HAL Interface Headers

**Nguyên tắc thiết kế HAL:**

```
1. Platform-agnostic: header KHÔNG #include bất kỳ MCU-specific header nào
2. Type-safe: dùng stdint.h types (uint8_t, uint32_t), enum cho error codes
3. Return-value convention: int (0 = success, negative = error) hoặc enum
4. Minimal dependencies: HAL headers không depend vào nhau
5. Testable: interface đủ fine-grained để mock từng operation
```

**hal_gpio.h (ví dụ):**

```c
/* hal_gpio.h — Platform-agnostic GPIO interface */
#ifndef HAL_GPIO_H
#define HAL_GPIO_H

#include <stdint.h>
#include <stdbool.h>

/* Pin descriptor — platform agnostic */
typedef struct {
  uint8_t port;    /* Port identifier (0=A, 1=B, ...) */
  uint8_t pin;     /* Pin number (0-15) */
} GpioPin_t;

typedef enum {
  GPIO_DIR_INPUT = 0,
  GPIO_DIR_OUTPUT
} GpioDir_t;

typedef enum {
  GPIO_PULL_NONE = 0,
  GPIO_PULL_UP,
  GPIO_PULL_DOWN
} GpioPull_t;

typedef void (*GpioIrqCallback_t)(GpioPin_t pin);

/* HAL Interface */
typedef struct {
  int   (*init)(GpioPin_t pin, GpioDir_t dir, GpioPull_t pull);
  void  (*set)(GpioPin_t pin, bool state);
  bool  (*get)(GpioPin_t pin);
  void  (*toggle)(GpioPin_t pin);
  int   (*attachInterrupt)(GpioPin_t pin, GpioIrqCallback_t cb, bool risingEdge);
  void  (*deinit)(GpioPin_t pin);
} GpioHal_t;

/* Platform instances — defined in platform-specific .c files */
extern const GpioHal_t g_gpioHal;

#endif /* HAL_GPIO_H */
```

**hal_i2c.h (ví dụ):**

```c
/* hal_i2c.h */
#ifndef HAL_I2C_H
#define HAL_I2C_H

#include <stdint.h>

typedef enum {
  HAL_I2C_OK = 0,
  HAL_I2C_ERR_TIMEOUT = -1,
  HAL_I2C_ERR_NACK    = -2,
  HAL_I2C_ERR_BUS     = -3,
  HAL_I2C_ERR_BUSY    = -4
} I2cStatus_t;

typedef struct {
  I2cStatus_t (*init)(uint32_t speedHz);
  I2cStatus_t (*writeReg)(uint8_t devAddr, uint8_t regAddr,
                           const uint8_t *data, uint16_t len, uint32_t timeoutMs);
  I2cStatus_t (*readReg)(uint8_t devAddr, uint8_t regAddr,
                          uint8_t *data, uint16_t len, uint32_t timeoutMs);
  I2cStatus_t (*isDeviceReady)(uint8_t devAddr, uint32_t timeoutMs);
  void        (*deinit)(void);
} I2cHal_t;

extern const I2cHal_t g_i2cHal;

#endif /* HAL_I2C_H */
```

**hal_system.h — timing và critical sections:**

```c
/* hal_system.h */
#ifndef HAL_SYSTEM_H
#define HAL_SYSTEM_H

#include <stdint.h>

typedef struct {
  void      (*delayMs)(uint32_t ms);
  void      (*delayUs)(uint32_t us);
  uint32_t  (*getTickMs)(void);
  void      (*enterCritical)(void);
  void      (*exitCritical)(void);
  void      (*reset)(void);           /* Software reset */
  void      (*feedWatchdog)(void);
} SystemHal_t;

extern const SystemHal_t g_systemHal;

#endif
```

### Bước 3: Platform-Specific Implementations

**hal_i2c_stm32.c:**

```c
/* hal_i2c_stm32.c — STM32 HAL implementation */
#include "hal_i2c.h"
#include "stm32f4xx_hal.h"

extern I2C_HandleTypeDef hi2c1; /* Defined in main.c hoặc i2c.c */

static I2cStatus_t stm32_i2c_init(uint32_t speedHz) {
  /* Clock speed được config ở CubeMX/ioc file */
  /* Chỉ cần verify ở đây */
  (void)speedHz;
  return (HAL_I2C_GetState(&hi2c1) == HAL_I2C_STATE_READY) ? HAL_I2C_OK : HAL_I2C_ERR_BUS;
}

static I2cStatus_t stm32_i2c_writeReg(uint8_t devAddr, uint8_t regAddr,
                                        const uint8_t *data, uint16_t len, uint32_t to) {
  HAL_StatusTypeDef status = HAL_I2C_Mem_Write(
    &hi2c1, devAddr << 1, regAddr, I2C_MEMADD_SIZE_8BIT,
    (uint8_t*)data, len, to
  );
  switch (status) {
    case HAL_OK:      return HAL_I2C_OK;
    case HAL_TIMEOUT: return HAL_I2C_ERR_TIMEOUT;
    case HAL_BUSY:    return HAL_I2C_ERR_BUSY;
    default:          return HAL_I2C_ERR_BUS;
  }
}

/* ... implement các function khác tương tự ... */

const I2cHal_t g_i2cHal = {
  .init         = stm32_i2c_init,
  .writeReg     = stm32_i2c_writeReg,
  .readReg      = stm32_i2c_readReg,
  .isDeviceReady= stm32_i2c_isDeviceReady,
  .deinit       = stm32_i2c_deinit
};
```

**hal_i2c_mock.c (cho unit tests):**

```c
/* hal_i2c_mock.c — Mock implementation (linked in UNIT_TEST builds) */
#include "hal_i2c.h"
#include <string.h>

/* Test state — readable bởi test cases */
typedef struct {
  uint8_t lastDevAddr;
  uint8_t lastRegAddr;
  uint8_t writtenData[256];
  uint16_t writtenLen;
  uint8_t readData[256];   /* Populate trước khi test */
  I2cStatus_t returnStatus; /* Simulate errors */
} MockI2cState_t;

MockI2cState_t g_mockI2c = {0};

static I2cStatus_t mock_writeReg(uint8_t dev, uint8_t reg, const uint8_t *data, uint16_t len, uint32_t to) {
  g_mockI2c.lastDevAddr = dev;
  g_mockI2c.lastRegAddr = reg;
  memcpy(g_mockI2c.writtenData, data, len);
  g_mockI2c.writtenLen = len;
  return g_mockI2c.returnStatus;
}

static I2cStatus_t mock_readReg(uint8_t dev, uint8_t reg, uint8_t *data, uint16_t len, uint32_t to) {
  memcpy(data, g_mockI2c.readData, len);
  return g_mockI2c.returnStatus;
}

const I2cHal_t g_i2cHal = {
  .writeReg = mock_writeReg,
  .readReg  = mock_readReg,
  /* ... */
};
```

### Bước 4: Board Support Package (BSP)

**bsp.h — Board-specific pin assignments:**

```c
/* bsp.h — Board Support Package */
/* Chứa pin definitions cụ thể của board, không phải HAL abstraction */
#ifndef BSP_H
#define BSP_H

#include "hal_gpio.h"

/* LED */
#define BSP_LED_RED    (GpioPin_t){.port=0, .pin=5}  /* PA5 */
#define BSP_LED_GREEN  (GpioPin_t){.port=2, .pin=13} /* PC13 */

/* Buttons */
#define BSP_BTN_USER   (GpioPin_t){.port=0, .pin=0}  /* PA0 */

/* UART Debug */
#define BSP_UART_DEBUG  USART2    /* Platform-specific, chỉ dùng trong bsp.c */

/* I2C Bus assignments */
#define BSP_I2C_SENSOR  I2C1     /* Platform-specific */

/* Functions */
void BSP_Init(void);
void BSP_LED_Set(GpioPin_t led, bool state);
void BSP_DelayMs(uint32_t ms);

#endif /* BSP_H */
```

### Bước 5: Portability Checklist

```
Review từng file để đảm bảo portability:

TYPES:
□ Không dùng int/long/unsigned trực tiếp cho fixed-size data → dùng uint8_t, int32_t, etc.
□ Không assume sizeof(int) = 4 (có thể = 2 trên AVR)
□ Không dùng platform-specific types: u8, UINT8, uint8 → chỉ uint8_t (từ stdint.h)

ENDIANNESS:
□ Không assume endianness khi serialize multi-byte values
□ Dùng explicit byte shifts: value = (buf[0] << 8) | buf[1]  (big-endian)

ALIGNMENT:
□ Không unaligned memory access: uint32_t *ptr = (uint32_t*)byteArray; ← UNDEFINED BEHAVIOR trên ARM
□ Dùng memcpy cho unaligned access:
    uint32_t val; memcpy(&val, byteArray, sizeof(val));

PLATFORM MACROS:
□ Không dùng #ifdef STM32 / #ifdef ESP32 trong application layer
□ Platform selection CHỈ trong hal_[peripheral]_[platform].c và bsp.c

VOLATILE:
□ Mọi variable được access từ cả ISR lẫn normal context: volatile
□ Hardware registers (volatile uint32_t *): luôn volatile
```

### Bước 6: Review Criteria

```
HAL design quality review:

Interface stability:
□ Function signatures ổn định — thêm features bằng new functions, không sửa signatures
□ Error codes có forward-compatible (enum với explicit values)
□ Không leak platform types qua interface (không có HAL_I2C_HandleTypeDef trong header)

Testability:
□ Có thể swap implementation bằng compile-time linking (không runtime)
□ Mock implementation dễ viết — không có hidden global state
□ Mỗi HAL function có thể test độc lập

Separation of concerns:
□ HAL layer: communication protocol (how to send bytes)
□ Driver layer: device protocol (what bytes mean for specific chip)
□ Application layer: business logic (what to do with data)
□ BSP layer: board-specific wiring (which GPIO = which function)

Không được vi phạm:
□ Application layer import MCU-specific headers
□ HAL interface functions > 5 parameters
□ HAL header #include platform-specific headers
□ Shared mutable state giữa driver instances (không thread-safe)
```

---

## Output

```
Files tạo trong project:
  include/hal/hal_gpio.h          ← GPIO abstract interface
  include/hal/hal_uart.h          ← UART abstract interface
  include/hal/hal_spi.h           ← SPI abstract interface
  include/hal/hal_i2c.h           ← I2C abstract interface
  include/hal/hal_system.h        ← Timing, critical sections
  include/bsp/bsp.h               ← Board pin assignments
  src/hal/hal_gpio_stm32.c        ← STM32 implementation
  src/hal/hal_i2c_stm32.c         ← STM32 implementation
  src/hal/hal_gpio_esp32.c        ← ESP32 implementation (nếu cần)
  src/hal/hal_i2c_esp32.c         ← ESP32 implementation (nếu cần)
  tests/mocks/hal_gpio_mock.c     ← Mock cho unit tests
  tests/mocks/hal_i2c_mock.c      ← Mock cho unit tests
  src/bsp/bsp_[board_name].c      ← BSP implementation
```

---

## Checklist

```
□ Tất cả peripheral interfaces có abstract header (không platform-specific types)
□ Platform implementations build thành công
□ Mock implementations compile được trên host (không cần MCU headers)
□ Portability checklist pass cho tất cả application code
□ BSP document rõ pin assignments (comment + schematic reference)
□ Unit test với mock: ít nhất 1 test case per driver verify mock works
□ README có hướng dẫn: "Để port sang platform X, implement hal_*_X.c"
```
