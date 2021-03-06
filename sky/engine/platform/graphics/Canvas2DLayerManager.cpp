/*
Copyright (C) 2012 Google Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1.  Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
2.  Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
#include "sky/engine/config.h"

#include "sky/engine/platform/graphics/Canvas2DLayerManager.h"

#include "sky/engine/public/platform/Platform.h"
#include "sky/engine/wtf/StdLibExtras.h"

namespace {

enum {
    DefaultMaxBytesAllocated = 64*1024*1024,
    DefaultTargetBytesAllocated = 16*1024*1024,
};

} // unnamed namespace

namespace blink {

Canvas2DLayerManager::Canvas2DLayerManager()
    : m_bytesAllocated(0)
    , m_maxBytesAllocated(DefaultMaxBytesAllocated)
    , m_targetBytesAllocated(DefaultTargetBytesAllocated)
    , m_limitPendingFramesTimer(this, &Canvas2DLayerManager::limitPendingFramesTimerFired)
{
}

Canvas2DLayerManager::~Canvas2DLayerManager()
{
    ASSERT(!m_bytesAllocated);
    ASSERT(!m_layerList.head());
}

void Canvas2DLayerManager::init(size_t maxBytesAllocated, size_t targetBytesAllocated)
{
    ASSERT(maxBytesAllocated >= targetBytesAllocated);
    m_maxBytesAllocated = maxBytesAllocated;
    m_targetBytesAllocated = targetBytesAllocated;
    if (m_limitPendingFramesTimer.isActive())
        m_limitPendingFramesTimer.stop();
}

Canvas2DLayerManager& Canvas2DLayerManager::get()
{
    DEFINE_STATIC_LOCAL(Canvas2DLayerManager, manager, ());
    return manager;
}

void Canvas2DLayerManager::limitPendingFramesTimerFired(Timer<Canvas2DLayerManager>*)
{
    Canvas2DLayerBridge* layer = m_layerList.head();
    while (layer) {
        Canvas2DLayerBridge* currentLayer = layer;
        // must increment iterator before calling limitPendingFrames, which
        // may result in the layer being removed from the list.
        layer = layer->next();
        currentLayer->limitPendingFrames();
    }
}

void Canvas2DLayerManager::layerDidDraw(Canvas2DLayerBridge* layer)
{
    if (isInList(layer)) {
        if (layer != m_layerList.head()) {
            m_layerList.remove(layer);
            m_layerList.push(layer); // Set as MRU
        }
    }

    if (!m_limitPendingFramesTimer.isActive())
        m_limitPendingFramesTimer.startOneShot(0, FROM_HERE);
}

void Canvas2DLayerManager::layerTransientResourceAllocationChanged(Canvas2DLayerBridge* layer, intptr_t deltaBytes)
{
    ASSERT((intptr_t)m_bytesAllocated + deltaBytes >= 0);
    m_bytesAllocated = (intptr_t)m_bytesAllocated + deltaBytes;
    if (!isInList(layer) && layer->hasTransientResources()) {
        m_layerList.push(layer);
    } else if (isInList(layer) && !layer->hasTransientResources()) {
        m_layerList.remove(layer);
        layer->setNext(0);
        layer->setPrev(0);
    }

    if (deltaBytes > 0)
        freeMemoryIfNecessary();
}

void Canvas2DLayerManager::freeMemoryIfNecessary()
{
    if (m_bytesAllocated >= m_maxBytesAllocated) {
        // Pass 1: Free memory from caches
        Canvas2DLayerBridge* layer = m_layerList.tail(); // LRU
        while (layer && m_bytesAllocated > m_targetBytesAllocated) {
            Canvas2DLayerBridge* currentLayer = layer;
            layer = layer->prev();
            currentLayer->freeMemoryIfPossible(m_bytesAllocated - m_targetBytesAllocated);
            ASSERT(isInList(currentLayer) == currentLayer->hasTransientResources());
        }

        // Pass 2: Flush canvases
        layer = m_layerList.tail();
        while (m_bytesAllocated > m_targetBytesAllocated && layer) {
            Canvas2DLayerBridge* currentLayer = layer;
            layer = layer->prev();
            currentLayer->flush();
            currentLayer->freeMemoryIfPossible(m_bytesAllocated - m_targetBytesAllocated);
            ASSERT(isInList(currentLayer) == currentLayer->hasTransientResources());
        }
    }
}

bool Canvas2DLayerManager::isInList(Canvas2DLayerBridge* layer) const
{
    return layer->prev() || m_layerList.head() == layer;
}

} // namespace blink

