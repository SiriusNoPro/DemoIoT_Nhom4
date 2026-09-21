#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

#include "cJSON.h"
#include "dht22.h"
#include "driver/gpio.h"
#include "esp_adc/adc_oneshot.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "esp_netif_sntp.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "mqtt_client.h"
#include "nvs_flash.h"
#include "protocol_examples_common.h"

#define DEVICE_ID "esp32-001"
#define MQTT_BROKER_URL "mqtt://10.32.83.195:1884" /* Docker host Wi-Fi IPv4 for this demo */
#define DHT_PIN GPIO_NUM_15
#define LED_PIN GPIO_NUM_2
#define BUZZER_PIN GPIO_NUM_7
#define LIGHT_PIN GPIO_NUM_5
#define SOIL_ADC_CHANNEL ADC_CHANNEL_3 /* GPIO4 on ESP32-S3 ADC1 */
#define SOIL_DRY_RAW 3000
#define SOIL_WET_RAW 1200
#define LIGHT_DARK_VALUE 80.0
#define LIGHT_BRIGHT_VALUE 255.0
#define LIGHT_ACTIVE_LOW 1

static const char *TAG = "IOT_ESP32";
static esp_mqtt_client_handle_t mqtt_client;
static volatile bool mqtt_connected;
static volatile bool led_state;
static volatile bool buzzer_state;
static adc_oneshot_unit_handle_t adc1_handle;
static char status_topic[64];
static char command_topic[64];
static char telemetry_topic[64];
static char ack_topic[68];
static char will_payload[128];

static bool utc_now(char *buffer, size_t length)
{
    time_t now = time(NULL);
    struct tm utc;
    if (now < 1700000000 || gmtime_r(&now, &utc) == NULL) return false;
    return strftime(buffer, length, "%Y-%m-%dT%H:%M:%SZ", &utc) != 0;
}

static float read_soil_moisture(void)
{
    int total = 0;
    const int samples = 16;
    for (int i = 0; i < samples; i++) {
        int raw = 0;
        if (adc_oneshot_read(adc1_handle, SOIL_ADC_CHANNEL, &raw) == ESP_OK) total += raw;
        vTaskDelay(pdMS_TO_TICKS(2));
    }
    float average = (float)total / samples;
    float percent = (SOIL_DRY_RAW - average) * 100.0f / (SOIL_DRY_RAW - SOIL_WET_RAW);
    if (percent < 0.0f) percent = 0.0f;
    if (percent > 100.0f) percent = 100.0f;
    return percent;
}

static float read_light_level(void)
{
    int level = gpio_get_level(LIGHT_PIN);
    bool bright = LIGHT_ACTIVE_LOW ? level == 0 : level != 0;
    return bright ? LIGHT_BRIGHT_VALUE : LIGHT_DARK_VALUE;
}

static void publish_status(esp_mqtt_client_handle_t client, const char *status)
{
    char timestamp[32];
    if (!utc_now(timestamp, sizeof(timestamp))) return;
    cJSON *json = cJSON_CreateObject();
    cJSON_AddStringToObject(json, "deviceId", DEVICE_ID);
    cJSON_AddStringToObject(json, "status", status);
    cJSON_AddStringToObject(json, "timestamp", timestamp);
    char *payload = cJSON_PrintUnformatted(json);
    if (payload) {
        esp_mqtt_client_publish(client, status_topic, payload, 0, 1, 1);
        cJSON_free(payload);
        ESP_LOGI(TAG, "Published %s status", status);
    }
    cJSON_Delete(json);
}

