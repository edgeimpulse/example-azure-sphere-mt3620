#include <cstdio>
#include <stdio.h>

#include "FreeRTOS.h"
#include "task.h"
#include "printf.h"
#include "mt3620.h"

#include "os_hal_gpio.h"
#include "os_hal_uart.h"
#include "os_hal_i2c.h"

#include "lsm6dso_driver.h"
#include "lsm6dso_reg.h"

#include "ei_run_classifier.h"

void*   __dso_handle = (void*) &__dso_handle;

#if !defined(EI_CLASSIFIER_SENSOR) || EI_CLASSIFIER_SENSOR != EI_CLASSIFIER_SENSOR_ACCELEROMETER
#error "Incompatible model, this example is only compatible with accelerometer data"
#endif

/******************************************************************************/
/* Configurations */
/******************************************************************************/
/* UART */
static const UART_PORT uart_port_num = OS_HAL_UART_ISU0;

/* GPIO */
static const os_hal_gpio_pin gpio_led_red = OS_HAL_GPIO_8;
static const os_hal_gpio_pin gpio_led_green = OS_HAL_GPIO_9;

/* I2C */
static const i2c_num i2c_port_num = OS_HAL_I2C_ISU2;
static const i2c_speed_kHz i2c_speed = I2C_SCL_50kHz;
static const uint8_t i2c_lsm6dso_addr = LSM6DSO_I2C_ADD_L>>1;
static uint8_t *i2c_tx_buf;
static uint8_t *i2c_rx_buf;

#define I2C_MAX_LEN 64
#define APP_STACK_SIZE_BYTES 1024

// Edge Impulse
static float buffer[EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE] = { 0 };
static float inference_buffer[EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE] = { 0 };

// To prevent false positives we smoothen the results, with readings=10 and time_between_readings=200
// we look at 2 seconds of data + (length of window (e.g. also 2 seconds)) for the result

// We use N number of readings to smoothen the results over
#define SMOOTHEN_OVER_READINGS              10
// Time between readings in milliseconds
#define SMOOTHEN_TIME_BETWEEN_READINGS      200

/******************************************************************************/
/* Application Hooks */
/******************************************************************************/
/* Hook for "stack over flow". */
extern "C" void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName)
{
    printf("%s: %s\n", __func__, pcTaskName);
}

/* Hook for "memory allocation failed". */
extern "C" void vApplicationMallocFailedHook(void)
{
    printf("%s\n", __func__);
}

/* Hook for "printf". */
extern "C" void _putchar(char character)
{
    mtk_os_hal_uart_put_char(uart_port_num, character);
    if (character == '\n')
        mtk_os_hal_uart_put_char(uart_port_num, '\r');
}

/******************************************************************************/
/* Functions */
/******************************************************************************/
int32_t i2c_write(int *fD, uint8_t reg, uint8_t *buf, uint16_t len)
{
    if (buf == NULL)
        return -1;

    if (len > (I2C_MAX_LEN-1))
        return -1;

    i2c_tx_buf[0] = reg;
    if (buf && len)
        memcpy(&i2c_tx_buf[1], buf, len);
    mtk_os_hal_i2c_write(i2c_port_num, i2c_lsm6dso_addr, i2c_tx_buf, len+1);
    return 0;
}

int32_t i2c_read(int *fD, uint8_t reg, uint8_t *buf, uint16_t len)
{
    if (buf == NULL)
        return -1;

    if (len > (I2C_MAX_LEN))
        return -1;

    mtk_os_hal_i2c_write_read(i2c_port_num, i2c_lsm6dso_addr,
                    &reg, i2c_rx_buf, 1, len);
    memcpy(buf, i2c_rx_buf, len);
    return 0;
}

void i2c_enum(void)
{
    uint8_t i;
    uint8_t data;

    printf("[ISU%d] Enumerate I2C Bus, Start\n", i2c_port_num);
    for (i = 0 ; i < 0x80 ; i += 2) {
        printf("[ISU%d] Address:0x%02X, ", i2c_port_num, i);
        if (mtk_os_hal_i2c_read(i2c_port_num, i, &data, 1) == 0)
            printf("Found 0x%02X\n", i);
    }
    printf("[ISU%d] Enumerate I2C Bus, Finish\n\n", i2c_port_num);
}

int i2c_init(void)
{
    /* Allocate I2C buffer */
    i2c_tx_buf = (uint8_t*)pvPortMalloc(I2C_MAX_LEN);
    i2c_rx_buf = (uint8_t*)pvPortMalloc(I2C_MAX_LEN);
    if (i2c_tx_buf == NULL || i2c_rx_buf == NULL) {
        printf("Failed to allocate I2C buffer!\n");
        return -1;
    }

    /* MT3620 I2C Init */
    mtk_os_hal_i2c_ctrl_init(i2c_port_num);
    mtk_os_hal_i2c_speed_init(i2c_port_num, i2c_speed);

    return 0;
}

