// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "mojo/public/cpp/bindings/lib/validation_util.h"

#include <limits>

#include "mojo/public/cpp/bindings/lib/bindings_serialization.h"
#include "mojo/public/cpp/bindings/lib/validation_errors.h"

namespace mojo {
namespace internal {

bool ValidateEncodedPointer(const uint64_t* offset) {
  // - Make sure |*offset| is no more than 32-bits.
  // - Cast |offset| to uintptr_t so overflow behavior is well defined across
  //   32-bit and 64-bit systems.
  return *offset <= std::numeric_limits<uint32_t>::max() &&
         (reinterpret_cast<uintptr_t>(offset) +
              static_cast<uint32_t>(*offset) >=
          reinterpret_cast<uintptr_t>(offset));
}

bool ValidateStructHeaderAndClaimMemory(const void* data,
                                        BoundsChecker* bounds_checker) {
  if (!IsAligned(data)) {
    ReportValidationError(ValidationError::MISALIGNED_OBJECT);
    return false;
  }
  if (!bounds_checker->IsValidRange(data, sizeof(StructHeader))) {
    ReportValidationError(ValidationError::ILLEGAL_MEMORY_RANGE);
    return false;
  }

  const StructHeader* header = static_cast<const StructHeader*>(data);

  if (header->num_bytes < sizeof(StructHeader)) {
    ReportValidationError(ValidationError::UNEXPECTED_STRUCT_HEADER);
    return false;
  }

  if (!bounds_checker->ClaimMemory(data, header->num_bytes)) {
    ReportValidationError(ValidationError::ILLEGAL_MEMORY_RANGE);
    return false;
  }

  return true;
}

}  // namespace internal
}  // namespace mojo