static void handle_command(esp_mqtt_event_handle_t event)
{
    if (event->topic_len != (int)strlen(command_topic) ||
        strncmp(event->topic, command_topic, event->topic_len) != 0) return;

    cJSON *json = cJSON_ParseWithLength(event->data, event->data_len);
    if (!json) return;
    const cJSON *id = cJSON_GetObjectItemCaseSensitive(json, "commandId");
    const cJSON *action = cJSON_GetObjectItemCaseSensitive(json, "action");
    if (!cJSON_IsString(id) || !id->valuestring || !id->valuestring[0] ||
        !cJSON_IsString(action) || !action->valuestring) {
        ESP_LOGW(TAG, "Rejected command without commandId or action");
        cJSON_Delete(json);
        return;
    }
    if (strcmp(action->valuestring, "LED_ON") == 0) {
        led_state = true;
        gpio_set_level(LED_PIN, 1);
    } else if (strcmp(action->valuestring, "LED_OFF") == 0) {
        led_state = false;
        gpio_set_level(LED_PIN, 0);
    } else if (strcmp(action->valuestring, "BUZZER_ON") == 0) {
        buzzer_state = true;
        gpio_set_level(BUZZER_PIN, 1);
    } else if (strcmp(action->valuestring, "BUZZER_OFF") == 0) {
        buzzer_state = false;
        gpio_set_level(BUZZER_PIN, 0);
    } else {
        ESP_LOGW(TAG, "Rejected unknown action: %s", action->valuestring);
        cJSON_Delete(json);
        return;
    }
    ESP_LOGI(TAG, "Received %s", action->valuestring);

    char timestamp[32];
    if (utc_now(timestamp, sizeof(timestamp))) {
        cJSON *ack = cJSON_CreateObject();
        cJSON_AddStringToObject(ack, "commandId", id->valuestring);
        cJSON_AddStringToObject(ack, "deviceId", DEVICE_ID);
        cJSON_AddStringToObject(ack, "action", action->valuestring);
        cJSON_AddStringToObject(ack, "status", "ACKNOWLEDGED");
        cJSON_AddBoolToObject(ack, "led", led_state);
        cJSON_AddBoolToObject(ack, "buzzer", buzzer_state);
        cJSON_AddStringToObject(ack, "timestamp", timestamp);
        char *payload = cJSON_PrintUnformatted(ack);
        if (payload) {
            esp_mqtt_client_publish(event->client, ack_topic, payload, 0, 1, 0);
            ESP_LOGI(TAG, "Sent ACK for command %s", id->valuestring);
            cJSON_free(payload);
        }
        cJSON_Delete(ack);
    }
    cJSON_Delete(json);
}

static void mqtt_event_handler(void *args, esp_event_base_t base, int32_t event_id, void *event_data)
{
    esp_mqtt_event_handle_t event = event_data;
    switch ((esp_mqtt_event_id_t)event_id) {
    case MQTT_EVENT_CONNECTED:
        mqtt_connected = true;
        ESP_LOGI(TAG, "MQTT_EVENT_CONNECTED");
        publish_status(event->client, "ONLINE");
        esp_mqtt_client_subscribe(event->client, command_topic, 1);
        ESP_LOGI(TAG, "Subscribed %s", command_topic);
        break;
    case MQTT_EVENT_DISCONNECTED:
        mqtt_connected = false;
        ESP_LOGW(TAG, "MQTT_EVENT_DISCONNECTED");
        break;
    case MQTT_EVENT_DATA:
        handle_command(event);
        break;
    default:
        break;
    }
}

static void telemetry_task(void *args)
{
    while (true) {
        float temperature = 0.0f;
        float humidity = 0.0f;
        char timestamp[32];
        if (mqtt_connected && utc_now(timestamp, sizeof(timestamp))) {
            bool dht_ok = dht22_read(&temperature, &humidity) == 0;
            float illuminance = read_light_level();
            float soil_moisture = read_soil_moisture();
            cJSON *json = cJSON_CreateObject();
            cJSON_AddStringToObject(json, "deviceId", DEVICE_ID);
            if (dht_ok) {
                cJSON_AddNumberToObject(json, "temperature", temperature);
                cJSON_AddNumberToObject(json, "humidity", humidity);
            } else {
                cJSON_AddNullToObject(json, "temperature");
                cJSON_AddNullToObject(json, "humidity");
                ESP_LOGW(TAG, "DHT22 read failed; publishing the other sensors");
            }
            cJSON_AddNumberToObject(json, "illuminance", illuminance);
            cJSON_AddNumberToObject(json, "soilMoisture", soil_moisture);
            cJSON_AddBoolToObject(json, "led", led_state);
            cJSON_AddBoolToObject(json, "buzzer", buzzer_state);
            cJSON_AddStringToObject(json, "timestamp", timestamp);
            char *payload = cJSON_PrintUnformatted(json);
            if (payload) {
                esp_mqtt_client_publish(mqtt_client, telemetry_topic, payload, 0, 0, 0);
                if (dht_ok) {
                    ESP_LOGI(TAG, "Published Telemetry: T=%.1f H=%.1f Light=%.0f Soil=%.1f%%",
                             temperature, humidity, illuminance, soil_moisture);
                } else {
                    ESP_LOGI(TAG, "Published Telemetry: T=null H=null Light=%.0f Soil=%.1f%%",
                             illuminance, soil_moisture);
                }
                cJSON_free(payload);
            }
            cJSON_Delete(json);
        }
        vTaskDelay(pdMS_TO_TICKS(5000));
    }
}

