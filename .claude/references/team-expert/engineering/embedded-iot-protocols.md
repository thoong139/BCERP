# Embedded Systems - IoT Protocols & Connectivity

> **Domain**: Embedded Systems / Kỹ thuật Nhúng
> **Last Updated**: 2026-04-13
> **Nguồn**: ESP-IDF Programming Guide, MQTT 5.0 Specification, Bluetooth SIG GATT Spec, LoRa Alliance Spec, Matter SDK Docs

---

## 1. MQTT

### 1.1 Core Concepts

| Khái niệm | Mô tả |
|-----------|-------|
| **Broker** | Server trung gian (Mosquitto, EMQX, HiveMQ, AWS IoT Core) |
| **Topic** | String phân cấp: `sensors/room1/temperature` |
| **QoS 0** | At most once (fire and forget, không ACK) |
| **QoS 1** | At least once (ACK từ broker, có thể duplicate) |
| **QoS 2** | Exactly once (4-way handshake, guaranteed no duplicate) |
| **Retain** | Broker lưu message cuối cùng, subscriber mới nhận ngay khi subscribe |
| **Last Will** | Message tự động publish khi client mất kết nối đột ngột |
| **Clean Session** | `true`: discard subscriptions + queued messages khi reconnect |

### 1.2 ESP32 MQTT (esp-mqtt)

```c
/* Cấu hình kết nối */
esp_mqtt_client_config_t mqtt_cfg = {
  .broker.address.uri = "mqtts://broker.example.com:8883",
  .credentials.client_id = "device_001",
  .credentials.username = "mqtt_user",
  .credentials.authentication.password = "mqtt_pass",
  .session.keepalive = 30,
  .session.last_will = {
    .topic = "devices/device_001/status",
    .msg = "offline",
    .qos = 1,
    .retain = true
  }
};

esp_mqtt_client_handle_t client = esp_mqtt_client_init(&mqtt_cfg);
esp_mqtt_client_register_event(client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
esp_mqtt_client_start(client);

/* Publish sensor data */
char payload[64];
snprintf(payload, sizeof(payload), "{\"temp\":%.1f,\"ts\":%lld}", temp, time(NULL));
int msg_id = esp_mqtt_client_publish(client, "sensors/device_001/temp", payload, 0, 1, 0);
```

### 1.3 TLS/mTLS Setup

```c
/* TLS với certificate verification */
esp_mqtt_client_config_t mqtt_cfg = {
  .broker.address.uri = "mqtts://broker.example.com:8883",
  .broker.verification.certificate = server_cert_pem_start,  /* Root CA */
  .credentials.authentication.certificate = client_cert_pem_start, /* Client cert */
  .credentials.authentication.key = client_key_pem_start          /* Client key */
};
```

### 1.4 Reconnect Pattern

```c
static void mqtt_event_handler(void *arg, esp_event_base_t base, int32_t event_id, void *event_data) {
  esp_mqtt_event_handle_t event = event_data;
  switch (event_id) {
    case MQTT_EVENT_CONNECTED:
      /* Re-subscribe sau mỗi lần reconnect */
      esp_mqtt_client_subscribe(client, "commands/device_001/#", 1);
      xEventGroupSetBits(g_mqttEvents, MQTT_CONNECTED_BIT);
      break;
    case MQTT_EVENT_DISCONNECTED:
      xEventGroupClearBits(g_mqttEvents, MQTT_CONNECTED_BIT);
      /* esp-mqtt tự động reconnect theo backoff */
      break;
    case MQTT_EVENT_DATA:
      HandleIncomingCommand(event->topic, event->data, event->data_len);
      break;
  }
}
```

---

## 2. BLE (Bluetooth Low Energy)

### 2.1 GATT Architecture

```
GATT Server (Device)
└── Service (UUID)
    ├── Characteristic (UUID)
    │   ├── Value (data bytes)
    │   ├── Properties: READ | WRITE | NOTIFY | INDICATE
    │   └── Descriptor (CCCD: Client Characteristic Configuration)
    └── Characteristic (UUID)
        └── ...
```

### 2.2 Standard Profile UUIDs

