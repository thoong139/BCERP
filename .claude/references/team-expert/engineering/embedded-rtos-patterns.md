# Embedded Systems - RTOS Patterns & Bare-Metal Architecture

> **Domain**: Embedded Systems / Kỹ thuật Nhúng
> **Last Updated**: 2026-04-13
> **Nguồn**: FreeRTOS Documentation (freertos.org), Zephyr Project Docs, Barr Group Embedded C Coding Standard

---

## 1. FreeRTOS Core Concepts

### 1.1 Task Creation và Management

```c
/* Tạo task cơ bản */
BaseType_t xTaskCreate(
  TaskFunction_t  pvTaskCode,     /* Hàm task */
  const char*     pcName,         /* Tên để debug */
  configSTACK_DEPTH_TYPE usStackDepth, /* Stack size (words, không phải bytes) */
  void*           pvParameters,   /* Tham số truyền vào task */
  UBaseType_t     uxPriority,     /* Priority: 0 = thấp nhất, configMAX_PRIORITIES-1 = cao nhất */
  TaskHandle_t*   pxCreatedTask   /* Handle để control task sau */
);

/* Ví dụ thực tế */
xTaskCreate(
  vSensorTask,          /* function */
  "SENSOR",             /* name (max configMAX_TASK_NAME_LEN) */
  256,                  /* stack depth in words = 1024 bytes on 32-bit MCU */
  NULL,                 /* no params */
  tskIDLE_PRIORITY + 2, /* priority */
  &xSensorTaskHandle
);
```

### 1.2 Task Priority Guidelines

| Priority Level | configMAX_PRIORITIES = 7 | Dùng cho |
|---------------|--------------------------|---------|
| 6 (Highest) | Critical real-time | Motor control ISR deferred handler, safety watchdog |
| 5 | High | Communications (CAN/UART critical) |
| 4 | Normal-high | Sensor acquisition |
| 3 | Normal | Application logic, state machine |
| 2 | Low | Data logging, display update |
| 1 | Background | LED blink, diagnostics |
| 0 | Idle | tskIDLE_PRIORITY — chỉ chạy khi không task nào run |

### 1.3 Task States

```
RUNNING → BLOCKED (đang chờ: semaphore, queue, delay)
RUNNING → READY (preempted bởi higher priority task)
READY   → RUNNING (scheduler chọn)
BLOCKED → READY (event xảy ra, timeout hết)
Bất kỳ → SUSPENDED (vTaskSuspend — không còn scheduled)
```

---

## 2. Synchronization Primitives

### 2.1 Queue

```c
/* Tạo queue giữ 10 phần tử kiểu SensorData_t */
QueueHandle_t xSensorQueue = xQueueCreate(10, sizeof(SensorData_t));

/* Gửi từ task (COPY by value) */
SensorData_t data = { .temp = 25.3f, .timestamp = xTaskGetTickCount() };
xQueueSend(xSensorQueue, &data, pdMS_TO_TICKS(10)); /* timeout 10ms */

/* Gửi từ ISR */
BaseType_t xHigherPriorityTaskWoken = pdFALSE;
xQueueSendFromISR(xSensorQueue, &data, &xHigherPriorityTaskWoken);
portYIELD_FROM_ISR(xHigherPriorityTaskWoken); /* yield nếu cần */

/* Nhận */
SensorData_t rxData;
if (xQueueReceive(xSensorQueue, &rxData, portMAX_DELAY) == pdPASS) {
  // process rxData
}
```

**Pattern chuẩn**: ISR nhận raw data → push vào queue → task xử lý logic nặng.

### 2.2 Semaphore

```c
/* Binary semaphore — signaling giữa ISR và task */
SemaphoreHandle_t xSem = xSemaphoreCreateBinary();

/* ISR give */
xSemaphoreGiveFromISR(xSem, &xHigherPriorityTaskWoken);

/* Task wait */
xSemaphoreTake(xSem, portMAX_DELAY);

/* Counting semaphore — resource pool (vd: 3 ADC channels) */
SemaphoreHandle_t xADCPool = xSemaphoreCreateCounting(3, 3);
xSemaphoreTake(xADCPool, pdMS_TO_TICKS(50)); /* acquire */
/* ... use ADC ... */
xSemaphoreGive(xADCPool);                    /* release */
```

### 2.3 Mutex (Priority Inheritance)

```c
/* Mutex cho shared resource — CÓ priority inheritance */
MutexHandle_t xI2CMutex = xSemaphoreCreateMutex();

/* Usage pattern */
if (xSemaphoreTake(xI2CMutex, pdMS_TO_TICKS(100)) == pdPASS) {
  // critical section — I2C access
  I2C_Write(device_addr, reg, data);
  xSemaphoreGive(xI2CMutex);
}

/* KHÔNG dùng mutex trong ISR — dùng semaphore thay vào */
```

