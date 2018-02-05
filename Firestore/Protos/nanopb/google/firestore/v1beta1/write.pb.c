/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* Automatically generated nanopb constant definitions */
/* Generated by nanopb-0.3.8 at Fri Feb  2 17:48:02 2018. */

#include "write.pb.h"

/* @@protoc_insertion_point(includes) */
#if PB_PROTO_HEADER_VERSION != 30
#error Regenerate this file with the current version of nanopb generator.
#endif



const pb_field_t google_firestore_v1beta1_Write_fields[7] = {
    PB_FIELD(  1, MESSAGE , SINGULAR, STATIC  , FIRST, google_firestore_v1beta1_Write, update, update, &google_firestore_v1beta1_Document_fields),
    PB_FIELD(  2, STRING  , SINGULAR, CALLBACK, OTHER, google_firestore_v1beta1_Write, delete_, update, 0),
    PB_FIELD(  3, MESSAGE , SINGULAR, STATIC  , OTHER, google_firestore_v1beta1_Write, update_mask, delete_, &google_firestore_v1beta1_DocumentMask_fields),
    PB_FIELD(  4, MESSAGE , SINGULAR, STATIC  , OTHER, google_firestore_v1beta1_Write, current_document, update_mask, &google_firestore_v1beta1_Precondition_fields),
    PB_FIELD(  5, STRING  , SINGULAR, CALLBACK, OTHER, google_firestore_v1beta1_Write, verify, current_document, 0),
    PB_FIELD(  6, MESSAGE , SINGULAR, STATIC  , OTHER, google_firestore_v1beta1_Write, transform, verify, &google_firestore_v1beta1_DocumentTransform_fields),
    PB_LAST_FIELD
};

const pb_field_t google_firestore_v1beta1_DocumentTransform_fields[3] = {
    PB_FIELD(  1, STRING  , SINGULAR, CALLBACK, FIRST, google_firestore_v1beta1_DocumentTransform, document, document, 0),
    PB_FIELD(  2, MESSAGE , REPEATED, CALLBACK, OTHER, google_firestore_v1beta1_DocumentTransform, field_transforms, document, &google_firestore_v1beta1_DocumentTransform_FieldTransform_fields),
    PB_LAST_FIELD
};

const pb_field_t google_firestore_v1beta1_DocumentTransform_FieldTransform_fields[3] = {
    PB_FIELD(  1, STRING  , SINGULAR, CALLBACK, FIRST, google_firestore_v1beta1_DocumentTransform_FieldTransform, field_path, field_path, 0),
    PB_ONEOF_FIELD(transform_type,   2, ENUM    , ONEOF, STATIC  , OTHER, google_firestore_v1beta1_DocumentTransform_FieldTransform, set_to_server_value, field_path, 0),
    PB_LAST_FIELD
};

const pb_field_t google_firestore_v1beta1_WriteResult_fields[3] = {
    PB_FIELD(  1, MESSAGE , SINGULAR, STATIC  , FIRST, google_firestore_v1beta1_WriteResult, update_time, update_time, &google_protobuf_Timestamp_fields),
    PB_FIELD(  2, MESSAGE , REPEATED, CALLBACK, OTHER, google_firestore_v1beta1_WriteResult, transform_results, update_time, &google_firestore_v1beta1_Value_fields),
    PB_LAST_FIELD
};

const pb_field_t google_firestore_v1beta1_DocumentChange_fields[4] = {
    PB_FIELD(  1, MESSAGE , SINGULAR, STATIC  , FIRST, google_firestore_v1beta1_DocumentChange, document, document, &google_firestore_v1beta1_Document_fields),
    PB_FIELD(  5, INT32   , REPEATED, CALLBACK, OTHER, google_firestore_v1beta1_DocumentChange, target_ids, document, 0),
    PB_FIELD(  6, INT32   , REPEATED, CALLBACK, OTHER, google_firestore_v1beta1_DocumentChange, removed_target_ids, target_ids, 0),
    PB_LAST_FIELD
};

const pb_field_t google_firestore_v1beta1_DocumentDelete_fields[4] = {
    PB_FIELD(  1, STRING  , SINGULAR, CALLBACK, FIRST, google_firestore_v1beta1_DocumentDelete, document, document, 0),
    PB_FIELD(  4, MESSAGE , SINGULAR, STATIC  , OTHER, google_firestore_v1beta1_DocumentDelete, read_time, document, &google_protobuf_Timestamp_fields),
    PB_FIELD(  6, INT32   , REPEATED, CALLBACK, OTHER, google_firestore_v1beta1_DocumentDelete, removed_target_ids, read_time, 0),
    PB_LAST_FIELD
};

