# Embedded Systems - Peripheral Drivers & HAL Design

> **Domain**: Embedded Systems / Kỹ thuật Nhúng
> **Last Updated**: 2026-04-13
> **Nguồn**: STM32 HAL Reference Manual, ESP-IDF Programming Guide, ARM CMSIS Driver Specification

---

## 1. GPIO

### 1.1 Configuration Modes

| Mode | Dùng khi | Notes |
|------|---------|-------|
| `GPIO_MODE_INPUT` | Đọc tín hiệu ngoài | Pull-up/down tùy input impedance |
| `GPIO_MODE_OUTPUT_PP` | Drive output (push-pull) | Có thể source và sink current |
| `GPIO_MODE_OUTPUT_OD` | I2C, one-wire, wired-OR | Cần external pull-up |
| `GPIO_MODE_AF_PP` | UART TX, SPI MOSI/SCK | Alternate function, push-pull |
| `GPIO_MODE_AF_OD` | I2C SDA/SCL | Alternate function, open-drain |
| `GPIO_MODE_ANALOG` | ADC input, DAC output | Disable digital buffer để giảm noise |
| `GPIO_MODE_IT_RISING/FALLING` | External interrupt | Cần enable NVIC |

### 1.2 Interrupt (EXTI) Pattern

```c
/* STM32 EXTI configuration */
GPIO_InitTypeDef GPIO_InitStruct = {
  .Pin = BUTTON_PIN,
  .Mode = GPIO_MODE_IT_FALLING,  /* trigger on falling edge */
  .Pull = GPIO_PULLUP
};
HAL_GPIO_Init(BUTTON_GPIO_Port, &GPIO_InitStruct);
HAL_NVIC_SetPriority(EXTI0_IRQn, 5, 0); /* priority < configMAX_SYSCALL_INTERRUPT_PRIORITY */
HAL_NVIC_EnableIRQ(EXTI0_IRQn);

/* ISR */
void EXTI0_IRQHandler(void) {
  HAL_GPIO_EXTI_IRQHandler(BUTTON_PIN); /* clears pending flag */
}

/* Callback — được gọi từ HAL_GPIO_EXTI_IRQHandler */
void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin) {
  if (GPIO_Pin == BUTTON_PIN) {
    xSemaphoreGiveFromISR(xButtonSem, &xHigherPriorityTaskWoken);
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
  }
}
```

### 1.3 Debounce Pattern

```c
/* Software debounce trong task (sau ISR signal) */
void vButtonTask(void *pvParameters) {
  const TickType_t DEBOUNCE_MS = 50;
  TickType_t xLastTrigger = 0;
  
  while (1) {
    xSemaphoreTake(xButtonSem, portMAX_DELAY);
    TickType_t xNow = xTaskGetTickCount();
    if ((xNow - xLastTrigger) > pdMS_TO_TICKS(DEBOUNCE_MS)) {
      xLastTrigger = xNow;
      HandleButtonPress();
    }
  }
}
```

---

## 2. UART

### 2.1 Init và Modes

```c
/* UART init (STM32 HAL) */
UART_HandleTypeDef huart2 = {
  .Instance = USART2,
  .Init.BaudRate = 115200,
  .Init.WordLength = UART_WORDLENGTH_8B,
  .Init.StopBits = UART_STOPBITS_1,
  .Init.Parity = UART_PARITY_NONE,
  .Init.Mode = UART_MODE_TX_RX,
  .Init.HwFlowCtl = UART_HWCONTROL_NONE
};
HAL_UART_Init(&huart2);

/* Transmit modes */
HAL_UART_Transmit(&huart2, data, len, 100);         /* Blocking (polling) */
HAL_UART_Transmit_IT(&huart2, data, len);            /* Interrupt (non-blocking) */
HAL_UART_Transmit_DMA(&huart2, data, len);           /* DMA (best for large data) */
```

### 2.2 Ring Buffer Pattern cho RX

```c
/* Nhận liên tục với DMA circular buffer + IDLE line interrupt */
#define RX_BUF_SIZE 256
uint8_t rxBuf[RX_BUF_SIZE];

/* Start DMA receive một lần, circular mode */
HAL_UARTEx_ReceiveToIdle_DMA(&huart2, rxBuf, RX_BUF_SIZE);

/* Callback khi IDLE hoặc half-transfer */
void HAL_UARTEx_RxEventCallback(UART_HandleTypeDef *huart, uint16_t Size) {
  if (huart->Instance == USART2) {
    /* Size = số bytes nhận được trong lần này */
    ProcessReceivedData(rxBuf, Size);
  }
}
```

