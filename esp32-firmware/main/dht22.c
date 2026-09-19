#include "dht22.h"
#include <stdbool.h>
#include "esp_rom_sys.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/portmacro.h"

static gpio_num_t data_pin;
static portMUX_TYPE dht_lock = portMUX_INITIALIZER_UNLOCKED;

static bool wait_level(int level, int timeout_us)
{
    int64_t deadline = esp_timer_get_time() + timeout_us;
    while (gpio_get_level(data_pin) != level) {
        if (esp_timer_get_time() >= deadline) return false;
    }
    return true;
}

void dht22_init(gpio_num_t pin)
{
    data_pin = pin;
    gpio_config_t config = {
        .pin_bit_mask = 1ULL << pin,
        .mode = GPIO_MODE_INPUT_OUTPUT_OD,
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    gpio_config(&config);
    gpio_set_level(data_pin, 1);
}

int dht22_read(float *temperature, float *humidity)
{
    if (!temperature || !humidity) return -1;
    uint8_t bytes[5] = {0};
    gpio_set_level(data_pin, 0);
    esp_rom_delay_us(1200);
    gpio_set_level(data_pin, 1);
    esp_rom_delay_us(30);

    portENTER_CRITICAL(&dht_lock);
    bool valid = wait_level(0, 100) && wait_level(1, 100) && wait_level(0, 100);
    for (int bit = 0; bit < 40 && valid; ++bit) {
        valid = wait_level(1, 70);
        if (!valid) break;
        esp_rom_delay_us(40);
        bytes[bit / 8] = (bytes[bit / 8] << 1) | (gpio_get_level(data_pin) ? 1 : 0);
        valid = wait_level(0, 100);
    }
    portEXIT_CRITICAL(&dht_lock);

    if (!valid || (uint8_t)(bytes[0] + bytes[1] + bytes[2] + bytes[3]) != bytes[4]) return -1;
    float h = ((bytes[0] << 8) | bytes[1]) / 10.0f;
    int raw = ((bytes[2] & 0x7f) << 8) | bytes[3];
    float t = raw / 10.0f * ((bytes[2] & 0x80) ? -1 : 1);
    if (h < 0 || h > 100 || t < -40 || t > 80) return -1;
    *temperature = t;
    *humidity = h;
    return 0;
}
