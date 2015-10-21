// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "mojo/public/cpp/bindings/lib/message_validation.h"

#include "mojo/public/cpp/bindings/lib/validation_errors.h"
#include "mojo/public/cpp/bindings/message.h"

namespace mojo {
namespace internal {

bool ValidateMessageIsRequestWithoutResponse(const Message* message) {
  if (message->has_flag(kMessageIsResponse) ||
      message->has_flag(kMessageExpectsResponse)) {
    ReportValidationError(VALIDATION_ERROR_MESSAGE_HEADER_INVALID_FLAGS);
    return false;
  }
  return true;
}

bool ValidateMessageIsRequestExpectingResponse(const Message* message) {
  if (message->has_flag(kMessageIsResponse) ||
      !message->has_flag(kMessageExpectsResponse)) {
    ReportValidationError(VALIDATION_ERROR_MESSAGE_HEADER_INVALID_FLAGS);
    return false;
  }
  return true;
}

bool ValidateMessageIsResponse(const Message* message) {
  if (message->has_flag(kMessageExpectsResponse) ||
      !message->has_flag(kMessageIsResponse)) {
    ReportValidationError(VALIDATION_ERROR_MESSAGE_HEADER_INVALID_FLAGS);
    return false;
  }
  return true;
}

}  // namespace internal
}  // namespace mojo