| Profile/Service | UUID |
|----------------|------|
| Generic Access | 0x1800 |
| Generic Attribute | 0x1801 |
| Device Information | 0x180A |
| Battery Service | 0x180F |
| Heart Rate | 0x180D |
| Environmental Sensing | 0x181A |
| Nordic UART Service (NUS) | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` |

### 2.3 ESP32 NimBLE (ESP-IDF)

```c
/* Define service và characteristic */
static const struct ble_gatt_svc_def gatt_svcs[] = {
  {
    .type = BLE_GATT_SVC_TYPE_PRIMARY,
    .uuid = BLE_UUID16_DECLARE(0x180F), /* Battery Service */
    .characteristics = (struct ble_gatt_chr_def[]) {
      {
        .uuid = BLE_UUID16_DECLARE(0x2A19), /* Battery Level */
        .access_cb = battery_chr_access,
        .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_NOTIFY,
        .val_handle = &battery_level_handle
      },
      { 0 } /* terminator */
    }
  },
  { 0 } /* terminator */
};

/* Gửi notification */
struct os_mbuf *om = ble_hs_mbuf_from_flat(&batteryLevel, sizeof(batteryLevel));
ble_gatts_notify_custom(conn_handle, battery_level_handle, om);
```

### 2.4 Advertising

```c
/* BLE advertising data */
struct ble_hs_adv_fields adv_fields = {
  .flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP,
  .tx_pwr_lvl = BLE_HS_ADV_TX_PWR_LVL_AUTO,
  .name = (uint8_t*)"MyDevice",
  .name_len = 8,
  .name_is_complete = 1
};
ble_gap_adv_set_fields(&adv_fields);

/* Start advertising */
struct ble_gap_adv_params adv_params = {
  .conn_mode = BLE_GAP_CONN_MODE_UND,   /* Undirected connectable */
  .disc_mode = BLE_GAP_DISC_MODE_GEN,   /* General discoverable */
  .itvl_min = BLE_GAP_ADV_ITVL_MS(100), /* 100ms interval */
  .itvl_max = BLE_GAP_ADV_ITVL_MS(500)
};
ble_gap_adv_start(BLE_OWN_ADDR_PUBLIC, NULL, BLE_HS_FOREVER, &adv_params, gap_event, NULL);
```

---

## 3. WiFi Provisioning

### 3.1 Methods Comparison

| Method | Pros | Cons | Dùng khi |
|--------|------|------|---------|
| **SoftAP** | Không cần app | User phải switch WiFi | Headless devices, simple setup |
| **BLE Provisioning** | Fast, secure | Cần BLE support | ESP32 with BLE, consumer products |
| **SmartConfig** | No extra hardware | Không ổn định | Deprecated, tránh dùng |
| **Provisioning by Scan** | UI đẹp trong app | Cần mobile app | IoT consumer devices |

### 3.2 ESP-IDF WiFi Provisioning (SoftAP)

```c
/* Khởi tạo provisioning */
wifi_prov_mgr_config_t config = {
  .scheme = wifi_prov_scheme_softap,
  .scheme_event_handler = WIFI_PROV_EVENT_HANDLER_NONE
};
wifi_prov_mgr_init(config);

/* Kiểm tra đã provisioned chưa */
bool provisioned = false;
wifi_prov_mgr_is_provisioned(&provisioned);

if (!provisioned) {
  /* Tạo SSID: MyDevice_AABBCC (dùng MAC để unique) */
  uint8_t mac[6];
  esp_wifi_get_mac(WIFI_IF_STA, mac);
  char ssid[32];
  snprintf(ssid, sizeof(ssid), "MyDevice_%02X%02X%02X", mac[3], mac[4], mac[5]);
  
  wifi_prov_mgr_start_provisioning(WIFI_PROV_SECURITY_1, "provision_key", ssid, NULL);
} else {
  wifi_prov_mgr_deinit();
  /* Connect với saved credentials */
  esp_wifi_start();
}
```

### 3.3 NVS Credential Storage

```c
/* Lưu WiFi credentials vào NVS (Non-Volatile Storage) */
nvs_handle_t nvs;
nvs_open("wifi_creds", NVS_READWRITE, &nvs);
nvs_set_str(nvs, "ssid", ssid);
nvs_set_str(nvs, "password", password);
nvs_commit(nvs);
nvs_close(nvs);