const pb_field_t google_firestore_v1beta1_DocumentRemove_fields[4] = {
    PB_FIELD(  1, STRING  , SINGULAR, CALLBACK, FIRST, google_firestore_v1beta1_DocumentRemove, document, document, 0),
    PB_FIELD(  2, INT32   , REPEATED, CALLBACK, OTHER, google_firestore_v1beta1_DocumentRemove, removed_target_ids, document, 0),
    PB_FIELD(  4, MESSAGE , SINGULAR, STATIC  , OTHER, google_firestore_v1beta1_DocumentRemove, read_time, removed_target_ids, &google_protobuf_Timestamp_fields),
    PB_LAST_FIELD
};

const pb_field_t google_firestore_v1beta1_ExistenceFilter_fields[3] = {
    PB_FIELD(  1, INT32   , SINGULAR, STATIC  , FIRST, google_firestore_v1beta1_ExistenceFilter, target_id, target_id, 0),
    PB_FIELD(  2, INT32   , SINGULAR, STATIC  , OTHER, google_firestore_v1beta1_ExistenceFilter, count, target_id, 0),
    PB_LAST_FIELD
};



/* Check that field information fits in pb_field_t */
#if !defined(PB_FIELD_32BIT)
/* If you get an error here, it means that you need to define PB_FIELD_32BIT
 * compile-time option. You can do that in pb.h or on compiler command line.
 * 
 * The reason you need to do this is that some of your messages contain tag
 * numbers or field sizes that are larger than what can fit in 8 or 16 bit
 * field descriptors.
 */
PB_STATIC_ASSERT((pb_membersize(google_firestore_v1beta1_Write, update) < 65536 && pb_membersize(google_firestore_v1beta1_Write, transform) < 65536 && pb_membersize(google_firestore_v1beta1_Write, update_mask) < 65536 && pb_membersize(google_firestore_v1beta1_Write, current_document) < 65536 && pb_membersize(google_firestore_v1beta1_WriteResult, update_time) < 65536 && pb_membersize(google_firestore_v1beta1_DocumentChange, document) < 65536 && pb_membersize(google_firestore_v1beta1_DocumentDelete, read_time) < 65536 && pb_membersize(google_firestore_v1beta1_DocumentRemove, read_time) < 65536), YOU_MUST_DEFINE_PB_FIELD_32BIT_FOR_MESSAGES_google_firestore_v1beta1_Write_google_firestore_v1beta1_DocumentTransform_google_firestore_v1beta1_DocumentTransform_FieldTransform_google_firestore_v1beta1_WriteResult_google_firestore_v1beta1_DocumentChange_google_firestore_v1beta1_DocumentDelete_google_firestore_v1beta1_DocumentRemove_google_firestore_v1beta1_ExistenceFilter)
#endif

#if !defined(PB_FIELD_16BIT) && !defined(PB_FIELD_32BIT)
/* If you get an error here, it means that you need to define PB_FIELD_16BIT
 * compile-time option. You can do that in pb.h or on compiler command line.
 * 
 * The reason you need to do this is that some of your messages contain tag
 * numbers or field sizes that are larger than what can fit in the default
 * 8 bit descriptors.
 */
PB_STATIC_ASSERT((pb_membersize(google_firestore_v1beta1_Write, update) < 256 && pb_membersize(google_firestore_v1beta1_Write, transform) < 256 && pb_membersize(google_firestore_v1beta1_Write, update_mask) < 256 && pb_membersize(google_firestore_v1beta1_Write, current_document) < 256 && pb_membersize(google_firestore_v1beta1_WriteResult, update_time) < 256 && pb_membersize(google_firestore_v1beta1_DocumentChange, document) < 256 && pb_membersize(google_firestore_v1beta1_DocumentDelete, read_time) < 256 && pb_membersize(google_firestore_v1beta1_DocumentRemove, read_time) < 256), YOU_MUST_DEFINE_PB_FIELD_16BIT_FOR_MESSAGES_google_firestore_v1beta1_Write_google_firestore_v1beta1_DocumentTransform_google_firestore_v1beta1_DocumentTransform_FieldTransform_google_firestore_v1beta1_WriteResult_google_firestore_v1beta1_DocumentChange_google_firestore_v1beta1_DocumentDelete_google_firestore_v1beta1_DocumentRemove_google_firestore_v1beta1_ExistenceFilter)
#endif


/* @@protoc_insertion_point(eof) */
