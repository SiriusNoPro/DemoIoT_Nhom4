#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

#include "cJSON.h"
#include "dht22.h"
#include "driver/gpio.h"
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

static const char *TAG = "IOT_ESP32";
static esp_mqtt_client_handle_t mqtt_client;
static volatile bool mqtt_connected;
static volatile bool led_state;
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
    bool next_state;
    if (strcmp(action->valuestring, "LED_ON") == 0) next_state = true;
    else if (strcmp(action->valuestring, "LED_OFF") == 0) next_state = false;
    else {
        ESP_LOGW(TAG, "Rejected unknown action: %s", action->valuestring);
        cJSON_Delete(json);
        return;
    }

    gpio_set_level(LED_PIN, next_state);
    led_state = next_state;
    ESP_LOGI(TAG, "Received %s", action->valuestring);

    char timestamp[32];
    if (utc_now(timestamp, sizeof(timestamp))) {
        cJSON *ack = cJSON_CreateObject();
        cJSON_AddStringToObject(ack, "commandId", id->valuestring);
        cJSON_AddStringToObject(ack, "deviceId", DEVICE_ID);
        cJSON_AddStringToObject(ack, "action", action->valuestring);
        cJSON_AddStringToObject(ack, "status", "ACKNOWLEDGED");
        cJSON_AddBoolToObject(ack, "led", led_state);
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
        float temperature, humidity;
        char timestamp[32];
        if (mqtt_connected && utc_now(timestamp, sizeof(timestamp)) &&
            dht22_read(&temperature, &humidity) == 0) {
            cJSON *json = cJSON_CreateObject();
            cJSON_AddStringToObject(json, "deviceId", DEVICE_ID);
            cJSON_AddNumberToObject(json, "temperature", temperature);
            cJSON_AddNumberToObject(json, "humidity", humidity);
            cJSON_AddNullToObject(json, "illuminance");
            cJSON_AddNullToObject(json, "soilMoisture");
            cJSON_AddBoolToObject(json, "led", led_state);
            cJSON_AddStringToObject(json, "timestamp", timestamp);
            char *payload = cJSON_PrintUnformatted(json);
            if (payload) {
                esp_mqtt_client_publish(mqtt_client, telemetry_topic, payload, 0, 0, 0);
                ESP_LOGI(TAG, "Published Telemetry: T=%.1f H=%.1f", temperature, humidity);
                cJSON_free(payload);
            }
            cJSON_Delete(json);
        } else if (mqtt_connected) {
            ESP_LOGW(TAG, "DHT22 read failed; telemetry skipped");
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
