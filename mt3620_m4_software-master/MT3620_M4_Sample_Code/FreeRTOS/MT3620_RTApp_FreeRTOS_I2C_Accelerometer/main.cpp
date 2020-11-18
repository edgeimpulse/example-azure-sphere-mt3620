/*
 * (C) 2005-2020 MediaTek Inc. All rights reserved.
 *
 * Copyright Statement:
 *
 * This MT3620 driver software/firmware and related documentation
 * ("MediaTek Software") are protected under relevant copyright laws.
 * The information contained herein is confidential and proprietary to
 * MediaTek Inc. ("MediaTek"). You may only use, reproduce, modify, or
 * distribute (as applicable) MediaTek Software if you have agreed to and been
 * bound by this Statement and the applicable license agreement with MediaTek
 * ("License Agreement") and been granted explicit permission to do so within
 * the License Agreement ("Permitted User"). If you are not a Permitted User,
 * please cease any access or use of MediaTek Software immediately.
 *
 * BY OPENING THIS FILE, RECEIVER HEREBY UNEQUIVOCALLY ACKNOWLEDGES AND AGREES
 * THAT MEDIATEK SOFTWARE RECEIVED FROM MEDIATEK AND/OR ITS REPRESENTATIVES ARE
 * PROVIDED TO RECEIVER ON AN "AS-IS" BASIS ONLY. MEDIATEK EXPRESSLY DISCLAIMS
 * ANY AND ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE OR
 * NONINFRINGEMENT. NEITHER DOES MEDIATEK PROVIDE ANY WARRANTY WHATSOEVER WITH
 * RESPECT TO THE SOFTWARE OF ANY THIRD PARTY WHICH MAY BE USED BY,
 * INCORPORATED IN, OR SUPPLIED WITH MEDIATEK SOFTWARE, AND RECEIVER AGREES TO
 * LOOK ONLY TO SUCH THIRD PARTY FOR ANY WARRANTY CLAIM RELATING THERETO.
 * RECEIVER EXPRESSLY ACKNOWLEDGES THAT IT IS RECEIVER'S SOLE RESPONSIBILITY TO
 * OBTAIN FROM ANY THIRD PARTY ALL PROPER LICENSES CONTAINED IN MEDIATEK
 * SOFTWARE. MEDIATEK SHALL ALSO NOT BE RESPONSIBLE FOR ANY MEDIATEK SOFTWARE
 * RELEASES MADE TO RECEIVER'S SPECIFICATION OR TO CONFORM TO A PARTICULAR
 * STANDARD OR OPEN FORUM. RECEIVER'S SOLE AND EXCLUSIVE REMEDY AND MEDIATEK'S
 * ENTIRE AND CUMULATIVE LIABILITY WITH RESPECT TO MEDIATEK SOFTWARE RELEASED
 * HEREUNDER WILL BE ANY SOFTWARE LICENSE FEES OR SERVICE CHARGE PAID BY
 * RECEIVER TO MEDIATEK DURING THE PRECEDING TWELVE (12) MONTHS FOR SUCH
 * MEDIATEK SOFTWARE AT ISSUE.
 */

