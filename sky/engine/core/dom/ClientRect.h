/*
 * Copyright (C) 2009 Apple Inc. All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#ifndef SKY_ENGINE_CORE_DOM_CLIENTRECT_H_
#define SKY_ENGINE_CORE_DOM_CLIENTRECT_H_

#include "sky/engine/tonic/dart_wrappable.h"
#include "sky/engine/platform/geometry/FloatRect.h"
#include "sky/engine/platform/heap/Handle.h"
#include "sky/engine/wtf/PassRefPtr.h"
#include "sky/engine/wtf/RefCounted.h"

namespace blink {

class IntRect;

class ClientRect final : public RefCounted<ClientRect>, public DartWrappable {
    DEFINE_WRAPPERTYPEINFO();
public:
    static PassRefPtr<ClientRect> create()
    {
        return adoptRef(new ClientRect);
    }
    static PassRefPtr<ClientRect> create(const IntRect& rect)
    {
        return adoptRef(new ClientRect(rect));
    }
    static PassRefPtr<ClientRect> create(const FloatRect& rect)
    {
        return adoptRef(new ClientRect(rect));
    }

    float top() const { return m_rect.y(); }
    float right() const { return m_rect.maxX(); }
    float bottom() const { return m_rect.maxY(); }
    float left() const { return m_rect.x(); }
    float width() const { return m_rect.width(); }
    float height() const { return m_rect.height(); }

private:
    ClientRect();
    explicit ClientRect(const IntRect&);
    explicit ClientRect(const FloatRect&);

    FloatRect m_rect;
};

} // namespace blink

#endif  // SKY_ENGINE_CORE_DOM_CLIENTRECT_H_
