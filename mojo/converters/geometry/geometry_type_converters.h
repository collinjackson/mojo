// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef MOJO_CONVERTERS_GEOMETRY_GEOMETRY_TYPE_CONVERTERS_H_
#define MOJO_CONVERTERS_GEOMETRY_GEOMETRY_TYPE_CONVERTERS_H_

#include "mojo/converters/geometry/mojo_geometry_export.h"
#include "mojo/services/geometry/public/interfaces/geometry.mojom.h"
#include "ui/gfx/geometry/point.h"
#include "ui/gfx/geometry/point_f.h"
#include "ui/gfx/geometry/rect.h"
#include "ui/gfx/geometry/size.h"
#include "ui/gfx/transform.h"

namespace mojo {

template <>
struct MOJO_GEOMETRY_EXPORT TypeConverter<PointPtr, gfx::Point> {
  static PointPtr Convert(const gfx::Point& input);
};
template <>
struct MOJO_GEOMETRY_EXPORT TypeConverter<gfx::Point, PointPtr> {
  static gfx::Point Convert(const PointPtr& input);
};

template <>
struct MOJO_GEOMETRY_EXPORT TypeConverter<PointFPtr, gfx::PointF> {
  static PointFPtr Convert(const gfx::PointF& input);
};
template <>
struct MOJO_GEOMETRY_EXPORT TypeConverter<gfx::PointF, PointFPtr> {
  static gfx::PointF Convert(const PointFPtr& input);
};

template <>
struct MOJO_GEOMETRY_EXPORT TypeConverter<SizePtr, gfx::Size> {
  static SizePtr Convert(const gfx::Size& input);
};
template <>
struct MOJO_GEOMETRY_EXPORT TypeConverter<gfx::Size, SizePtr> {
  static gfx::Size Convert(const SizePtr& input);
};

template <>
struct MOJO_GEOMETRY_EXPORT TypeConverter<RectPtr, gfx::Rect> {
  static RectPtr Convert(const gfx::Rect& input);
};
template <>
struct MOJO_GEOMETRY_EXPORT TypeConverter<gfx::Rect, RectPtr> {
  static gfx::Rect Convert(const RectPtr& input);
};

template <>
struct MOJO_GEOMETRY_EXPORT TypeConverter<RectFPtr, gfx::RectF> {
  static RectFPtr Convert(const gfx::RectF& input);
};
template <>
struct MOJO_GEOMETRY_EXPORT TypeConverter<gfx::RectF, RectFPtr> {
  static gfx::RectF Convert(const RectFPtr& input);
};

template <>
struct MOJO_GEOMETRY_EXPORT TypeConverter<TransformPtr, gfx::Transform> {
  static TransformPtr Convert(const gfx::Transform& input);
};
template <>
struct MOJO_GEOMETRY_EXPORT TypeConverter<gfx::Transform, TransformPtr> {
  static gfx::Transform Convert(const TransformPtr& input);
};

template <>
struct MOJO_GEOMETRY_EXPORT TypeConverter<Size, gfx::Size> {
  static Size Convert(const gfx::Size& input);
};
template <>
struct MOJO_GEOMETRY_EXPORT TypeConverter<gfx::Size, Size> {
  static gfx::Size Convert(const Size& input);
};

template <>
struct MOJO_GEOMETRY_EXPORT TypeConverter<Rect, gfx::Rect> {
  static Rect Convert(const gfx::Rect& input);
};
template <>
struct MOJO_GEOMETRY_EXPORT TypeConverter<gfx::Rect, Rect> {
  static gfx::Rect Convert(const Rect& input);
};

}  // namespace mojo

inline bool operator==(const mojo::Size& lhs, const mojo::Size& rhs) {
  return lhs.width == rhs.width && lhs.height == rhs.height;
}

inline bool operator==(const gfx::Size& lhs, const mojo::Size& rhs) {
  return lhs.width() == rhs.width && lhs.height() == rhs.height;
}

inline bool operator==(const mojo::Size& lhs, const gfx::Size& rhs) {
  return rhs == lhs;
}

inline bool operator!=(const mojo::Size& lhs, const mojo::Size& rhs) {
  return !(lhs == rhs);
}

inline bool operator!=(const gfx::Size& lhs, const mojo::Size& rhs) {
  return !(lhs == rhs);
}

inline bool operator!=(const mojo::Size& lhs, const gfx::Size& rhs) {
  return !(lhs == rhs);
}

#endif  // MOJO_CONVERTERS_GEOMETRY_GEOMETRY_TYPE_CONVERTERS_H_