---

## 3. SPI

### 3.1 Configuration

| Parameter | Options | Notes |
|-----------|---------|-------|
| CPOL | 0 (idle low) / 1 (idle high) | Xem slave device datasheet |
| CPHA | 0 (capture on 1st edge) / 1 (capture on 2nd edge) | |
| Mode 0 | CPOL=0, CPHA=0 | Phổ biến nhất (W25Q Flash, TFT displays) |
| Mode 3 | CPOL=1, CPHA=1 | Một số sensors (BME280 SPI mode) |
| Prescaler | Fclk/2 đến Fclk/256 | Tốc độ SPI ≤ min(slave max, bus capacitance limit) |

### 3.2 CS Management Pattern

```c
/* Software CS (linh hoạt hơn hardware CS) */
#define SPI_CS_LOW()   HAL_GPIO_WritePin(CS_GPIO_Port, CS_Pin, GPIO_PIN_RESET)
#define SPI_CS_HIGH()  HAL_GPIO_WritePin(CS_GPIO_Port, CS_Pin, GPIO_PIN_SET)

uint8_t SPI_ReadRegister(uint8_t reg) {
  uint8_t txBuf[2] = { reg | 0x80, 0xFF }; /* MSB=1 for read (device-specific) */
  uint8_t rxBuf[2] = {0};
  
  SPI_CS_LOW();
  HAL_SPI_TransmitReceive(&hspi1, txBuf, rxBuf, 2, 10);
  SPI_CS_HIGH();
  return rxBuf[1]; /* second byte = register value */
}
```

### 3.3 DMA Transfer cho Large Data

```c
/* SPI DMA cho display hoặc flash (non-blocking) */
HAL_SPI_Transmit_DMA(&hspi1, (uint8_t*)frameBuffer, FRAME_SIZE);

/* Callback khi DMA hoàn thành */
void HAL_SPI_TxCpltCallback(SPI_HandleTypeDef *hspi) {
  if (hspi->Instance == SPI1) {
    SPI_CS_HIGH();
    xSemaphoreGiveFromISR(xSPIDoneSem, &xWoken);
    portYIELD_FROM_ISR(xWoken);
  }
}
```

---

## 4. I2C

### 4.1 Addressing và Timing

```c
/* 7-bit address: shift left 1 bit (HAL dùng 7-bit, tự shift) */
#define BME280_ADDR  (0x76 << 1)  /* SDO = GND → address = 0x76 */

/* Ghi register */
HAL_I2C_Mem_Write(&hi2c1, BME280_ADDR, reg, I2C_MEMADD_SIZE_8BIT, &data, 1, 10);

/* Đọc register */
HAL_I2C_Mem_Read(&hi2c1, BME280_ADDR, reg, I2C_MEMADD_SIZE_8BIT, rxBuf, len, 10);

/* Kiểm tra device có trên bus không */
if (HAL_I2C_IsDeviceReady(&hi2c1, BME280_ADDR, 3, 10) != HAL_OK) {
  Error_Handler(); /* Device không respond */
}
```

### 4.2 I2C Speed Standards

| Mode | Speed | Khi dùng |
|------|-------|---------|
| Standard | 100 kHz | Hầu hết sensors, EEPROMs |
| Fast | 400 kHz | Display controllers (SSD1306), fast sensors |
| Fast-plus | 1 MHz | High-speed DACs, ADCs |

### 4.3 Error Handling

```c
/* I2C errors thường gặp */
HAL_StatusTypeDef status = HAL_I2C_Mem_Read(&hi2c1, addr, reg, ...);
if (status == HAL_BUSY) {
  /* Bus busy — có thể bị stuck, cần reset I2C */
  HAL_I2C_DeInit(&hi2c1);
  HAL_Delay(1);
  HAL_I2C_Init(&hi2c1); /* Software reset I2C peripheral */
}
if (status == HAL_TIMEOUT) {
  /* Device không respond — check hardware connection */
}
```

---

## 5. CAN Bus

### 5.1 Bit Timing Configuration

```
CAN bit time = Sync_Seg (1 Tq) + Prop_Seg + Phase_Seg1 + Phase_Seg2
Baud rate = f_CAN_clock / (prescaler × total_Tq)

Ví dụ: STM32, APB1 = 42 MHz, target = 500 kbps
  prescaler = 6, BS1 = 10 Tq, BS2 = 3 Tq, total = 14 Tq
  Baud = 42,000,000 / (6 × 14) = 500,000 bps ✓
  Sample point = (1 + 10) / 14 = 78.6% (khuyến nghị 75-80%)
```

