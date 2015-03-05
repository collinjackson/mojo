/*
 * Copyright (C) 2011, 2012 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "sky/engine/config.h"
#include "sky/engine/core/css/CSSValuePool.h"

#include "sky/engine/core/css/CSSValueList.h"
#include "sky/engine/core/css/parser/BisonCSSParser.h"
#include "sky/engine/core/rendering/style/RenderStyle.h"

namespace blink {

CSSValuePool& cssValuePool()
{
    DEFINE_STATIC_LOCAL(OwnPtr<CSSValuePool>, pool, (adoptPtr(new CSSValuePool())));
    return *pool;
}

CSSValuePool::CSSValuePool()
    : m_inheritedValue(CSSInheritedValue::create())
    , m_implicitInitialValue(CSSInitialValue::createImplicit())
    , m_explicitInitialValue(CSSInitialValue::createExplicit())
    , m_colorTransparent(CSSPrimitiveValue::createColor(Color::transparent))
    , m_colorWhite(CSSPrimitiveValue::createColor(Color::white))
    , m_colorBlack(CSSPrimitiveValue::createColor(Color::black))
{
    m_identifierValueCache.resize(numCSSValueKeywords);
    m_pixelValueCache.resize(maximumCacheableIntegerValue + 1);
    m_percentValueCache.resize(maximumCacheableIntegerValue + 1);
    m_numberValueCache.resize(maximumCacheableIntegerValue + 1);
}

PassRefPtr<CSSPrimitiveValue> CSSValuePool::createIdentifierValue(CSSValueID ident)
{
    if (ident <= 0)
        return CSSPrimitiveValue::createIdentifier(ident);

    if (!m_identifierValueCache[ident])
        m_identifierValueCache[ident] = CSSPrimitiveValue::createIdentifier(ident);
    return m_identifierValueCache[ident];
}

PassRefPtr<CSSPrimitiveValue> CSSValuePool::createIdentifierValue(CSSPropertyID ident)
{
    return CSSPrimitiveValue::createIdentifier(ident);
}

PassRefPtr<CSSPrimitiveValue> CSSValuePool::createColorValue(unsigned rgbValue)
{
    // These are the empty and deleted values of the hash table.
    if (rgbValue == Color::transparent)
        return m_colorTransparent;
    if (rgbValue == Color::white)
        return m_colorWhite;
    // Just because it is common.
    if (rgbValue == Color::black)
        return m_colorBlack;

    // Just wipe out the cache and start rebuilding if it gets too big.
    const unsigned maximumColorCacheSize = 512;
    if (m_colorValueCache.size() > maximumColorCacheSize)
        m_colorValueCache.clear();

    RefPtr<CSSPrimitiveValue> dummyValue = nullptr;
    ColorValueCache::AddResult entry = m_colorValueCache.add(rgbValue, dummyValue);
    if (entry.isNewEntry)
        entry.storedValue->value = CSSPrimitiveValue::createColor(rgbValue);
    return entry.storedValue->value;
}

PassRefPtr<CSSPrimitiveValue> CSSValuePool::createValue(double value, CSSPrimitiveValue::UnitType type)
{
    if (std::isinf(value))
        value = 0;

    if (value < 0 || value > maximumCacheableIntegerValue)
        return CSSPrimitiveValue::create(value, type);

    int intValue = static_cast<int>(value);
    if (value != intValue)
        return CSSPrimitiveValue::create(value, type);

    switch (type) {
    case CSSPrimitiveValue::CSS_PX:
        if (!m_pixelValueCache[intValue])
            m_pixelValueCache[intValue] = CSSPrimitiveValue::create(value, type);
        return m_pixelValueCache[intValue];
    case CSSPrimitiveValue::CSS_PERCENTAGE:
        if (!m_percentValueCache[intValue])
            m_percentValueCache[intValue] = CSSPrimitiveValue::create(value, type);
        return m_percentValueCache[intValue];
    case CSSPrimitiveValue::CSS_NUMBER:
        if (!m_numberValueCache[intValue])
            m_numberValueCache[intValue] = CSSPrimitiveValue::create(value, type);
        return m_numberValueCache[intValue];
    default:
        return CSSPrimitiveValue::create(value, type);
    }
}

PassRefPtr<CSSPrimitiveValue> CSSValuePool::createValue(const Length& value, const RenderStyle& style)
{
    return CSSPrimitiveValue::create(value);
}

PassRefPtr<CSSPrimitiveValue> CSSValuePool::createFontFamilyValue(const String& familyName)
{
    RefPtr<CSSPrimitiveValue>& value = m_fontFamilyValueCache.add(familyName, nullptr).storedValue->value;
    if (!value)
        value = CSSPrimitiveValue::create(familyName, CSSPrimitiveValue::CSS_STRING);
    return value;
}

PassRefPtr<CSSValueList> CSSValuePool::createFontFaceValue(const AtomicString& string)
{
    // Just wipe out the cache and start rebuilding if it gets too big.
    const unsigned maximumFontFaceCacheSize = 128;
    if (m_fontFaceValueCache.size() > maximumFontFaceCacheSize)
        m_fontFaceValueCache.clear();

    RefPtr<CSSValueList>& value = m_fontFaceValueCache.add(string, nullptr).storedValue->value;
    if (!value)
        value = BisonCSSParser::parseFontFaceValue(string);
    return value;
}

}