// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef MOJO_PUBLIC_CPP_BINDINGS_LIB_MESSAGE_VALIDATION_H_
#define MOJO_PUBLIC_CPP_BINDINGS_LIB_MESSAGE_VALIDATION_H_

#include "mojo/public/cpp/bindings/lib/bounds_checker.h"
#include "mojo/public/cpp/bindings/message.h"

namespace mojo {
namespace internal {

// Validates that the message is a request which doesn't expect a response.
bool ValidateMessageIsRequestWithoutResponse(const Message* message);
// Validates that the message is a request expecting a response.
bool ValidateMessageIsRequestExpectingResponse(const Message* message);
// Validates that the message is a response.
bool ValidateMessageIsResponse(const Message* message);

// Validates that the message payload is a valid struct of type ParamsType.
template <typename ParamsType>
bool ValidateMessagePayload(const Message* message) {
  BoundsChecker bounds_checker(message->payload(), message->payload_num_bytes(),
                               message->handles()->size());
  return ParamsType::Validate(message->payload(), &bounds_checker);
}

}  // namespace internal
}  // namespace mojo

#endif  // MOJO_PUBLIC_CPP_BINDINGS_LIB_MESSAGE_VALIDATION_H_