### 5.2 Filter Configuration

```c
/* Mask filter: chỉ nhận ID 0x100-0x1FF */
CAN_FilterTypeDef sFilterConfig = {
  .FilterIdHigh = 0x100 << 5,       /* ID base */
  .FilterIdLow = 0,
  .FilterMaskIdHigh = 0x700 << 5,   /* Mask: bit 8-10 phải khớp */
  .FilterMaskIdLow = 0,
  .FilterFIFOAssignment = CAN_RX_FIFO0,
  .FilterBank = 0,
  .FilterMode = CAN_FILTERMODE_IDMASK,
  .FilterScale = CAN_FILTERSCALE_32BIT,
  .FilterActivation = ENABLE
};
HAL_CAN_ConfigFilter(&hcan1, &sFilterConfig);
```

### 5.3 Error Handling

```c
/* Kiểm tra CAN error counters */
uint32_t errCode = HAL_CAN_GetError(&hcan1);
if (errCode & HAL_CAN_ERROR_BOF) {
  /* Bus-off: quá nhiều lỗi, auto-recover bằng cách wait 128x11 recessive bits */
  HAL_CAN_Stop(&hcan1);
  HAL_Delay(100);
  HAL_CAN_Start(&hcan1);
}
```

---

## 6. ADC

### 6.1 Modes

| Mode | Dùng khi | DMA cần? |
|------|---------|---------|
| Single conversion | Đọc 1 channel, không liên tục | Không |
| Continuous | Stream data 1 channel | Có (tránh miss samples) |
| Scan (multi-channel) | Đọc nhiều channels tuần tự | Có |
| Discontinuous | Trigger mỗi lần đọc từng batch | Tuỳ |

```c
/* DMA circular buffer cho continuous multi-channel ADC */
#define ADC_CHANNELS 3
uint16_t adcBuf[ADC_CHANNELS]; /* DMA viết vào đây liên tục */

/* Start ADC DMA — chạy một lần, tự reload */
HAL_ADC_Start_DMA(&hadc1, (uint32_t*)adcBuf, ADC_CHANNELS);

/* Callback: được gọi mỗi khi hoàn thành 1 scan cycle */
void HAL_ADC_ConvCpltCallback(ADC_HandleTypeDef *hadc) {
  /* adcBuf[0] = Channel 0, adcBuf[1] = Channel 1, adcBuf[2] = Channel 2 */
  /* Half-transfer callback cũng có: HAL_ADC_ConvHalfCpltCallback */
}
```

### 6.2 Reference Voltage và Accuracy

```
ADC resolution: 12-bit → 4096 steps
Vref = 3.3V → LSB = 3.3V / 4096 = 0.806 mV

Voltage calculation:
  float voltage = (float)adcRaw * 3.3f / 4096.0f;

Oversampling (STM32 hardware): 16x oversampling → 14-bit effective
  uint16_t rawAvg = adcAccumulator >> 2; /* shift 2 bits = divide by 4 cho 2-bit gain */
```

---

## 7. DMA

### 7.1 Transfer Types

| Type | Dùng cho | Direction |
|------|---------|-----------|
| Peripheral → Memory | ADC, UART RX, SPI RX | P2M |
| Memory → Peripheral | UART TX, SPI TX, DAC | M2P |
| Memory → Memory | memcpy acceleration | M2M |

### 7.2 Circular Mode Pattern

```c
/* DMA circular: khi đến cuối buffer → tự quay lại đầu */
/* Dùng Half-Transfer và Transfer-Complete callbacks để double-buffer */

#define BUF_SIZE 256
uint8_t dmaBuf[BUF_SIZE];  /* DMA viết, CPU đọc */

/* Half-Transfer: DMA viết xong nửa đầu (index 0-127) → CPU xử lý nửa đầu */
void HAL_UART_RxHalfCpltCallback(UART_HandleTypeDef *huart) {
  ProcessData(dmaBuf, BUF_SIZE / 2);           /* process first half */
}

/* Transfer-Complete: DMA viết xong nửa sau (index 128-255) → CPU xử lý nửa sau */
void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart) {
  ProcessData(dmaBuf + BUF_SIZE / 2, BUF_SIZE / 2); /* process second half */
}
```

