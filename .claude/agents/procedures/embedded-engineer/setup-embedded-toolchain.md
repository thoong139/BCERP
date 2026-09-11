# Playbook: Setup Embedded Toolchain

> **Type**: Agent Skill Playbook
> **Agent**: embedded-engineer
> **Triggered by**: Khi cần setup môi trường phát triển embedded từ đầu
> **Output**: CMakeLists.txt, platformio.ini, debug config, CI/CD workflow

---

## Khi nào dùng playbook này

- Khởi tạo project firmware mới
- Onboard developer mới vào embedded project
- Migrate từ IDE (STM32CubeIDE, ArduinoIDE) sang CMake/PlatformIO + VSCode
- Setup CI/CD cho firmware build và test

---

## Pre-conditions

```
□ Xác định MCU target (STM32F4, ESP32-S3, RP2040, nRF52...)
□ Xác định build system preference (CMake hoặc PlatformIO)
□ Xác định debug probe có sẵn (ST-LINK, J-Link, ESP-Prog, Pico probe)
□ Xác định CI/CD platform (GitHub Actions, GitLab CI, Jenkins)
```

---

## Procedure

### Bước 1: CMake Setup cho ARM MCU

```
Cài đặt toolchain:
  Windows: arm-none-eabi-gcc từ developer.arm.com hoặc winget install arm-none-eabi-gcc
  Linux:   sudo apt-get install gcc-arm-none-eabi binutils-arm-none-eabi
  macOS:   brew install --cask gcc-arm-embedded

Cài OpenOCD:
  Windows: winget install openocd hoặc từ openocd.org
  Linux:   sudo apt-get install openocd
```

**CMakeLists.txt cho STM32:**

```cmake
cmake_minimum_required(VERSION 3.22)

# Toolchain file phải được set TRƯỚC project()
set(CMAKE_TOOLCHAIN_FILE ${CMAKE_SOURCE_DIR}/cmake/arm-none-eabi-gcc.cmake)

project(MyFirmware C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# MCU flags
set(MCU_FLAGS "-mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard")
set(CMAKE_C_FLAGS "${MCU_FLAGS} -Wall -Wextra -fdata-sections -ffunction-sections")
set(CMAKE_EXE_LINKER_FLAGS "${MCU_FLAGS} -T${CMAKE_SOURCE_DIR}/STM32F407VGTx_FLASH.ld \
  -Wl,--gc-sections -Wl,-Map=${PROJECT_NAME}.map")

# Sources
file(GLOB_RECURSE SOURCES
  "src/*.c" "src/*.cpp"
  "Drivers/STM32F4xx_HAL_Driver/Src/*.c"
  "Middlewares/Third_Party/FreeRTOS/Source/*.c"
  "startup_stm32f407xx.s"
)

add_executable(${PROJECT_NAME}.elf ${SOURCES})

target_include_directories(${PROJECT_NAME}.elf PRIVATE
  src/ include/
  Drivers/STM32F4xx_HAL_Driver/Inc
  Drivers/CMSIS/Device/ST/STM32F4xx/Include
  Drivers/CMSIS/Include
  Middlewares/Third_Party/FreeRTOS/Source/include
  Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM4F
)

target_compile_definitions(${PROJECT_NAME}.elf PRIVATE
  USE_HAL_DRIVER STM32F407xx
)

# Post-build: generate .bin và .hex
add_custom_command(TARGET ${PROJECT_NAME}.elf POST_BUILD
  COMMAND arm-none-eabi-objcopy -O binary ${PROJECT_NAME}.elf ${PROJECT_NAME}.bin
  COMMAND arm-none-eabi-objcopy -O ihex   ${PROJECT_NAME}.elf ${PROJECT_NAME}.hex
  COMMAND arm-none-eabi-size ${PROJECT_NAME}.elf
)
```

**cmake/arm-none-eabi-gcc.cmake (Toolchain file):**