#include <cstdio>
#include <stdio.h>
#include <time.h>


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
const float features[] = {
    1.8400, -1.5700, 10.4200, 1.8400, -1.5700, 10.4200, 1.4100, -0.9100, 9.7000, 1.5300, -0.9300, 10.1800, 1.4800, -1.0600, 9.6200, 1.3000, -0.6700, 10.2100, 0.3900, 1.0500, 10.0900, 1.2600, 2.1100, 9.7000, 1.2600, 2.1100, 9.7000, 1.3700, 2.5500, 9.0600, 1.5800, 2.4400, 9.7100, 0.9400, 1.6100, 10.0200, 1.5600, 1.3900, 9.5500, 1.7600, 1.7900, 9.4200, 0.6200, 2.3900, 9.4300, 0.6200, 2.3900, 9.4300, -0.6200, 2.5200, 8.9400, 1.1600, 3.6900, 9.0300, 0.2500, 3.2400, 8.5700, -0.1300, 4.0500, 8.8800, -0.8800, 3.7700, 8.9700, -2.0000, 2.8200, 9.1300, -2.0000, 2.8200, 9.1300, -0.4800, 2.2800, 8.5500, 0.4300, 0.8300, 10.0200, -0.7500, 1.2800, 8.7000, -0.1200, 1.7000, 8.8900, -0.5700, 1.3200, 9.9900, 0.2900, 0.5400, 10.0600, 0.2900, 0.5400, 10.0600, -0.7300, -0.0100, 10.2200, -2.0400, -0.7600, 10.1300, -2.2700, -1.2400, 10.0200, -1.3700, -1.2500, 10.1900, -0.3600, -1.0200, 9.5300, -0.5800, -1.2100, 10.1000, -0.5800, -1.2100, 10.1000, 0.2900, -1.5200, 10.0100, 0.2400, -1.8600, 10.2200, -0.4200, -2.3100, 9.9600, -1.0900, -1.7500, 9.9800, -0.4300, -0.1300, 10.3100, -0.4300, -0.1300, 10.3100, 1.2300, 0.2000, 9.4800, 0.0900, -0.4900, 10.2500, 0.9900, -0.0900, 9.6300, 1.2400, -0.6000, 9.6200, 0.1000, -0.3300, 9.0200, 0.7300, -1.5100, 9.6400, 0.7300, -1.5100, 9.6400, 0.7000, -2.4800, 8.7300, 0.6500, -1.3300, 9.5000, 1.7700, -0.7400, 9.4200, 0.2200, -1.0800, 9.2000, 1.5500, -1.1500, 9.4600, 1.4400, -1.4100, 9.0300, 1.4400, -1.4100, 9.0300, 1.6800, -1.1900, 9.7500, 1.3300, -0.2100, 9.8600, 2.1900, 1.3200, 10.1700, 1.7900, 1.9100, 10.4400, 1.0800, 1.4200, 9.8900, 1.5100, 1.8400, 9.8500, 1.5100, 1.8400, 9.8500, 1.3900, 2.3300, 10.1600, 0.3400, 2.8900, 9.9900, 0.6900, 3.2000, 10.3700, 0.5900, 3.4900, 9.8600, 0.9100, 3.0700, 10.0600, 0.0400, 3.2500, 9.8200, 0.0400, 3.2500, 9.8200, -0.9300, 2.6900, 10.1600, -1.3900, 2.2200, 10.0100, 0.6300, 2.8100, 9.5300, 0.7300, 2.5600, 9.9400, 0.7300, 2.3600, 10.1300, -0.7900, 0.6700, 9.8700, -0.7900, 0.6700, 9.8700, -2.1000, 0.5600, 10.2400, -1.8700, 0.5800, 9.9000, -1.6200, -0.4400, 10.1500, 0.4000, -0.0600, 10.0100, 1.1100, 0.4400, 9.9300, -0.6000, -0.1700, 10.2000, -0.6000, -0.1700, 10.2000, -0.9400, -0.5000, 9.8700, 0.4300, -0.1500, 9.8800, -0.3600, -0.8600, 10.1900, -0.2000, -3.1100, 9.9700, -0.5400, -4.9100, 10.0100, -0.5800, -5.0700, 9.9700, -0.5800, -5.0700, 9.9700, -0.9500, -3.9100, 9.4000, -1.0000, -2.1400, 8.8900, -1.1900, -0.8000, 9.2000, -0.8700, -0.0600, 8.4900, 0.2500, -0.3800, 8.7600, 0.2500, -0.3800, 8.7600, -0.5100, -0.5500, 9.4000, -2.2800, -2.1100, 9.9900, 0.8600, -2.7400, 9.4100, 0.9600, -1.3400, 9.6300, 0.5800, -0.6500, 9.6400, 0.0200, -0.9800, 9.6000, 0.0200, -0.9800, 9.6000, -0.2400, -1.2700, 9.8800, 0.1200, -0.6700, 9.0700, 1.2400, -0.3900, 9.0600, 1.6300, 0.5200, 9.6900, 2.2300, 0.9800, 9.4300, 0.9300, 1.4800, 9.6600, 0.9300, 1.4800, 9.6600, 0.7900, 2.3600, 9.6700, 1.5200, 2.8700, 10.4000, 1.5700, 1.8200, 9.8600, 1.6000, 1.9800, 10.0000, 1.4700, 2.7200, 10.3200, 0.9800, 2.9100, 10.3300, 0.9800, 2.9100, 10.3300, 1.3700, 2.2800, 9.5800, 1.4600, 2.0500, 10.1100, 1.1300, 2.4600, 9.8900, 1.1400, 2.6900, 9.5900, 0.2800, 1.2700, 9.8100, -0.5200, 0.9000, 8.5000
};
int raw_feature_get_data(size_t offset, size_t length, float *out_ptr) {
    memcpy(out_ptr, features + offset, length * sizeof(float));
    return 0;
}

static float buffer[EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE] = { 0 };
static float inference_buffer[EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE] = { 0 };

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
    printf("Inference Task Started. (ISU%d)\n", i2c_port_num);
    vTaskDelay(pdMS_TO_TICKS((EI_CLASSIFIER_INTERVAL_MS * EI_CLASSIFIER_RAW_SAMPLE_COUNT) + 100));

    while (1) {
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
        printf("calling run_classifier %ld\n", clock() / CLOCKS_PER_SEC);
        EI_IMPULSE_ERROR res = run_classifier(&signal, &result, false);
        printf("run_classifier returned: %d\n", res);

        if (res != 0) return;

        printf("Predictions (DSP: %d ms., Classification: %d ms., Anomaly: %d ms.): \n",
            result.timing.dsp, result.timing.classification, result.timing.anomaly);

        // print the predictions
        printf("[");
        for (size_t ix = 0; ix < EI_CLASSIFIER_LABEL_COUNT; ix++) {
            printf("%.5f", result.classification[ix].value);
    #if EI_CLASSIFIER_HAS_ANOMALY == 1
            printf(", ");
    #else
            if (ix != EI_CLASSIFIER_LABEL_COUNT - 1) {
                printf(", ");
            }
    #endif
        }
    #if EI_CLASSIFIER_HAS_ANOMALY == 1
        printf("%.3f", result.anomaly);
    #endif
        printf("]\n");

        vTaskDelay(pdMS_TO_TICKS(200));
    }
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