---

## 8. HAL Design Pattern

### 8.1 Abstract Interface (C function pointers)

```c
/* hal_uart.h — abstract interface */
typedef struct {
  bool    (*init)(uint32_t baudRate);
  int     (*transmit)(const uint8_t *data, uint16_t len, uint32_t timeout_ms);
  int     (*receive)(uint8_t *buf, uint16_t len, uint32_t timeout_ms);
  void    (*deinit)(void);
} UartHal_t;

/* Khai báo instance */
extern const UartHal_t g_debugUart;
```

```c
/* hal_uart_stm32.c — platform implementation */
static bool stm32_uart_init(uint32_t baud) {
  huart2.Init.BaudRate = baud;
  return HAL_UART_Init(&huart2) == HAL_OK;
}

static int stm32_uart_transmit(const uint8_t *data, uint16_t len, uint32_t to) {
  return HAL_UART_Transmit(&huart2, (uint8_t*)data, len, to) == HAL_OK ? len : -1;
}

const UartHal_t g_debugUart = {
  .init = stm32_uart_init,
  .transmit = stm32_uart_transmit,
  .receive = stm32_uart_receive,
  .deinit = stm32_uart_deinit
};
```

```c
/* hal_uart_mock.c — mock for unit testing (host) */
static uint8_t mockTxBuf[1024];
static int mockTxIdx = 0;

static int mock_uart_transmit(const uint8_t *data, uint16_t len, uint32_t to) {
  memcpy(mockTxBuf + mockTxIdx, data, len);
  mockTxIdx += len;
  return len; /* always succeeds in test */
}

const UartHal_t g_debugUart = {
  .init = mock_uart_init,
  .transmit = mock_uart_transmit,
  /* ... */
};
```

### 8.2 HAL Usage trong Application

```c
/* application code — chỉ dùng interface, không biết platform */
// REQ-ID: REQ-COMM-001
void Logger_Send(const char *msg) {
  g_debugUart.transmit((const uint8_t*)msg, strlen(msg), 100);
}
```

---

## 9. Driver Testing với Unity + CMock

### 9.1 Directory Structure

```
tests/
├── unity/           ← Unity test framework
├── cmock/           ← CMock (generates mocks from headers)
├── test_sensor.c    ← Unit test file
└── mock_hal_i2c.c   ← Generated mock (từ hal_i2c.h)
```

### 9.2 Test Example

```c
/* test_bme280.c */
#include "unity.h"
#include "mock_hal_i2c.h"  /* CMock generated */
#include "bme280_driver.h"

void setUp(void) { }
void tearDown(void) { }

void test_BME280_ReadTemperature_ReturnsCorrectValue(void) {
  uint8_t rawData[6] = {0x83, 0x42, 0x00, 0x7E, 0xC0, 0x00}; /* pre-calculated raw */
  
  /* CMock expectation: I2C Mem Read sẽ được gọi với args này và trả về rawData */
  HAL_I2C_Mem_Read_ExpectAndReturn(
    &hi2c1, BME280_ADDR, BME280_REG_TEMP_MSB,
    I2C_MEMADD_SIZE_8BIT, NULL, 6, 10, HAL_OK
  );
  HAL_I2C_Mem_Read_ReturnArrayThruPtr_pData(rawData, 6);
  
  float temp = BME280_ReadTemperature();
  TEST_ASSERT_FLOAT_WITHIN(0.1f, 25.3f, temp); /* ±0.1°C tolerance */
}
```

---

## 10. Quick Reference: Peripheral Selection

| Giao tiếp | Speed | Wires | Full-duplex | Multi-device | Khi dùng |
|-----------|-------|-------|:-----------:|:------------:|---------|
| UART | 9600–4M baud | 2 (TX, RX) | ✅ | ❌ (point-to-point) | GPS, debug console, GSM |
| SPI | 1–50 MHz | 4 (MOSI, MISO, SCK, CS) | ✅ | ✅ (1 CS/device) | Flash, display, high-speed DAC/ADC |
| I2C | 100k–1M | 2 (SDA, SCL) | ❌ | ✅ (7-bit addr) | Sensors, EEPROM, OLED |
| CAN | 125k–1M | 2 (CAN_H, CAN_L) | ✅ | ✅ (message-based) | Automotive, industrial multi-node |
| 1-Wire | ~15k | 1 + GND | ❌ | ✅ (unique ROM) | DS18B20 temperature |
