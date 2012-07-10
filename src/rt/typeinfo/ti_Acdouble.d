/**
 * TypeInfo support code.
 *
 * Copyright: Copyright Digital Mars 2004 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright
 */

/*          Copyright Digital Mars 2004 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.typeinfo.ti_Acdouble;

private import rt.typeinfo.ti_cdouble;
private import rt.util.hash;

// cdouble[]

class TypeInfo_Ar : TypeInfo_Array
{
    override equals_t opEquals(const Object o) const { return TypeInfo.opEquals(o); }

    @trusted:
    const:
    pure:
    nothrow:

    override string toString() const pure nothrow @safe { return "cdouble[]"; }

    override hash_t getHash(in void* p)
    {
        cdouble[] s = *cast(cdouble[]*)p;
        return hashOf(s.ptr, s.length * cdouble.sizeof);
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        cdouble[] s1 = *cast(cdouble[]*)p1;
        cdouble[] s2 = *cast(cdouble[]*)p2;
        size_t len = s1.length;

        if (len != s2.length)
            return false;
        for (size_t u = 0; u < len; u++)
        {
            if (!TypeInfo_r._equals(s1[u], s2[u]))
                return false;
        }
        return true;
    }

    override int compare(in void* p1, in void* p2)
    {
        cdouble[] s1 = *cast(cdouble[]*)p1;
        cdouble[] s2 = *cast(cdouble[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            int c = TypeInfo_r._compare(s1[u], s2[u]);
            if (c)
                return c;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    override @property const(TypeInfo) next() nothrow pure
    {
        return typeid(cdouble);
    }
}
