# Success Metrics: Embedded Engineer

> Domain: Firmware & Embedded Systems
> Agent: `embedded-engineer`

## Key Performance Indicators

| Chỉ số | Mục tiêu | Đo lường |
|--------|----------|----------|
| ISR execution time | < 10 µs cho GPIO/UART ISR | Xcode Instruments / oscilloscope |
| RTOS task response time | < 1ms cho critical tasks | RTOS trace / logic analyzer |
| Flash/RAM usage | < 80% capacity (headroom cho updates) | `arm-none-eabi-size` output |
| Unit test coverage (HAL mock) | > 80% logic paths | Unity/CMock coverage report |
| Power consumption | Đạt target specification ±10% | Power profiler / current measurement |

## Quality Gates

- [ ] All firmware files contain REQ-ID reference
- [ ] HAL interface designed before implementation (enables mock testing)
- [ ] Flash/RAM usage validated after each major feature
- [ ] Watchdog timer configured for production firmware
- [ ] MISRA-C compliance checked for safety-critical code

## Definition of Done

1. Code compiles without warnings with `-Wall -Wextra -Werror`
2. Unit tests pass with mocked HAL layer
3. Integration tests pass on target hardware or simulator
4. Power budget validated with profiler
5. Documentation updated (datasheet references, timing diagrams)
