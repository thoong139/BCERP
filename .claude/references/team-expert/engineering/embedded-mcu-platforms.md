# Embedded Systems - MCU Platforms & Hardware Fundamentals

> **Domain**: Embedded Systems / Kỹ thuật Nhúng
> **Last Updated**: 2026-04-13
> **Nguồn**: ARM Cortex-M Technical Reference, Espressif ESP-IDF Docs, Raspberry Pi RP2040 Datasheet, Nordic nRF52 Series Docs

---

## 1. So sánh MCU Platforms

### 1.1 Bảng so sánh tổng quan

| Platform | CPU Core | Clock Max | Flash | RAM | FPU | Price Range | Power (Active) |
|----------|---------|-----------|-------|-----|-----|-------------|----------------|
| STM32F4 | Cortex-M4 | 168 MHz | 1 MB | 192 KB | ✅ | $3–8 | 100 mA |
| STM32H7 | Cortex-M7 | 480 MHz | 2 MB | 1 MB | ✅ | $8–20 | 200 mA |
| STM32L4 | Cortex-M4 | 80 MHz | 1 MB | 256 KB | ✅ | $3–7 | 10 mA |
| ESP32-S3 | Xtensa LX7 (dual) | 240 MHz | 8 MB | 512 KB | ✅ | $2–5 | 240 mA |
| ESP32-C3 | RISC-V | 160 MHz | 4 MB | 400 KB | ❌ | $1–3 | 200 mA |
| RP2040 | Cortex-M0+ (dual) | 133 MHz | External | 264 KB | ❌ | $1 | 80 mA |
| ATmega328P | AVR 8-bit | 20 MHz | 32 KB | 2 KB | ❌ | $1–3 | 15 mA |
| nRF52840 | Cortex-M4 | 64 MHz | 1 MB | 256 KB | ✅ | $5–10 | 6 mA |
| nRF52832 | Cortex-M4 | 64 MHz | 512 KB | 64 KB | ✅ | $3–6 | 5.5 mA |

### 1.2 Chip Selection Guide theo Use Case

| Use Case | Khuyến nghị | Lý do |
|----------|-------------|-------|
| Industrial control, motor drive | STM32F4/H7 | FPU, nhiều timers (TIM1/8 advanced), CAN Bus, DMA mạnh |
| Low-power sensor node (coin cell) | STM32L4, nRF52832 | Stop mode < 2 µA, RTC wakeup |
| IoT WiFi + BLE | ESP32-S3 | Tích hợp WiFi/BLE, dual-core, 8MB Flash, AI accelerator |
| BLE-only wearable | nRF52840 | BLE 5.3, USB, 256KB RAM, Ultra-low power |
| Maker/education | RP2040 | Rẻ, PIO (Programmable I/O) linh hoạt, Arduino + MicroPython |
| Arduino ecosystem | ATmega328P | Ecosystem rộng, simple toolchain, không cần RTOS |
| Medical device | STM32L4 + nRF52 | IEC 62304 toolchain support, low power, HAL certified |
| Matter/Thread smart home | nRF52840, ESP32-H2 | Native Thread stack, Matter SDK support |

---

## 2. Memory Map Fundamentals

### 2.1 Cortex-M Memory Map (chuẩn ARM)

```
Address Range    | Region              | Typical Use
0x00000000–0x1FFFFFFF | Code            | Flash (execute-in-place)
0x20000000–0x3FFFFFFF | SRAM            | Stack, heap, global vars
0x40000000–0x5FFFFFFF | Peripheral      | APB/AHB peripheral registers
0x60000000–0x7FFFFFFF | External RAM    | SDRAM, PSRAM (nếu có)
0xE0000000–0xE00FFFFF | System          | SysTick, NVIC, SCB, ITM
```

### 2.2 STM32F4 Cụ thể

```
0x08000000  Flash (512KB–2MB) — vector table + code + const data
0x20000000  SRAM1 (112KB)     — stack, heap, .data, .bss
0x2001C000  SRAM2 (16KB)      — có thể backup power
0x10000000  CCMRAM (64KB)     — chỉ CPU access, tốc độ cao nhất, thích hợp cho stack RTOS
```

### 2.3 ESP32-S3 Cụ thể

```
0x3FC80000  Internal SRAM (512KB) — DRAM, .data, .bss, heap
0x40374000  IRAM (512KB)          — executable from RAM (interrupt handlers)
0x3C000000  Flash (mapped)        — code, rodata (DROM/IROM)
```

---

## 3. Boot Sequence

### 3.1 Cortex-M Boot Sequence

```
Power-On Reset
    ↓
Bootloader (optional, tùy config BOOT0/BOOT1 pins)
    ↓
Vector Table Load: SP = vector[0], PC = vector[1] (Reset_Handler)
    ↓
Reset_Handler (startup_stm32xxx.s)
    ├── Copy .data từ Flash → SRAM
    ├── Zero-fill .bss
    ├── Call SystemInit() → PLL/clock setup
    └── Call main()
    ↓
main()
    ├── HAL_Init()
    ├── SystemClock_Config()
    ├── Peripheral Init (GPIO, UART, SPI...)
    └── RTOS Scheduler Start / Super Loop
```