```cmake
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR ARM)

set(TOOLCHAIN_PREFIX arm-none-eabi-)
set(CMAKE_C_COMPILER   ${TOOLCHAIN_PREFIX}gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_PREFIX}g++)
set(CMAKE_ASM_COMPILER ${TOOLCHAIN_PREFIX}gcc)
set(CMAKE_OBJCOPY      ${TOOLCHAIN_PREFIX}objcopy)
set(CMAKE_SIZE         ${TOOLCHAIN_PREFIX}size)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
```

**Build commands:**

```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Debug
cmake --build . -- -j$(nproc)
```

---

### Bước 2: PlatformIO Setup

```
Cài đặt: pip install platformio
         hoặc VSCode extension: PlatformIO IDE
```

**platformio.ini:**

```ini
[platformio]
default_envs = stm32f4

[env:stm32f4]
platform = ststm32
board = disco_f407vg
framework = stm32cube
lib_deps =
  stm32f4hal
  freertos
upload_protocol = stlink
debug_tool = stlink
debug_build_flags = -Og -g3
build_flags =
  -DUSE_HAL_DRIVER
  -DSTM32F407xx
  -I include/
monitor_speed = 115200

[env:esp32s3]
platform = espressif32
board = esp32-s3-devkitc-1
framework = espidf
upload_protocol = esptool
monitor_speed = 115200
board_build.mcu = esp32s3
board_build.f_cpu = 240000000L

[env:native_test]
; Host-side unit tests (không cần hardware)
platform = native
build_flags =
  -DUNIT_TEST
  -I include/
  -I test/mocks/
test_build_src = yes
```

**Build và Flash:**

```bash
pio run                    # Build
pio run --target upload    # Flash
pio device monitor         # Serial monitor
pio test -e native_test    # Unit tests (host)
```

---

### Bước 3: Debug Setup với VSCode

**launch.json (STM32 với ST-LINK):**

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "STM32 Debug (OpenOCD)",
      "type": "cortex-debug",
      "request": "launch",
      "servertype": "openocd",
      "configFiles": [
        "interface/stlink.cfg",
        "target/stm32f4x.cfg"
      ],
      "executable": "${workspaceFolder}/build/${workspaceFolderBasename}.elf",
      "svdFile": "${workspaceFolder}/STM32F407.svd",
      "runToEntryPoint": "main",
      "preLaunchTask": "build"
    },
    {
      "name": "ESP32 Debug (OpenOCD)",
      "type": "cortex-debug",
      "request": "launch",
      "servertype": "openocd",
      "configFiles": [
        "board/esp32s3-builtin.cfg"
      ],
      "executable": "${workspaceFolder}/build/${workspaceFolderBasename}.elf",
      "runToEntryPoint": "app_main"
    }
  ]
}
```

**Cài VSCode extensions:**

```
cortex-debug          ← ARM Cortex-M GDB debug
ms-vscode.cpptools    ← C/C++ IntelliSense
ms-vscode.cmake-tools ← CMake integration
platformio.platformio-ide ← Nếu dùng PlatformIO
```

---

### Bước 4: ESP-IDF Project Structure

```bash
# Tạo project mới
idf.py create-project my_project
cd my_project

# Project structure:
# my_project/
# ├── CMakeLists.txt         ← IDF project root CMake
# ├── main/
# │   ├── CMakeLists.txt     ← main component
# │   └── main.c
# ├── components/            ← custom components
# │   └── my_driver/
# │       ├── CMakeLists.txt
# │       ├── include/my_driver.h
# │       └── my_driver.c
# └── sdkconfig              ← Kconfig settings (after menuconfig)

# Configure (menuconfig UI)
idf.py menuconfig