**Priority Inheritance**: Khi low-priority task giữ mutex, nếu high-priority task chờ mutex → FreeRTOS tạm thời nâng priority của low-priority task = priority của người chờ cao nhất.

### 2.4 Event Group

```c
/* Bit flags cho nhiều events */
EventGroupHandle_t xSystemEvents = xEventGroupCreate();
#define EVT_WIFI_CONNECTED   (1 << 0)
#define EVT_MQTT_CONNECTED   (1 << 1)
#define EVT_DATA_READY       (1 << 2)

/* Set bit từ bất kỳ context */
xEventGroupSetBits(xSystemEvents, EVT_WIFI_CONNECTED);

/* Chờ TẤT CẢ bits set */
xEventGroupWaitBits(
  xSystemEvents,
  EVT_WIFI_CONNECTED | EVT_MQTT_CONNECTED, /* bits cần wait */
  pdTRUE,  /* clear bits sau khi đọc */
  pdTRUE,  /* wait for ALL (pdFALSE = wait for ANY) */
  portMAX_DELAY
);
```

---

## 3. Memory Management

### 3.1 FreeRTOS Heap Schemes

| Scheme | Tính năng | Khi dùng |
|--------|-----------|---------|
| heap_1 | Chỉ allocate, không free | Static-only system, maximum determinism |
| heap_2 | Allocate + free (không merge) | Blocks cùng size, ít fragmentation risk |
| heap_3 | Wrapper cho malloc/free (thread-safe) | Dùng libc malloc, flexibility |
| heap_4 | Allocate + free + merge adjacent blocks | **Recommended cho hầu hết dự án** |
| heap_5 | heap_4 nhưng span nhiều vùng nhớ (vd: SRAM + CCMRAM) | MCU có nhiều memory regions |

### 3.2 Stack Overflow Detection

```c
/* Trong FreeRTOSConfig.h */
#define configCHECK_FOR_STACK_OVERFLOW  2  /* Method 2: check pattern (chậm hơn nhưng đáng tin hơn) */

/* Implement hook */
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
  /* Không return — system halt */
  configASSERT(0);
  /* Hoặc: log to flash, trigger watchdog */
}
```

### 3.3 Kiểm tra Stack Usage

```c
/* Runtime check — gọi từ monitoring task */
UBaseType_t uxHighWaterMark = uxTaskGetStackHighWaterMark(xSensorTaskHandle);
/* uxHighWaterMark = số words còn lại (chưa dùng) tại điểm sử dụng nhiều nhất */
/* Nếu = 0: overflow đã xảy ra */
/* Nếu < 20: cần tăng stack size */
```

---

## 4. Software Timer

```c
/* Software timer — chạy trong Timer Daemon Task (không phải ISR) */
TimerHandle_t xLEDTimer = xTimerCreate(
  "LED_BLINK",
  pdMS_TO_TICKS(500),  /* period: 500ms */
  pdTRUE,              /* auto-reload */
  (void*)0,            /* timer ID */
  vLEDTimerCallback    /* callback */
);
xTimerStart(xLEDTimer, 0);

void vLEDTimerCallback(TimerHandle_t xTimer) {
  /* Chạy trong context của Timer Daemon Task */
  /* Không blocking, không delay */
  HAL_GPIO_TogglePin(LED_GPIO_Port, LED_Pin);
}
```

**Lưu ý**: Software timer callback KHÔNG nên dùng `vTaskDelay()` — sẽ block Timer Daemon và ảnh hưởng mọi timer khác.

---

## 5. Bare-Metal Patterns

### 5.1 Super Loop Pattern

```c
/* Đơn giản nhất — không RTOS */
int main(void) {
  SystemInit();
  HAL_Init();
  Peripheral_Init();
  
  while (1) {
    ReadSensors();
    ProcessData();
    UpdateOutputs();
    CheckCommunications();
    /* Không delay ở đây — toàn bộ phải non-blocking */
  }
}
```

**Giới hạn**: Không có timing guarantees, khó xử lý concurrent tasks có timing khác nhau.

### 5.2 Interrupt-Driven State Machine

```c
typedef enum {
  STATE_IDLE,
  STATE_MEASURING,
  STATE_TRANSMITTING,
  STATE_ERROR
} SystemState_t;

volatile SystemState_t eSystemState = STATE_IDLE;
volatile bool bMeasureComplete = false;

/* ISR: chỉ set flag */
void ADC_IRQHandler(void) {
  adcValue = ADC->DR;
  bMeasureComplete = true;
}

/* Main loop: xử lý state transitions */
while (1) {
  switch (eSystemState) {
    case STATE_IDLE:
      if (bMeasureComplete) {
        bMeasureComplete = false; /* phải atomic — dùng __disable_irq nếu cần */
        eSystemState = STATE_MEASURING;
      }
      break;
    case STATE_MEASURING:
      ProcessADC(adcValue);
      eSystemState = STATE_TRANSMITTING;
      break;
    /* ... */
  }
}
```

