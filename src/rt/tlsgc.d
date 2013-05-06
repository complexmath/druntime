/**
 *
 * Copyright: Copyright Digital Mars 2011 - 2012.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Martin Nowak
 */

/*          Copyright Digital Mars 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.tlsgc;

import core.stdc.stdlib;

static import rt.lifetime, rt.sections;

/**
 * Per thread record to store thread associated data for garbage collection.
 */
struct Data
{
    typeof(rt.sections.initTLSRanges()) tlsRanges;
    rt.lifetime.BlkInfo** blockInfoCache;
}

/**
 * Initialization hook, called FROM each thread. No assumptions about
 * module initialization state should be made.
 */
extern (C) void* rt_attachTLS()
{
    auto data = cast(Data*).malloc(Data.sizeof);

    *data = Data.init;
    data.tlsRanges = rt.sections.initTLSRanges();
    data.blockInfoCache = &rt.lifetime.__blkcache_storage;
    return data;
}

/**
 * Finalization hook, called FOR each thread. No assumptions about
 * module initialization state should be made.
 */
extern (C) void rt_detachTLS(void* key)
{
    if (key !is null)
    {
        Data *data = cast(Data*) key;
        rt.sections.finiTLSRanges(data.tlsRanges);
        .free(data);
    }
}

alias void delegate(void* pstart, void* pend) ScanDg;

/**
 * GC scan hook, called FOR each thread. Can be used to scan
 * additional thread local memory.
 */
extern (C) void rt_scanTLS(void* key, scope ScanDg dg)
{
    if (key !is null)
    {
        Data* data = cast(Data*) key;
        rt.sections.scanTLSRanges(data.tlsRanges, dg);
    }
}

alias int delegate(void* addr) IsMarkedDg;

/**
 * GC sweep hook, called FOR each thread. Can be used to free
 * additional thread local memory or associated data structures. Note
 * that only memory allocated from the GC can have marks.
 */
extern (C) void rt_processGCMarks(void* key, scope IsMarkedDg dg)
{
    if (key !is null)
    {
        Data* data = cast(Data*) key;
        rt.lifetime.processGCMarks(*data.blockInfoCache, dg);
    }
}
