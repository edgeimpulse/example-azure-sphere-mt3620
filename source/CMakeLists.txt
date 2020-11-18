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
add_definitions(-DEIDSP_USE_CMSIS_DSP=0
                -DEIDSP_LOAD_CMSIS_DSP_SOURCES=0
                -DEI_CLASSIFIER_TFLITE_ENABLE_CMSIS_NN=0
                -DEIDSP_QUANTIZE_FILTERBANK=0
                -DARM_MATH_LOOPUNROLL
                -DEIDSP_TRACK_ALLOCATIONS=1
                -DEIDSP_PRINT_ALLOCATIONS=0
                -DEI_CLASSIFIER_ALLOCATION_STATIC
                -DTF_LITE_STATIC_MEMORY
                )

add_compile_definitions(OSAI_FREERTOS)
add_compile_definitions(OSAI_ENABLE_DMA)
# When place CODE_REGION in FLASH instead of TCM, please enable this definition:
add_compile_definitions(M4_ENABLE_XIP_FLASH)
add_link_options(-specs=nano.specs -specs=nosys.specs)

# Executable
add_executable(${PROJECT_NAME})

# Include Folders
# Edge impulse SDK include directories
set(INCLUDES
    .
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
    )
include_directories(${PROJECT_NAME} PUBLIC ${INCLUDES})

target_include_directories(${PROJECT_NAME} PUBLIC
                           ../../OS_HAL/inc
                           ./)

RECURSIVE_FIND_FILE(SOURCE_FILES "edge-impulse-sdk" "*.cpp")
RECURSIVE_FIND_FILE(MODEL_FILES "tflite-model" "*.cpp")
RECURSIVE_FIND_FILE(CC_FILES "edge-impulse-sdk" "*.cc")
RECURSIVE_FIND_FILE(S_FILES "edge-impulse-sdk" "*.s")
RECURSIVE_FIND_FILE(C_FILES "edge-impulse-sdk" "*.c")
list(APPEND SOURCE_FILES ${S_FILES})
list(APPEND SOURCE_FILES ${C_FILES})
list(APPEND SOURCE_FILES ${CC_FILES})
list(APPEND SOURCE_FILES ${MODEL_FILES})

# Exclude the CMSIS folders, I don't have time to fix all of this
set(EXCLUDE_DIR "/CMSIS/")
foreach (TMP_PATH ${SOURCE_FILES})
    string (FIND ${TMP_PATH} ${EXCLUDE_DIR} EXCLUDE_DIR_FOUND)
    if (NOT ${EXCLUDE_DIR_FOUND} EQUAL -1)
        list (REMOVE_ITEM SOURCE_FILES ${TMP_PATH})
    endif ()
endforeach(TMP_PATH)

# target_sources(${PROJECT_NAME} PRIVATE ${SOURCE_FILES})

#target_sources(${PROJECT_NAME} PRIVATE src/main.cpp)


# Executable
target_sources(${PROJECT_NAME} PRIVATE ${SOURCE_FILES})
target_sources(${PROJECT_NAME} PRIVATE ./main.cpp)
target_sources(${PROJECT_NAME} PRIVATE ./lsm6dso_driver.c)
target_sources(${PROJECT_NAME} PRIVATE ./lsm6dso_reg.c)
target_sources(${PROJECT_NAME} PRIVATE ./porting/debug_log.cpp)
target_sources(${PROJECT_NAME} PRIVATE ./porting/ei_classifier_porting.cpp)
target_sources(${PROJECT_NAME} PRIVATE ../mt3620_m4_software-master/MT3620_M4_Sample_Code/OS_HAL/src/os_hal_gpio.c)
target_sources(${PROJECT_NAME} PRIVATE ../mt3620_m4_software-master/MT3620_M4_Sample_Code/OS_HAL/src/os_hal_uart.c)
target_sources(${PROJECT_NAME} PRIVATE ../mt3620_m4_software-master/MT3620_M4_Sample_Code/OS_HAL/src/os_hal_dma.c)
target_sources(${PROJECT_NAME} PRIVATE ../mt3620_m4_software-master/MT3620_M4_Sample_Code/OS_HAL/src/os_hal_i2c.c)

# Libraries
set(OSAI_FREERTOS 1)
add_subdirectory(../mt3620_m4_software-master/MT3620_M4_Driver ./lib/MT3620_M4_Driver)
target_link_libraries(${PROJECT_NAME} MT3620_M4_Driver)

# Linker, Image
set_target_properties(${PROJECT_NAME} PROPERTIES LINK_DEPENDS ${CMAKE_SOURCE_DIR}/linker.ld)
azsphere_target_add_image_package(${PROJECT_NAME})