void app_main(void)
{
    esp_err_t nvs_result = nvs_flash_init();
    if (nvs_result == ESP_ERR_NVS_NO_FREE_PAGES || nvs_result == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        nvs_result = nvs_flash_init();
    }
    ESP_ERROR_CHECK(nvs_result);
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    ESP_ERROR_CHECK(example_connect());

    esp_sntp_config_t sntp_config = ESP_NETIF_SNTP_DEFAULT_CONFIG("pool.ntp.org");
    ESP_ERROR_CHECK(esp_netif_sntp_init(&sntp_config));
    while (esp_netif_sntp_sync_wait(pdMS_TO_TICKS(10000)) != ESP_OK) {
        ESP_LOGW(TAG, "Waiting for UTC time sync");
    }

    snprintf(status_topic, sizeof(status_topic), "device/%s/status", DEVICE_ID);
    snprintf(command_topic, sizeof(command_topic), "device/%s/command", DEVICE_ID);
    snprintf(telemetry_topic, sizeof(telemetry_topic), "device/%s/telemetry", DEVICE_ID);
    snprintf(ack_topic, sizeof(ack_topic), "device/%s/command/ack", DEVICE_ID);

    char timestamp[32];
    ESP_ERROR_CHECK(utc_now(timestamp, sizeof(timestamp)) ? ESP_OK : ESP_FAIL);
    snprintf(will_payload, sizeof(will_payload),
             "{\"deviceId\":\"%s\",\"status\":\"OFFLINE\",\"timestamp\":\"%s\"}",
             DEVICE_ID, timestamp);

    gpio_set_direction(LED_PIN, GPIO_MODE_OUTPUT);
    gpio_set_level(LED_PIN, 0);
    gpio_set_direction(BUZZER_PIN, GPIO_MODE_OUTPUT);
    gpio_set_level(BUZZER_PIN, 0);
    gpio_set_direction(LIGHT_PIN, GPIO_MODE_INPUT);

    adc_oneshot_unit_init_cfg_t adc_init_config = {
        .unit_id = ADC_UNIT_1,
    };
    ESP_ERROR_CHECK(adc_oneshot_new_unit(&adc_init_config, &adc1_handle));
    adc_oneshot_chan_cfg_t adc_channel_config = {
        .atten = ADC_ATTEN_DB_12,
        .bitwidth = ADC_BITWIDTH_DEFAULT,
    };
    ESP_ERROR_CHECK(adc_oneshot_config_channel(adc1_handle, SOIL_ADC_CHANNEL, &adc_channel_config));
    dht22_init(DHT_PIN);

    esp_mqtt_client_config_t config = {
        .broker.address.uri = MQTT_BROKER_URL,
        .session.last_will = {
            .topic = status_topic,
            .msg = will_payload,
            .qos = 1,
            .retain = 1,
        },
    };
    mqtt_client = esp_mqtt_client_init(&config);
    ESP_ERROR_CHECK(mqtt_client ? ESP_OK : ESP_FAIL);
    ESP_ERROR_CHECK(esp_mqtt_client_register_event(mqtt_client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL));
    ESP_ERROR_CHECK(esp_mqtt_client_start(mqtt_client));
    xTaskCreate(telemetry_task, "telemetry_task", 4096, NULL, 5, NULL);
}