/* Đọc lại */
size_t len = 64;
char savedSSID[64] = {0};
nvs_get_str(nvs, "ssid", savedSSID, &len);
```

---

## 4. LoRaWAN

### 4.1 Core Concepts

| Khái niệm | Mô tả |
|-----------|-------|
| **Class A** | Devices gửi uplink, sau đó mở 2 receive windows ngắn. Ultra-low power. |
| **Class B** | Class A + scheduled downlink windows (sync beacon từ gateway) |
| **Class C** | Luôn listen (trừ khi transmitting). Tiêu thụ nhiều điện. |
| **OTAA** | Over-The-Air Activation: device join network bằng AppKey |
| **ABP** | Activation By Personalization: hardcode DevAddr + session keys |
| **Spreading Factor** | SF7 (nhanh, ít range) ↔ SF12 (chậm, xa hơn) |
| **Duty Cycle** | EU868: max 1% duty cycle (36s/giờ trên 1 channel) |

### 4.2 OTAA Join và Uplink (LMIC library)

```c
/* Join settings */
static const u1_t NWKSKEY[16] = { 0x... }; /* Network Session Key */
static const u1_t APPSKEY[16] = { 0x... }; /* App Session Key */
static const u4_t DEVADDR = 0x00000001;

void onEvent(ev_t ev) {
  switch (ev) {
    case EV_JOINED:
      /* OTAA join berhasil */
      LMIC_setLinkCheckMode(0);
      xEventGroupSetBits(g_loraEvents, LORA_JOINED_BIT);
      break;
    case EV_TXCOMPLETE:
      /* Uplink complete */
      if (LMIC.txrxFlags & TXRX_ACK) { /* Downlink ACK received */ }
      if (LMIC.dataLen > 0) { /* Downlink data received */ }
      break;
  }
}

/* Gửi payload (confirmed = ACK required) */
uint8_t payload[4] = {0};
payload[0] = (uint16_t)(temperature * 100) >> 8;
payload[1] = (uint16_t)(temperature * 100) & 0xFF;
LMIC_setTxData2(1, payload, sizeof(payload), 0 /* unconfirmed */);
```

### 4.3 TTN / Chirpstack Payload Format

```json
{
  "uplink_message": {
    "frm_payload": "AYA=",
    "decoded_payload": { "temperature": 24.16 },
    "rx_metadata": [{ "rssi": -87, "snr": 9.5 }],
    "settings": { "data_rate": { "lora": { "spreading_factor": 7 } } }
  }
}
```

---

## 5. Matter / Thread

### 5.1 Matter Overview

| Khái niệm | Mô tả |
|-----------|-------|
| **Matter** | Application-layer protocol (IPv6, WiFi, Thread, Ethernet) |
| **Thread** | Low-power mesh network (802.15.4), thường dùng với Matter |
| **Commissioner** | Phone app hoặc hub để commission (onboard) device |
| **Fabric** | Trust domain chứa nhiều controllers và devices |
| **Endpoint** | Logical device trong một node (1 plug có 2 outlet = 2 endpoints) |

### 5.2 Device Types phổ biến

| Device Type | ID | Examples |
|-------------|-----|---------|
| On/Off Light | 0x0100 | Smart bulb, relay |
| Dimmable Light | 0x0101 | Dimmer |
| On/Off Plug-In Unit | 0x010A | Smart plug |
| Temperature Sensor | 0x0302 | Thermometer |
| Door Lock | 0x000A | Smart lock |
| Window Covering | 0x0202 | Motorized curtain |

### 5.3 nRF Connect SDK (Matter + Thread)

```c
/* Matter init trong Zephyr */
#include <app/server/Server.h>
#include <app/clusters/on-off-server/on-off-server.h>

void MatterEventHandler(const DeviceLayer::ChipDeviceEvent *event, intptr_t arg) {
  switch (event->Type) {
    case DeviceLayer::DeviceEventType::kCommissioningComplete:
      /* Device đã được commission thành công */
      break;
  }
}

/* Implement On/Off cluster callback */
void emberAfOnOffClusterServerAttributeChangedCallback(
    chip::EndpointId endpoint, chip::AttributeId attributeId) {
  if (attributeId == chip::app::Clusters::OnOff::Attributes::OnOff::Id) {
    bool onOff = false;
    chip::app::Clusters::OnOff::Attributes::OnOff::Get(endpoint, &onOff);
    GPIO_SetRelay(onOff);
  }
}
```

---

## 6. OTA Firmware Update

### 6.1 ESP-IDF OTA (A/B Partition Scheme)

```
Partition Table:
  otadata   (8KB)     ← tracks active OTA partition
  ota_0    (1MB)      ← firmware slot A
  ota_1    (1MB)      ← firmware slot B
  (current = ota_0, update goes to ota_1, then swap)
