/* Generated by Edge Impulse
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

#ifndef _EI_CLASSIFIER_ANOMALY_CLUSTERS_H_
#define _EI_CLASSIFIER_ANOMALY_CLUSTERS_H_

#include "edge-impulse-sdk/anomaly/anomaly.h"

// (before - mean) / scale
const float ei_classifier_anom_scale[EI_CLASSIFIER_ANOM_AXIS_SIZE] = { 4.677716991045109, 2.6807735798322265, 1.7878896521529057 };
const float ei_classifier_anom_mean[EI_CLASSIFIER_ANOM_AXIS_SIZE] = { 4.049253756995615, 2.176246025334355, 1.7247324142624738 };

const ei_classifier_anom_cluster_t ei_classifier_anom_clusters[EI_CLASSIFIER_ANOM_CLUSTER_COUNT] = { { { 0.9787842035293579, -0.10284792631864548, 0.7487738728523254 }, 0.49728206866487085 }
, { { -0.6597225666046143, -0.19599513709545135, -0.8294264674186707 }, 0.3021868203261926 }
, { { -0.8648430705070496, -0.8103421926498413, -0.9609860777854919 }, 0.06897922916764229 }
, { { -0.6911530494689941, -0.35917624831199646, -0.7213176488876343 }, 0.2977162178691692 }
, { { -0.5609683990478516, 0.3331587314605713, -0.27592331171035767 }, 0.3463540066710449 }
, { { -0.6262943744659424, -0.013759643770754337, 1.758225917816162 }, 0.4008013123019078 }
, { { -0.34657835960388184, -0.04953658953309059, 2.6922237873077393 }, 0.6816468112208848 }
, { { 1.5289050340652466, 0.7466232776641846, 0.13703659176826477 }, 0.475675124620682 }
, { { -0.4039129912853241, 3.311537504196167, -0.24803036451339722 }, 0.4987923635561109 }
, { { 0.9984645843505859, -0.06949276477098465, -0.35720038414001465 }, 0.3428066151241744 }
, { { 1.677612543106079, 0.595112681388855, 0.5887191295623779 }, 0.3198703504438305 }
, { { -0.4249028265476227, -0.3317238390445709, 2.1257402896881104 }, 0.7367921735594811 }
, { { 1.3520702123641968, -0.38202881813049316, 0.6156148910522461 }, 0.3705604708968316 }
, { { 1.151719331741333, -0.32791510224342346, -0.1509680300951004 }, 0.3776133623978573 }
, { { 1.2306536436080933, 0.2845533788204193, -0.039658136665821075 }, 0.4777164196351518 }
, { { -0.6802474856376648, -0.5005916953086853, 0.8841982483863831 }, 0.17714257262602695 }
, { { 1.7711036205291748, 0.2756361663341522, 0.3472443222999573 }, 0.4552462321357169 }
, { { -0.45886537432670593, -0.3777782618999481, 2.496960163116455 }, 0.3548919987541503 }
, { { 1.0260059833526611, 3.2638466358184814, 1.1441134214401245 }, 0.31586356851643943 }
, { { -0.5585231781005859, 0.07482703030109406, 1.3090965747833252 }, 0.42608980387850964 }
, { { 1.3942135572433472, -0.20736947655677795, -0.3917272984981537 }, 0.46914095786448223 }
, { { 1.9367129802703857, 0.06214451044797897, 1.378117322921753 }, 0.5566898009406961 }
, { { -0.527009904384613, 0.6036292314529419, 0.013903023675084114 }, 0.5646154233978363 }
, { { 1.3656988143920898, 0.1999337524175644, -0.41297921538352966 }, 0.3415535856554037 }
, { { -0.7258737087249756, -0.4784170389175415, 1.2396011352539062 }, 0.2524988952244247 }
, { { -0.2600155472755432, 1.5715409517288208, 0.1444423645734787 }, 0.8988913439103206 }
, { { -0.09362787753343582, 3.539919853210449, -0.40547046065330505 }, 0.3681575853247179 }
, { { -0.6523675918579102, -0.3007986843585968, 1.5885103940963745 }, 0.3308938248601472 }
, { { 0.013510562479496002, 3.8188693523406982, -0.11200831830501556 }, 0.4903956303698676 }
, { { 1.9211982488632202, -0.005435988772660494, 0.8020132780075073 }, 0.3764450324957776 }
, { { 0.8201168775558472, 2.773259401321411, 0.7787922620773315 }, 0.45324703907814345 }
, { { -0.004712195601314306, 1.224219799041748, 2.4766719341278076 }, 0.2939598710753949 }
};

#endif // _EI_CLASSIFIER_ANOMALY_CLUSTERS_H_