### 3.2 ESP32 Boot Sequence

```
Power-On Reset
    ↓
1st stage bootloader (ROM, không sửa được)
    ├── Load 2nd stage bootloader từ Flash offset 0x1000
    └── Verify SHA-256 nếu secure boot enabled
    ↓
2nd stage bootloader (esp-idf)
    ├── OTA partition selection
    ├── Flash decryption (nếu enabled)
    └── Load app từ active OTA partition
    ↓
app_main() (FreeRTOS task)
```

---

## 4. Linker Script Anatomy

### 4.1 GNU LD Script cơ bản (STM32)

```ld
MEMORY {
  FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 512K
  RAM   (xrw) : ORIGIN = 0x20000000, LENGTH = 128K
  CCMRAM (xrw): ORIGIN = 0x10000000, LENGTH = 64K
}

SECTIONS {
  .isr_vector : { *(.isr_vector) } >FLASH    /* Vector table đầu tiên */
  .text       : { *(.text*) }     >FLASH    /* Code */
  .rodata     : { *(.rodata*) }   >FLASH    /* Const data */
  .data       : {                           /* Initialized global vars */
    _sdata = .;
    *(.data*)
    _edata = .;
  } >RAM AT> FLASH                          /* Load từ Flash, run trong RAM */
  .bss        : {                           /* Zero-initialized vars */
    _sbss = .;
    *(.bss*)
    _ebss = .;
  } >RAM
  ._stack     : {
    . = ALIGN(8);
    . = . + _Min_Stack_Size;
  } >RAM
}
```

### 4.2 Sections quan trọng

| Section | Nội dung | Vị trí |
|---------|----------|--------|
| `.text` | Machine code | Flash |
| `.rodata` | String literals, const arrays | Flash |
| `.data` | Initialized global/static vars | Flash (load) → RAM (run) |
| `.bss` | Uninitialized global/static vars (zero-fill) | RAM only |
| `.stack` | Main stack (Cortex-M dùng full descending stack) | RAM |
| `.heap` | Dynamic allocation (malloc/new) | RAM |
| `CCMRAM` (STM32) | Critical data, FreeRTOS TCB, stack | CCMRAM |

---

## 5. Debugging Interfaces

### 5.1 JTAG vs SWD

| Thuộc tính | JTAG | SWD (Serial Wire Debug) |
|------------|------|------------------------|
| Số pins | 4–5 (TCK, TMS, TDI, TDO, TRST) | 2 (SWCLK, SWDIO) |
| Daisy chain | ✅ nhiều chip | ❌ |
| Tốc độ | Thấp hơn SWD | Cao hơn (4–8 MHz) |
| STM32 default | JTAG | SWD (ưu tiên — ít pins hơn) |

### 5.2 Debug Probes phổ biến

| Probe | Interface | Chip target | Đặc điểm |
|-------|-----------|-------------|----------|
| ST-LINK V3 | SWD/JTAG | STM32 | Có sẵn trên Nucleo/Discovery, hỗ trợ VCP |
| J-Link (Segger) | SWD/JTAG | Hầu hết ARM | Real-time trace (ETM), commercial |
| CMSIS-DAP (DAPLink) | SWD/JTAG | ARM Cortex | Open-source, USB HID |
| ESP-Prog | JTAG | ESP32 | Espressif official, tích hợp USB-UART |
| Raspberry Pi Pico | SWD | RP2040 + ARM | Dùng làm probe với PicoProbe firmware |

### 5.3 OpenOCD Command Examples

```bash
# Flash STM32 via ST-LINK
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg \
  -c "program firmware.elf verify reset exit"

# GDB attach
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg &
arm-none-eabi-gdb -ex "target remote :3333" firmware.elf
```

---

## 6. Flash/RAM Usage Analysis

```bash
# Xem kích thước các sections
arm-none-eabi-size --format=berkeley build/firmware.elf

# Output:
#    text    data     bss     dec     hex filename
#   45123    1024    8192   54339    d443 firmware.elf
# text = Flash used, data = RAM used (init), bss = RAM used (zero), dec = total

# Chi tiết từng symbol
arm-none-eabi-nm --print-size --size-sort build/firmware.elf | tail -20
```

---

## 7. Quick Reference: Platform Selection Matrix

| Criteria | STM32F4 | ESP32-S3 | RP2040 | nRF52840 | ATmega |
|----------|:-------:|:--------:|:------:|:--------:|:------:|
| WiFi | ❌ | ✅ | ❌ | ❌ | ❌ |
| BLE | ❌ | ✅ | ❌ | ✅ | ❌ |
| FPU | ✅ | ✅ | ❌ | ✅ | ❌ |
| Low power (<10µA) | ✅ (L4) | ❌ | ❌ | ✅ | ✅ |
| USB native | ✅ | ✅ | ✅ | ✅ | ❌ |
| CAN Bus | ✅ | ❌ | ❌ | ❌ | ❌ |
| Arduino ecosystem | ⚠ | ✅ | ✅ | ⚠ | ✅ |
| MISRA-C toolchain | ✅ | ❌ | ⚠ | ✅ | ❌ |
| Price (single unit) | $3–20 | $2–5 | $1 | $5–10 | $1–3 |