---

## 6. Zephyr RTOS Basics

### 6.1 Project Structure

```
my_app/
├── CMakeLists.txt
├── prj.conf          ← Kconfig: CONFIG_UART=y, CONFIG_LOG=y
├── app.overlay       ← Device tree overlay (pin assignments, peripherals)
└── src/main.c
```

### 6.2 Device Tree Binding

```dts
/* app.overlay — thêm LED vào board */
/ {
  leds {
    compatible = "gpio-leds";
    user_led: led_0 {
      gpios = <&gpioa 5 GPIO_ACTIVE_HIGH>;
      label = "User LED";
    };
  };
};
```

```c
/* Dùng DT_ALIAS trong code */
#include <zephyr/drivers/gpio.h>
static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(DT_ALIAS(led0), gpios);

void main(void) {
  gpio_pin_configure_dt(&led, GPIO_OUTPUT_ACTIVE);
  gpio_pin_toggle_dt(&led);
}
```

### 6.3 Zephyr Kernel Objects

```c
/* Thread (tương đương FreeRTOS task) */
K_THREAD_DEFINE(sensor_tid, 1024, sensor_thread, NULL, NULL, NULL, 5, 0, 0);

/* Message Queue */
K_MSGQ_DEFINE(sensor_queue, sizeof(SensorData_t), 10, 4);
k_msgq_put(&sensor_queue, &data, K_MSEC(10));
k_msgq_get(&sensor_queue, &rxData, K_FOREVER);

/* Mutex */
K_MUTEX_DEFINE(i2c_mutex);
k_mutex_lock(&i2c_mutex, K_FOREVER);
k_mutex_unlock(&i2c_mutex);
```

---

## 7. Common Pitfalls

### 7.1 ISR Calling Non-ISR-Safe API

```c
/* ❌ SAI — xQueueSend trong ISR sẽ crash */
void UART_IRQHandler(void) {
  xQueueSend(xQueue, &data, 0); /* WRONG! Blocking version không safe trong ISR */
}

/* ✅ ĐÚNG — dùng FromISR variant */
void UART_IRQHandler(void) {
  BaseType_t xWoken = pdFALSE;
  xQueueSendFromISR(xQueue, &data, &xWoken);
  portYIELD_FROM_ISR(xWoken);
}
```

### 7.2 Priority Inversion (không dùng mutex)

```c
/* ❌ Dùng binary semaphore cho mutual exclusion */
/* Không có priority inheritance → high-prio task có thể bị block lâu */
SemaphoreHandle_t xSem = xSemaphoreCreateBinary();
xSemaphoreGive(xSem); /* init as available */

/* ✅ Dùng mutex cho shared resource */
MutexHandle_t xMutex = xSemaphoreCreateMutex();
/* FreeRTOS mutex có built-in priority inheritance */
```

### 7.3 Deadlock Detection

Deadlock xảy ra khi:
1. Task A giữ Mutex1, chờ Mutex2
2. Task B giữ Mutex2, chờ Mutex1

**Phòng tránh**: Luôn lock mutexes theo thứ tự cố định (luôn lock Mutex1 trước Mutex2).

### 7.4 Volatile và Memory Barriers

```c
/* Shared data giữa ISR và task PHẢI volatile */
volatile bool g_buttonPressed = false;
volatile uint32_t g_adcValue = 0;

/* Trên Cortex-M: đủ với volatile cho single-word access */
/* Với multi-byte struct: cần critical section */
taskENTER_CRITICAL();
memcpy(&localCopy, &g_sharedStruct, sizeof(SharedStruct_t));
taskEXIT_CRITICAL();
```

---

## 8. Quick Reference: FreeRTOS API Cheat Sheet

| Tình huống | API (từ Task) | API (từ ISR) |
|-----------|--------------|-------------|
| Gửi queue | `xQueueSend()` | `xQueueSendFromISR()` |
| Nhận queue | `xQueueReceive()` | `xQueueReceiveFromISR()` |
| Give semaphore | `xSemaphoreGive()` | `xSemaphoreGiveFromISR()` |
| Take semaphore | `xSemaphoreTake()` | `xSemaphoreTakeFromISR()` |
| Set event bits | `xEventGroupSetBits()` | `xEventGroupSetBitsFromISR()` |
| Delay | `vTaskDelay(pdMS_TO_TICKS(n))` | ❌ không delay từ ISR |
| Get tick count | `xTaskGetTickCount()` | `xTaskGetTickCountFromISR()` |