void inference_task(void *pParameters)
{
    // struct that smoothens out the readings over time, to avoid misclassification if a single frame
    // happened to overlap with one of the classes in our training set
    ei_classifier_smoothen_t smoothen;

    ei_classifier_smoothen_init(&smoothen, SMOOTHEN_OVER_READINGS, SMOOTHEN_OVER_READINGS * 0.7,
        0.8 /* confidence */, 0.3 /* max anomaly score */);

    static bool first_reading = true;

    printf("Inference Task Started\n");

    // wait until we have a full frame of data
    vTaskDelay(pdMS_TO_TICKS((EI_CLASSIFIER_INTERVAL_MS * EI_CLASSIFIER_RAW_SAMPLE_COUNT)));

    while (1) {
        // copy into working buffer (other buffer is used by other task)
        memcpy(inference_buffer, buffer, EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE * sizeof(float));

        // Turn the raw buffer in a signal which we can the classify
        signal_t signal;
        int err = numpy::signal_from_buffer(inference_buffer, EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE, &signal);
        if (err != 0) {
            ei_printf("Failed to create signal from buffer (%d)\n", err);
            return;
        }

        ei_impulse_result_t result = { 0 };

        // invoke the impulse
        EI_IMPULSE_ERROR res = run_classifier(&signal, &result, false);
        if (res != 0) {
            printf("run_classifier returned: %d\n", res);
            return;
        }

        if (first_reading) {
            printf("Timing = (DSP: %d ms., Classification: %d ms., Anomaly: %d ms.)\n",
                result.timing.dsp, result.timing.classification, result.timing.anomaly);
            first_reading = false;
        }

        const char *prediction = ei_classifier_smoothen_update(&smoothen, &result);
        printf("%s", prediction);

        printf(" [ ");
        for (size_t ix = 0; ix < smoothen.count_size; ix++) {
            printf("%u", smoothen.count[ix]);
            if (ix != smoothen.count_size + 1) {
                printf(", ");
            }
        }
        printf("]\n");

        vTaskDelay(pdMS_TO_TICKS(SMOOTHEN_TIME_BETWEEN_READINGS));
    }

    ei_classifier_smoothen_free(&smoothen);
}

void i2c_task(void *pParameters)
{
    /* Enumerate I2C Bus*/
    i2c_enum();

    /* MT3620 I2C Init */
    if (i2c_init())
        return;

    /* LSM6DSO Init */
    if (lsm6dso_init((void*)i2c_write, (void*)i2c_read))
        return;

    xTaskCreate(inference_task, "Inferencing Task", APP_STACK_SIZE_BYTES, NULL, 2, NULL);

    while (1) {
        // roll the buffer -3 points so we can overwrite the last one
        numpy::roll(buffer, EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE, -3);

        float x, y, z;
        lsm6dso_read(&x, &y, &z);

        buffer[EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE - 3] = x / 100.0f;
        buffer[EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE - 2] = y / 100.0f;
        buffer[EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE - 1] = z / 100.0f;

        vTaskDelay(pdMS_TO_TICKS(EI_CLASSIFIER_INTERVAL_MS));
    }
}

extern "C" _Noreturn void RTCoreMain(void)
{
    /* Setup Vector Table */
    NVIC_SetupVectorTable();

    /* Init UART */
    mtk_os_hal_uart_ctlr_init(uart_port_num);

    /* Init GPIO */
    mtk_os_hal_gpio_set_direction(gpio_led_red, OS_HAL_GPIO_DIR_OUTPUT);
    mtk_os_hal_gpio_set_direction(gpio_led_green, OS_HAL_GPIO_DIR_OUTPUT);

    mtk_os_hal_gpio_set_output(gpio_led_red, OS_HAL_GPIO_DATA_LOW);
    mtk_os_hal_gpio_set_output(gpio_led_green, OS_HAL_GPIO_DATA_HIGH);

    printf("\nFreeRTOS I2C LSM6DSO Demo %d\n", 1337);

    /* Init I2C Master/Slave */
    mtk_os_hal_i2c_ctrl_init(i2c_port_num);

    /* Create I2C Master/Slave Task */
    xTaskCreate(i2c_task, "I2C Task", APP_STACK_SIZE_BYTES / 4, NULL, 4, NULL);

    vTaskStartScheduler();
    for (;;)
        __asm__("wfi");
}
