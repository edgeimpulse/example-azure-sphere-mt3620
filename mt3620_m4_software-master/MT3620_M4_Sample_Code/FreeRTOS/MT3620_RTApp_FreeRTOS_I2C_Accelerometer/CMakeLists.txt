# This code is based on a sample from Microsoft (see license below),
# with modifications made by MediaTek.
# Modified version of CMakeLists.txt from Microsoft Azure Sphere sample code:
# https://github.com/Azure/azure-sphere-samples/blob/master/Samples/HelloWorld/HelloWorld_RTApp_MT3620_BareMetal/CMakeLists.txt

#  Copyright (c) Microsoft Corporation. All rights reserved.
#  Licensed under the MIT License.

cmake_minimum_required(VERSION 3.10)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Configurations
project(FreeRTOS_RTcore_I2C_Accelerometer)
include(utils/cmake/utils.cmake)
azsphere_configure_tools(TOOLS_REVISION "20.07")

# Use hardware acceleration for DSP and Neural Network code
# You'll need to disable these on non-Arm cores
add_definitions(-DEIDSP_USE_CMSIS_DSP=1
                -DEIDSP_LOAD_CMSIS_DSP_SOURCES=1
                -DEI_CLASSIFIER_TFLITE_ENABLE_CMSIS_NN=1
                -DEIDSP_QUANTIZE_FILTERBANK=0
                -DARM_MATH_LOOPUNROLL
                )

add_compile_definitions(OSAI_FREERTOS)
add_compile_definitions(OSAI_ENABLE_DMA)
# When place CODE_REGION in FLASH instead of TCM, please enable this definition:
# add_compile_definitions(M4_ENABLE_XIP_FLASH)
# add_link_options(-specs=nano.specs -specs=nosys.specs)

# Executable
add_executable(${PROJECT_NAME}
               ./main.cpp
               ./lsm6dso_driver.c
               ./lsm6dso_reg.c
               ../../OS_HAL/src/os_hal_gpio.c
               ../../OS_HAL/src/os_hal_uart.c
               ../../OS_HAL/src/os_hal_dma.c
               ../../OS_HAL/src/os_hal_i2c.c)

# Include Folders
# Edge impulse SDK include directories
set(INCLUDES
    .
    src
    tflite-model
    model-parameters
    edge-impulse-sdk
    edge-impulse-sdk/third_party/ruy
    edge-impulse-sdk/third_party/gemmlowp
    edge-impulse-sdk/third_party/flatbuffers/include
    edge-impulse-sdk/third_party
    edge-impulse-sdk/tensorflow
    edge-impulse-sdk/dsp
    edge-impulse-sdk/classifier
    edge-impulse-sdk/anomaly
    edge-impulse-sdk/CMSIS/NN/Include
    edge-impulse-sdk/CMSIS/DSP/PrivateInclude
    edge-impulse-sdk/CMSIS/DSP/Include
    edge-impulse-sdk/CMSIS/Core/Include
    )
include_directories(${PROJECT_NAME} PUBLIC ${INCLUDES})

target_include_directories(${PROJECT_NAME} PUBLIC
                           ../../OS_HAL/inc
                           ./)

# Libraries
set(OSAI_FREERTOS 1)
add_subdirectory(../../../MT3620_M4_Driver ./lib/MT3620_M4_Driver)
target_link_libraries(${PROJECT_NAME} MT3620_M4_Driver)

# Linker, Image
set_target_properties(${PROJECT_NAME} PROPERTIES LINK_DEPENDS ${CMAKE_SOURCE_DIR}/linker.ld)
azsphere_target_add_image_package(${PROJECT_NAME})
