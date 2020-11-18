/* Edge Impulse inferencing library
 * Copyright (c) 2020 EdgeImpulse Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#ifndef _EI_CLASSIFIER_SMOOTHEN_H_
#define _EI_CLASSIFIER_SMOOTHEN_H_

#include <stdint.h>

typedef struct {
    int *last_readings;
    size_t last_readings_size;
    uint8_t min_readings_same;
    float classifier_confidence;
    float anomaly_confidence;
    uint8_t count[EI_CLASSIFIER_LABEL_COUNT + 2] = { 0 };
    size_t count_size = EI_CLASSIFIER_LABEL_COUNT + 2;
} ei_classifier_smoothen_t;

/**
 * Initialize a smoothen structure. This is useful if you don't want to trust
 * single readings, but rather want consensus
 * (e.g. 7 / 10 readings should be the same before I draw any ML conclusions).
 * This allocates memory on the heap!
 * @param smoothen Pointer to an uninitialized ei_classifier_smoothen_t struct
 * @param n_readings Number of readings you want to store
 * @param min_readings_same Minimum readings that need to be the same before concluding (needs to be lower than n_readings)
 * @param classifier_confidence Minimum confidence in a class (default 0.8)
 * @param anomaly_confidence Maximum error for anomalies (default 0.3)
 */
void ei_classifier_smoothen_init(ei_classifier_smoothen_t *smoothen, size_t n_readings,
                      uint8_t min_readings_same, float classifier_confidence = 0.8,
                      float anomaly_confidence = 0.3) {
    smoothen->last_readings = (int*)ei_malloc(n_readings * sizeof(int));
    for (size_t ix = 0; ix < n_readings; ix++) {
        smoothen->last_readings[ix] = -1; // -1 == uncertain
    }
    smoothen->last_readings_size = n_readings;
    smoothen->min_readings_same = min_readings_same;
    smoothen->classifier_confidence = classifier_confidence;
    smoothen->anomaly_confidence = anomaly_confidence;
    smoothen->count_size = EI_CLASSIFIER_LABEL_COUNT + 2;
}

/**
 * Call when a new reading comes in.
 * @param smoothen Pointer to an initialized ei_classifier_smoothen_t struct
 * @param result Pointer to a result structure (after calling ei_run_classifier)
 * @returns Label, either 'uncertain', 'anomaly', or a label from the result struct
 */
const char* ei_classifier_smoothen_update(ei_classifier_smoothen_t *smoothen, ei_impulse_result_t *result) {
    // clear out the count array
    memset(smoothen->count, 0, EI_CLASSIFIER_LABEL_COUNT + 2);

    // roll through the last_readings buffer
    numpy::roll(smoothen->last_readings, smoothen->last_readings_size, -1);

    int reading = -1; // uncertain

    // print the predictions
    // printf("[");
    for (size_t ix = 0; ix < EI_CLASSIFIER_LABEL_COUNT; ix++) {
        if (result->classification[ix].value >= smoothen->classifier_confidence) {
            reading = (int)ix;
        }
    }
#if EI_CLASSIFIER_HAS_ANOMALY == 1
    if (result->anomaly >= smoothen->anomaly_confidence) {
        reading = -2; // anomaly
    }
#endif

    smoothen->last_readings[smoothen->last_readings_size - 1] = reading;

    // now count last 10 readings and see what we actually see...
    for (size_t ix = 0; ix < smoothen->last_readings_size; ix++) {
        if (smoothen->last_readings[ix] >= 0) {
            smoothen->count[smoothen->last_readings[ix]]++;
        }
        else if (smoothen->last_readings[ix] == -1) { // uncertain
            smoothen->count[EI_CLASSIFIER_LABEL_COUNT]++;
        }
        else if (smoothen->last_readings[ix] == -2) { // anomaly
            smoothen->count[EI_CLASSIFIER_LABEL_COUNT + 1]++;
        }
    }

    // then loop over the count and see which is highest
    uint8_t top_result = 0;
    uint8_t top_count = 0;
    bool met_confidence_threshold = false;
    uint8_t confidence_threshold = smoothen->min_readings_same; // 70% of windows should be the same
    for (size_t ix = 0; ix < EI_CLASSIFIER_LABEL_COUNT + 2; ix++) {
        if (smoothen->count[ix] > top_count) {
            top_result = ix;
            top_count = smoothen->count[ix];
        }
        if (smoothen->count[ix] > confidence_threshold) {
            met_confidence_threshold = true;
        }
    }

    if (met_confidence_threshold) {
        if (top_result == EI_CLASSIFIER_LABEL_COUNT) {
            return "uncertain";
        }
        else if (top_result == EI_CLASSIFIER_LABEL_COUNT + 1) {
            return "anomaly";
        }
        else {
            return result->classification[top_result].label;
        }
    }
    return "uncertain";
}

/**
 * Clear up a smoothen structure
 */
void ei_classifier_smoothen_free(ei_classifier_smoothen_t *smoothen) {
    free(smoothen->last_readings);
}

#endif // _EI_CLASSIFIER_SMOOTHEN_H_