# Build + Flash + Monitor
idf.py build
idf.py -p /dev/ttyUSB0 flash
idf.py -p /dev/ttyUSB0 monitor
idf.py -p /dev/ttyUSB0 flash monitor  # all in one
```

---

### Bước 5: Testing Infrastructure (Unity + CMock)

```
Project structure cho tests:
  tests/
  ├── unity/           ← Unity (download từ github.com/ThrowTheSwitch/Unity)
  ├── cmock/           ← CMock (github.com/ThrowTheSwitch/CMock)
  ├── test_runner.c    ← Generated test runner (hoặc Unity test_main)
  ├── test_sensor.c    ← Test file
  └── mocks/           ← CMock generated mocks
      └── mock_hal_i2c.c
```

**CMakeLists.txt cho host tests:**

```cmake
# Separate target cho host-side unit tests
if(UNIT_TEST)
  add_executable(test_runner
    tests/test_sensor.c
    tests/mocks/mock_hal_i2c.c
    tests/unity/src/unity.c
    src/drivers/sensor.c   # Actual code under test (NOT hardware files)
  )
  target_include_directories(test_runner PRIVATE
    tests/unity/src
    tests/cmock/src
    tests/mocks
    include/
  )
  target_compile_definitions(test_runner PRIVATE UNIT_TEST)
  add_test(NAME unit_tests COMMAND test_runner)
endif()
```

**Generate mock từ header:**

```bash
ruby cmock/lib/cmock.rb --mock_path=tests/mocks include/hal/hal_i2c.h
# Tạo: tests/mocks/mock_hal_i2c.h + mock_hal_i2c.c
```

**Run tests:**

```bash
mkdir build_test && cd build_test
cmake .. -DUNIT_TEST=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build .
ctest --output-on-failure
# Hoặc: ./test_runner (trực tiếp)
```

---

### Bước 6: CI/CD cho Firmware

**GitHub Actions (.github/workflows/firmware-ci.yml):**

```yaml
name: Firmware CI

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: sudo apt-get install -y cmake gcc ruby
      - name: Generate CMock mocks
        run: ruby cmock/lib/cmock.rb --mock_path=tests/mocks include/hal/*.h
      - name: Build and run unit tests
        run: |
          mkdir build && cd build
          cmake .. -DUNIT_TEST=ON -DCMAKE_BUILD_TYPE=Debug
          cmake --build .
          ctest --output-on-failure

  build-stm32:
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - uses: actions/checkout@v4
      - name: Install ARM toolchain
        run: |
          sudo apt-get install -y gcc-arm-none-eabi binutils-arm-none-eabi
      - name: Build firmware
        run: |
          mkdir build && cd build
          cmake .. -DCMAKE_BUILD_TYPE=Release
          cmake --build .
      - name: Check firmware size
        run: arm-none-eabi-size build/firmware.elf
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: firmware
          path: build/firmware.bin

  build-esp32:
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - uses: actions/checkout@v4
      - name: Install ESP-IDF
        uses: espressif/esp-idf-ci-action@v1
        with:
          esp_idf_version: v5.2
          target: esp32s3
          command: idf.py build
```

---

## Output

```
Files tạo trong project:
  CMakeLists.txt                              ← Build system
  cmake/arm-none-eabi-gcc.cmake              ← Toolchain file (ARM)
  platformio.ini                             ← PlatformIO config (thay thế CMake)
  .vscode/launch.json                        ← Debug config
  .vscode/tasks.json                         ← Build tasks
  .github/workflows/firmware-ci.yml         ← CI/CD
  tests/CMakeLists.txt                       ← Test build
  README.md (build section)                  ← Instructions
```

---

## Checklist

```
□ Toolchain installed và verify: arm-none-eabi-gcc --version
□ Build succeeds: cmake --build . không có errors/warnings
□ Flash succeeds: firmware chạy trên board
□ Debug: breakpoints work trong VSCode
□ Unit tests: ctest tất cả pass trên host
□ CI: GitHub Actions build và test pass trên push
□ arm-none-eabi-size output documented (Flash/RAM baseline)
```
