idf_component_register(SRCS "main.c" "dht22.c"
                    INCLUDE_DIRS "."
                    REQUIRES mqtt json esp_netif esp_timer esp_driver_gpio nvs_flash protocol_examples_common)