```

```c
/* OTA update via HTTPS */
esp_https_ota_config_t ota_config = {
  .http_config = &http_config /* URL, cert, timeouts */
};

esp_https_ota_handle_t https_ota_handle;
esp_https_ota_begin(&ota_config, &https_ota_handle);

while (1) {
  esp_err_t err = esp_https_ota_perform(https_ota_handle);
  if (err != ESP_ERR_HTTPS_OTA_IN_PROGRESS) break;
  /* Có thể check progress và update UI */
}

esp_https_ota_finish(https_ota_handle); /* Validates, marks new partition bootable */
esp_restart(); /* Reboot vào firmware mới */
```

### 6.2 Rollback

```c
/* Khi firmware mới boot thành công, đánh dấu valid */
esp_ota_mark_app_valid_cancel_rollback();

/* Nếu không gọi trong timeout → bootloader tự rollback về firmware cũ */
/* Cấu hình rollback trong sdkconfig: CONFIG_BOOTLOADER_APP_ROLLBACK_ENABLE=y */
```

### 6.3 STM32 Bootloader + DFU

```c
/* Jump to DFU bootloader từ application */
void JumpToBootloader(void) {
  HAL_RCC_DeInit();
  HAL_DeInit();
  
  /* Disable SysTick */
  SysTick->CTRL = 0;
  SysTick->LOAD = 0;
  SysTick->VAL  = 0;
  
  /* Remap memory */
  __HAL_RCC_SYSCFG_CLK_ENABLE();
  __HAL_SYSCFG_REMAPMEMORY_SYSTEMFLASH();
  
  /* Set SP và PC từ system memory (bootloader) */
  uint32_t sysMem = 0x1FFF0000; /* STM32F4 system memory */
  uint32_t sp = *((uint32_t*)sysMem);
  uint32_t pc = *((uint32_t*)(sysMem + 4));
  
  __set_MSP(sp);
  ((void(*)(void))pc)();
}
```

---

## 7. Firmware Security

### 7.1 Secure Boot (ESP32)

```
Secure Boot V2 (RSA-PSS):
1. Bootloader generates private key (stored in eFuse) + burns public key hash
2. Each firmware image must be signed với private key
3. Bootloader verifies signature before loading
4. eFuse burn = permanent — nếu key mất, device brick

Bật trong sdkconfig:
  CONFIG_SECURE_BOOT=y
  CONFIG_SECURE_BOOT_V2_ENABLED=y
  CONFIG_SECURE_BOOT_SIGNING_KEY="private_key.pem"
```

### 7.2 Flash Encryption (ESP32)

```
AES-256 encrypts all Flash content (firmware, NVS, ota partitions)
Keys stored in eFuse (not readable after burn)
Transparent encryption/decryption via hardware

Bật trong sdkconfig:
  CONFIG_FLASH_ENCRYPTION_ENABLED=y
  (Development mode: can reflash with encrypted images)
  (Release mode: permanent, no re-flash without key)
```

### 7.3 TLS Certificate Management

```c
/* Nhúng certificate vào firmware (ESP-IDF) */
extern const uint8_t server_cert_pem_start[] asm("_binary_server_cert_pem_start");
extern const uint8_t server_cert_pem_end[]   asm("_binary_server_cert_pem_end");

/* Trong CMakeLists.txt: */
/* target_add_binary_data(${PROJECT_NAME}.elf "server.pem" TEXT) */

/* Sử dụng */
esp_tls_cfg_t tls_cfg = {
  .cacert_pem_buf = server_cert_pem_start,
  .cacert_pem_bytes = server_cert_pem_end - server_cert_pem_start
};
```

---

## 8. Quick Reference: Protocol Selection

| Yêu cầu | Protocol | Lý do |
|---------|---------|-------|
| Realtime, bi-directional, LAN | MQTT (QoS 0) | Low latency, broker local |
| Reliable delivery, cloud | MQTT (QoS 1) + TLS | Balance giữa reliability và overhead |
| Battery-powered, outdoor range | LoRaWAN Class A | Ultra-low power, km range |
| Phone app + firmware config | BLE GATT | Direct phone↔device, no cloud needed |
| Smart home (Apple/Google/Amazon) | Matter | Interoperability standard |
| High bandwidth (camera stream) | RTSP/WebRTC | UDP-based, low latency |
| Offline-first sensor node | LoRaWAN + NVS backup | Works without internet |
| Industrial field bus | CAN Bus (không WiFi) | Deterministic, noise-immune |
