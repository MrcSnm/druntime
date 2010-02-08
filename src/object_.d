/**
 * Forms the symbols available to all D programs. Includes Object, which is
 * the root of the class object hierarchy.  This module is implicitly
 * imported.
 * Macros:
 *      WIKI = Object
 *
 * Copyright: Copyright Digital Mars 2000 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 *
 *          Copyright Digital Mars 2000 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

module object;

//debug=PRINTF;

private
{
    import core.stdc.string;
    import core.stdc.stdlib;
    import rt.util.hash;
    import rt.util.string;
    debug(PRINTF) import core.stdc.stdio;

    extern (C) void onOutOfMemoryError();
    extern (C) Object _d_newclass(TypeInfo_Class ci);
}

// NOTE: For some reason, this declaration method doesn't work
//       in this particular file (and this file only).  It must
//       be a DMD thing.
//alias typeof(int.sizeof)                    size_t;
//alias typeof(cast(void*)0 - cast(void*)0)   ptrdiff_t;

version(X86_64)
{
    alias ulong size_t;
    alias long  ptrdiff_t;
}
else
{
    alias uint  size_t;
    alias int   ptrdiff_t;
}

alias size_t hash_t;
alias bool equals_t;

alias immutable(char)[]  string;
alias immutable(wchar)[] wstring;
alias immutable(dchar)[] dstring;

/**
 * All D class objects inherit from Object.
 */
class Object
{
    /**
     * Convert Object to a human readable string.
     */
    string toString()
    {
        return this.classinfo.name;
    }

    /**
     * Compute hash function for Object.
     */
    hash_t toHash()
    {
        // BUG: this prevents a compacting GC from working, needs to be fixed
        return cast(hash_t)cast(void*)this;
    }

    /**
     * Compare with another Object obj.
     * Returns:
     *  $(TABLE
     *  $(TR $(TD this &lt; obj) $(TD &lt; 0))
     *  $(TR $(TD this == obj) $(TD 0))
     *  $(TR $(TD this &gt; obj) $(TD &gt; 0))
     *  )
     */
    int opCmp(Object o)
    {
        // BUG: this prevents a compacting GC from working, needs to be fixed
        //return cast(int)cast(void*)this - cast(int)cast(void*)o;

        throw new Exception("need opCmp for class " ~ this.classinfo.name);
        //return this !is o;
    }

    /**
     * Returns !=0 if this object does have the same contents as obj.
     */
    equals_t opEquals(Object o)
    {
        return this is o;
    }

    interface Monitor
    {
        void lock();
        void unlock();
    }

    /**
     * Create instance of class specified by classname.
     * The class must either have no constructors or have
     * a default constructor.
     * Returns:
     *   null if failed
     */
    static Object factory(string classname)
    {
        auto ci = TypeInfo_Class.find(classname);
        if (ci)
        {
            return ci.create();
        }
        return null;
    }
}

/************************
 * Returns true if lhs and rhs are equal.
 */
bool opEquals(Object lhs, Object rhs)
{
    // If aliased to the same object or both null => equal
    if (lhs is rhs) return true;

    // If either is null => non-equal
    if (lhs is null || rhs is null) return false;

    // If same exact type => one call to method opEquals
    if (typeid(lhs) == typeid(rhs)) return lhs.opEquals(rhs);

    // General case => symmetric calls to method opEquals
    return lhs.opEquals(rhs) && rhs.opEquals(lhs);
}

/**
 * Information about an interface.
 * When an object is accessed via an interface, an Interface* appears as the
 * first entry in its vtbl.
 */
struct Interface
{
    TypeInfo_Class   classinfo;  /// .classinfo for this interface (not for containing class)
    void*[]     vtbl;
    ptrdiff_t   offset;     /// offset to Interface 'this' from Object 'this'
}

/**
 * Runtime type information about a class. Can be retrieved for any class type
 * or instance by using the .classinfo property.
 * A pointer to this appears as the first entry in the class's vtbl[].
 */
alias TypeInfo_Class Classinfo;

/**
 * Array of pairs giving the offset and type information for each
 * member in an aggregate.
 */
struct OffsetTypeInfo
{
    size_t   offset;    /// Offset of member from start of object
    TypeInfo ti;        /// TypeInfo for this member
}

/**
 * Runtime type information about a type.
 * Can be retrieved for any type using a
 * <a href="../expression.html#typeidexpression">TypeidExpression</a>.
 */
class TypeInfo
{
    override hash_t toHash()
    {
        auto data = this.toString();
        return hashOf(data.ptr, data.length);
    }

    override int opCmp(Object o)
    {
        if (this is o)
            return 0;
        TypeInfo ti = cast(TypeInfo)o;
        if (ti is null)
            return 1;
        return dstrcmp(this.toString(), ti.toString());
    }

    override equals_t opEquals(Object o)
    {
        /* TypeInfo instances are singletons, but duplicates can exist
         * across DLL's. Therefore, comparing for a name match is
         * sufficient.
         */
        if (this is o)
            return true;
        TypeInfo ti = cast(TypeInfo)o;
        return ti && this.toString() == ti.toString();
    }

    /// Returns a hash of the instance of a type.
    hash_t getHash(in void* p) { return cast(hash_t)p; }

    /// Compares two instances for equality.
    equals_t equals(in void* p1, in void* p2) { return p1 == p2; }

    /// Compares two instances for &lt;, ==, or &gt;.
    int compare(in void* p1, in void* p2) { return 0; }

    /// Returns size of the type.
    size_t tsize() { return 0; }

    /// Swaps two instances of the type.
    void swap(void* p1, void* p2)
    {
        size_t n = tsize();
        for (size_t i = 0; i < n; i++)
        {
            byte t = (cast(byte *)p1)[i];
            (cast(byte*)p1)[i] = (cast(byte*)p2)[i];
            (cast(byte*)p2)[i] = t;
        }
    }

    /// Get TypeInfo for 'next' type, as defined by what kind of type this is,
    /// null if none.
    TypeInfo next() { return null; }

    /// Return default initializer, null if default initialize to 0
    void[] init() { return null; }

    /// Get flags for type: 1 means GC should scan for pointers
    uint flags() { return 0; }

    /// Get type information on the contents of the type; null if not available
    OffsetTypeInfo[] offTi() { return null; }
    /// Run the destructor on the object and all its sub-objects
    void destroy(void* p) {}
    /// Run the postblit on the object and all its sub-objects
    void postblit(void* p) {}
}

class TypeInfo_Typedef : TypeInfo
{
    override string toString() { return name; }

    override equals_t opEquals(Object o)
    {
        TypeInfo_Typedef c;
        return this is o ||
               ((c = cast(TypeInfo_Typedef)o) !is null &&
                this.name == c.name &&
                this.base == c.base);
    }

    override hash_t getHash(in void* p) { return base.getHash(p); }
    override equals_t equals(in void* p1, in void* p2) { return base.equals(p1, p2); }
    override int compare(in void* p1, in void* p2) { return base.compare(p1, p2); }
    override size_t tsize() { return base.tsize(); }
    override void swap(void* p1, void* p2) { return base.swap(p1, p2); }

    override TypeInfo next() { return base.next(); }
    override uint flags() { return base.flags(); }
    override void[] init() { return m_init.length ? m_init : base.init(); }

    TypeInfo base;
    string   name;
    void[]   m_init;
}

class TypeInfo_Enum : TypeInfo_Typedef
{

}

class TypeInfo_Pointer : TypeInfo
{
    override string toString() { return m_next.toString() ~ "*"; }

    override equals_t opEquals(Object o)
    {
        TypeInfo_Pointer c;
        return this is o ||
                ((c = cast(TypeInfo_Pointer)o) !is null &&
                 this.m_next == c.m_next);
    }

    override hash_t getHash(in void* p)
    {
        return cast(hash_t)*cast(void**)p;
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        return *cast(void**)p1 == *cast(void**)p2;
    }

    override int compare(in void* p1, in void* p2)
    {
        if (*cast(void**)p1 < *cast(void**)p2)
            return -1;
        else if (*cast(void**)p1 > *cast(void**)p2)
            return 1;
        else
            return 0;
    }

    override size_t tsize()
    {
        return (void*).sizeof;
    }

    override void swap(void* p1, void* p2)
    {
        void* tmp = *cast(void**)p1;
        *cast(void**)p1 = *cast(void**)p2;
        *cast(void**)p2 = tmp;
    }

    override TypeInfo next() { return m_next; }
    override uint flags() { return 1; }

    TypeInfo m_next;
}

class TypeInfo_Array : TypeInfo
{
    override string toString() { return value.toString() ~ "[]"; }

    override equals_t opEquals(Object o)
    {
        TypeInfo_Array c;
        return this is o ||
               ((c = cast(TypeInfo_Array)o) !is null &&
                this.value == c.value);
    }

    override hash_t getHash(in void* p)
    {
        void[] a = *cast(void[]*)p;
        return hashOf(a.ptr, a.length);
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        void[] a1 = *cast(void[]*)p1;
        void[] a2 = *cast(void[]*)p2;
        if (a1.length != a2.length)
            return false;
        size_t sz = value.tsize();
        for (size_t i = 0; i < a1.length; i++)
        {
            if (!value.equals(a1.ptr + i * sz, a2.ptr + i * sz))
                return false;
        }
        return true;
    }

    override int compare(in void* p1, in void* p2)
    {
        void[] a1 = *cast(void[]*)p1;
        void[] a2 = *cast(void[]*)p2;
        size_t sz = value.tsize();
        size_t len = a1.length;

        if (a2.length < len)
            len = a2.length;
        for (size_t u = 0; u < len; u++)
        {
            int result = value.compare(a1.ptr + u * sz, a2.ptr + u * sz);
            if (result)
                return result;
        }
        return cast(int)a1.length - cast(int)a2.length;
    }

    override size_t tsize()
    {
        return (void[]).sizeof;
    }

    override void swap(void* p1, void* p2)
    {
        void[] tmp = *cast(void[]*)p1;
        *cast(void[]*)p1 = *cast(void[]*)p2;
        *cast(void[]*)p2 = tmp;
    }

    TypeInfo value;

    override TypeInfo next()
    {
        return value;
    }

    override uint flags() { return 1; }
}

class TypeInfo_StaticArray : TypeInfo
{
    override string toString()
    {
        char[10] tmp = void;
        return cast(string)(value.toString() ~ "[" ~ tmp.intToString(len) ~ "]");
    }

    override equals_t opEquals(Object o)
    {
        TypeInfo_StaticArray c;
        return this is o ||
               ((c = cast(TypeInfo_StaticArray)o) !is null &&
                this.len == c.len &&
                this.value == c.value);
    }

    override hash_t getHash(in void* p)
    {
        size_t sz = value.tsize();
        hash_t hash = 0;
        for (size_t i = 0; i < len; i++)
            hash += value.getHash(p + i * sz);
        return hash;
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        size_t sz = value.tsize();

        for (size_t u = 0; u < len; u++)
        {
            if (!value.equals(p1 + u * sz, p2 + u * sz))
                return false;
        }
        return true;
    }

    override int compare(in void* p1, in void* p2)
    {
        size_t sz = value.tsize();

        for (size_t u = 0; u < len; u++)
        {
            int result = value.compare(p1 + u * sz, p2 + u * sz);
            if (result)
                return result;
        }
        return 0;
    }

    override size_t tsize()
    {
        return len * value.tsize();
    }

    override void swap(void* p1, void* p2)
    {
        void* tmp;
        size_t sz = value.tsize();
        ubyte[16] buffer;
        void* pbuffer;

        if (sz < buffer.sizeof)
            tmp = buffer.ptr;
        else
            tmp = pbuffer = (new void[sz]).ptr;

        for (size_t u = 0; u < len; u += sz)
        {   size_t o = u * sz;
            memcpy(tmp, p1 + o, sz);
            memcpy(p1 + o, p2 + o, sz);
            memcpy(p2 + o, tmp, sz);
        }
        if (pbuffer)
            delete pbuffer;
    }

    override void[] init() { return value.init(); }
    override TypeInfo next() { return value; }
    override uint flags() { return value.flags(); }

    override void destroy(void* p)
    {
        auto sz = value.tsize();
        p += sz * len;
        foreach (i; 0 .. len)
        {
            p -= sz;
            value.destroy(p);
        }
    }

    override void postblit(void* p)
    {
        auto sz = value.tsize();
        foreach (i; 0 .. len)
        {
            value.postblit(p);
            p += sz;
        }
    }

    TypeInfo value;
    size_t   len;
}

class TypeInfo_AssociativeArray : TypeInfo
{
    override string toString()
    {
        return cast(string)(next.toString() ~ "[" ~ key.toString() ~ "]");
    }

    override equals_t opEquals(Object o)
    {
        TypeInfo_AssociativeArray c;
        return this is o ||
                ((c = cast(TypeInfo_AssociativeArray)o) !is null &&
                 this.key == c.key &&
                 this.value == c.value);
    }

    // BUG: need to add the rest of the functions

    override size_t tsize()
    {
        return (char[int]).sizeof;
    }

    override TypeInfo next() { return value; }
    override uint flags() { return 1; }

    TypeInfo value;
    TypeInfo key;

    TypeInfo impl;
}

class TypeInfo_Function : TypeInfo
{
    override string toString()
    {
        return cast(string)(next.toString() ~ "()");
    }

    override equals_t opEquals(Object o)
    {
        TypeInfo_Function c;
        return this is o ||
                ((c = cast(TypeInfo_Function)o) !is null &&
                 this.next == c.next);
    }

    // BUG: need to add the rest of the functions

    override size_t tsize()
    {
        return 0;       // no size for functions
    }

    TypeInfo next;
}

class TypeInfo_Delegate : TypeInfo
{
    override string toString()
    {
        return cast(string)(next.toString() ~ " delegate()");
    }

    override equals_t opEquals(Object o)
    {
        TypeInfo_Delegate c;
        return this is o ||
                ((c = cast(TypeInfo_Delegate)o) !is null &&
                 this.next == c.next);
    }

    // BUG: need to add the rest of the functions

    override size_t tsize()
    {
        alias int delegate() dg;
        return dg.sizeof;
    }

    override uint flags() { return 1; }

    TypeInfo next;
}

class TypeInfo_Class : TypeInfo
{
    override string toString() { return info.name; }

    override equals_t opEquals(Object o)
    {
        TypeInfo_Class c;
        return this is o ||
                ((c = cast(TypeInfo_Class)o) !is null &&
                 this.info.name == c.classinfo.name);
    }

    override hash_t getHash(in void* p)
    {
        Object o = *cast(Object*)p;
        return o ? o.toHash() : 0;
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        Object o1 = *cast(Object*)p1;
        Object o2 = *cast(Object*)p2;

        return (o1 is o2) || (o1 && o1.opEquals(o2));
    }

    override int compare(in void* p1, in void* p2)
    {
        Object o1 = *cast(Object*)p1;
        Object o2 = *cast(Object*)p2;
        int c = 0;

        // Regard null references as always being "less than"
        if (o1 !is o2)
        {
            if (o1)
            {
                if (!o2)
                    c = 1;
                else
                    c = o1.opCmp(o2);
            }
            else
                c = -1;
        }
        return c;
    }

    override size_t tsize()
    {
        return Object.sizeof;
    }

    override uint flags() { return 1; }

    override OffsetTypeInfo[] offTi()
    {
        return m_offTi;
    }

    @property TypeInfo_Class info() { return this; }
    @property TypeInfo typeinfo() { return this; }

    byte[]      init;           /** class static initializer
                                 * (init.length gives size in bytes of class)
                                 */
    string      name;           /// class name
    void*[]     vtbl;           /// virtual function pointer table
    Interface[] interfaces;     /// interfaces this class implements
    TypeInfo_Class   base;           /// base class
    void*       destructor;
    void function(Object) classInvariant;
    uint        m_flags;
    //  1:                      // is IUnknown or is derived from IUnknown
    //  2:                      // has no possible pointers into GC memory
    //  4:                      // has offTi[] member
    //  8:                      // has constructors
    // 16:                      // has xgetMembers member
    // 32:                      // has typeinfo member
    void*       deallocator;
    OffsetTypeInfo[] m_offTi;
    void function(Object) defaultConstructor;   // default Constructor
    const(MemberInfo[]) function(in char[]) xgetMembers;

    /**
     * Search all modules for TypeInfo_Class corresponding to classname.
     * Returns: null if not found
     */
    static TypeInfo_Class find(in char[] classname)
    {
        foreach (m; ModuleInfo)
        {
	  if (m)
            //writefln("module %s, %d", m.name, m.localClasses.length);
            foreach (c; m.localClasses)
            {
                //writefln("\tclass %s", c.name);
                if (c.name == classname)
                    return c;
            }
        }
        return null;
    }

    /**
     * Create instance of Object represented by 'this'.
     */
    Object create()
    {
        if (m_flags & 8 && !defaultConstructor)
            return null;
        Object o = _d_newclass(this);
        if (m_flags & 8 && defaultConstructor)
        {
            defaultConstructor(o);
        }
        return o;
    }

    /**
     * Search for all members with the name 'name'.
     * If name[] is null, return all members.
     */
    const(MemberInfo[]) getMembers(in char[] name)
    {
        if (m_flags & 16 && xgetMembers)
            return xgetMembers(name);
        return null;
    }
}

alias TypeInfo_Class ClassInfo;

class TypeInfo_Interface : TypeInfo
{
    override string toString() { return info.name; }

    override equals_t opEquals(Object o)
    {
        TypeInfo_Interface c;
        return this is o ||
                ((c = cast(TypeInfo_Interface)o) !is null &&
                 this.info.name == c.classinfo.name);
    }

    override hash_t getHash(in void* p)
    {
        Interface* pi = **cast(Interface ***)*cast(void**)p;
        Object o = cast(Object)(*cast(void**)p - pi.offset);
        assert(o);
        return o.toHash();
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        Interface* pi = **cast(Interface ***)*cast(void**)p1;
        Object o1 = cast(Object)(*cast(void**)p1 - pi.offset);
        pi = **cast(Interface ***)*cast(void**)p2;
        Object o2 = cast(Object)(*cast(void**)p2 - pi.offset);

        return o1 == o2 || (o1 && o1.opCmp(o2) == 0);
    }

    override int compare(in void* p1, in void* p2)
    {
        Interface* pi = **cast(Interface ***)*cast(void**)p1;
        Object o1 = cast(Object)(*cast(void**)p1 - pi.offset);
        pi = **cast(Interface ***)*cast(void**)p2;
        Object o2 = cast(Object)(*cast(void**)p2 - pi.offset);
        int c = 0;

        // Regard null references as always being "less than"
        if (o1 != o2)
        {
            if (o1)
            {
                if (!o2)
                    c = 1;
                else
                    c = o1.opCmp(o2);
            }
            else
                c = -1;
        }
        return c;
    }

    override size_t tsize()
    {
        return Object.sizeof;
    }

    override uint flags() { return 1; }

    TypeInfo_Class info;
}

class TypeInfo_Struct : TypeInfo
{
    override string toString() { return name; }

    override equals_t opEquals(Object o)
    {
        TypeInfo_Struct s;
        return this is o ||
                ((s = cast(TypeInfo_Struct)o) !is null &&
                 this.name == s.name &&
                 this.init.length == s.init.length);
    }

    override hash_t getHash(in void* p)
    {
        assert(p);
        if (xtoHash)
        {
            debug(PRINTF) printf("getHash() using xtoHash\n");
            return (*xtoHash)(p);
        }
        else
        {
            debug(PRINTF) printf("getHash() using default hash\n");
            return hashOf(p, init.length);
        }
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        if (p1 == p2)
            return true;
        else if (!p1 || !p2)
            return false;
        else if (xopEquals)
            return (*xopEquals)(p1, p2);
        else
            // BUG: relies on the GC not moving objects
            return memcmp(p1, p2, init.length) == 0;
    }

    override int compare(in void* p1, in void* p2)
    {
        // Regard null references as always being "less than"
        if (p1 != p2)
        {
            if (p1)
            {
                if (!p2)
                    return true;
                else if (xopCmp)
                    return (*xopCmp)(p2, p1);
                else
                    // BUG: relies on the GC not moving objects
                    return memcmp(p1, p2, init.length);
            }
            else
                return -1;
        }
        return 0;
    }

    override size_t tsize()
    {
        return init.length;
    }

    override void[] init() { return m_init; }

    override uint flags() { return m_flags; }

    override void destroy(void* p)
    {
        if (xdtor)
            (*xdtor)(p);
    }

    override void postblit(void* p)
    {
        if (xpostblit)
            (*xpostblit)(p);
    }

    string name;
    void[] m_init;      // initializer; init.ptr == null if 0 initialize

    hash_t   function(in void*)           xtoHash;
    equals_t function(in void*, in void*) xopEquals;
    int      function(in void*, in void*) xopCmp;
    char[]   function(in void*)           xtoString;

    uint m_flags;

    const(MemberInfo[]) function(in char[]) xgetMembers;
    void function(void*)                    xdtor;
    void function(void*)                    xpostblit;
}

class TypeInfo_Tuple : TypeInfo
{
    TypeInfo[] elements;

    override string toString()
    {
        string s = "(";
        foreach (i, element; elements)
        {
            if (i)
                s ~= ',';
            s ~= element.toString();
        }
        s ~= ")";
        return s;
    }

    override equals_t opEquals(Object o)
    {
        if (this is o)
            return true;

        auto t = cast(TypeInfo_Tuple)o;
        if (t && elements.length == t.elements.length)
        {
            for (size_t i = 0; i < elements.length; i++)
            {
                if (elements[i] != t.elements[i])
                    return false;
            }
            return true;
        }
        return false;
    }

    override hash_t getHash(in void* p)
    {
        assert(0);
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        assert(0);
    }

    override int compare(in void* p1, in void* p2)
    {
        assert(0);
    }

    override size_t tsize()
    {
        assert(0);
    }

    override void swap(void* p1, void* p2)
    {
        assert(0);
    }

    override void destroy(void* p)
    {
        assert(0);
    }

    override void postblit(void* p)
    {
        assert(0);
    }
}

class TypeInfo_Const : TypeInfo
{
    override string toString()
    {
        return cast(string) ("const(" ~ base.toString() ~ ")");
    }

    override equals_t opEquals(Object o) { return base.opEquals(o); }
    override hash_t getHash(in void *p) { return base.getHash(p); }
    override equals_t equals(in void *p1, in void *p2) { return base.equals(p1, p2); }
    override int compare(in void *p1, in void *p2) { return base.compare(p1, p2); }
    override size_t tsize() { return base.tsize(); }
    override void swap(void *p1, void *p2) { return base.swap(p1, p2); }

    override TypeInfo next() { return base.next(); }
    override uint flags() { return base.flags(); }
    override void[] init() { return base.init(); }

    TypeInfo base;
}

class TypeInfo_Invariant : TypeInfo_Const
{
    override string toString()
    {
        return cast(string) ("immutable(" ~ base.toString() ~ ")");
    }
}

class TypeInfo_Shared : TypeInfo_Const
{
    override string toString()
    {
        return cast(string) ("shared(" ~ base.toString() ~ ")");
    }
}

class TypeInfo_Inout : TypeInfo_Const
{
    override string toString()
    {
        return cast(string) ("inout(" ~ base.toString() ~ ")");
    }
}

abstract class MemberInfo
{
    string name();
}

class MemberInfo_field : MemberInfo
{
    this(string name, TypeInfo ti, size_t offset)
    {
        m_name = name;
        m_typeinfo = ti;
        m_offset = offset;
    }

    override string name() { return m_name; }
    TypeInfo typeInfo() { return m_typeinfo; }
    size_t offset() { return m_offset; }

    string   m_name;
    TypeInfo m_typeinfo;
    size_t   m_offset;
}

class MemberInfo_function : MemberInfo
{
    this(string name, TypeInfo ti, void* fp, uint flags)
    {
        m_name = name;
        m_typeinfo = ti;
        m_fp = fp;
        m_flags = flags;
    }

    override string name() { return m_name; }
    TypeInfo typeInfo() { return m_typeinfo; }
    void* fp() { return m_fp; }
    uint flags() { return m_flags; }

    string   m_name;
    TypeInfo m_typeinfo;
    void*    m_fp;
    uint     m_flags;
}


///////////////////////////////////////////////////////////////////////////////
// Throwable
///////////////////////////////////////////////////////////////////////////////


class Throwable : Object
{
    interface TraceInfo
    {
        int opApply(int delegate(ref char[]));
    }

    string      msg;
    string      file;
    size_t      line;
    TraceInfo   info;
    Throwable   next;

    this(string msg, Throwable next = null)
    {
        this.msg = msg;
        this.next = next;
        this.info = traceContext();
    }

    this(string msg, string file, size_t line, Throwable next = null)
    {
        this(msg, next);
        this.file = file;
        this.line = line;
        this.info = traceContext();
    }

    override string toString()
    {
        char[10] tmp = void;
        char[]   buf;

        for (Throwable e = this; e !is null; e = e.next)
        {
            if (e.file)
            {
               buf ~= e.classinfo.name ~ "@" ~ e.file ~ "(" ~ tmp.intToString(e.line) ~ "): " ~ e.msg;
            }
            else
            {
               buf ~= e.classinfo.name ~ ": " ~ e.msg;
            }
            if (e.info)
            {
                buf ~= "\n----------------";
                foreach (t; e.info)
                    buf ~= "\n" ~ t;
            }
            if (e.next)
                buf ~= "\n";
        }
        return cast(string) buf;
    }
}


alias Throwable.TraceInfo function(void* ptr = null) TraceHandler;
private __gshared TraceHandler traceHandler = null;


/**
 * Overrides the default trace hander with a user-supplied version.
 *
 * Params:
 *  h = The new trace handler.  Set to null to use the default handler.
 */
extern (C) void  rt_setTraceHandler(TraceHandler h)
{
    traceHandler = h;
}


/**
 * This function will be called when an exception is constructed.  The
 * user-supplied trace handler will be called if one has been supplied,
 * otherwise no trace will be generated.
 *
 * Params:
 *  ptr = A pointer to the location from which to generate the trace, or null
 *        if the trace should be generated from within the trace handler
 *        itself.
 *
 * Returns:
 *  An object describing the current calling context or null if no handler is
 *  supplied.
 */
Throwable.TraceInfo traceContext(void* ptr = null)
{
    if (traceHandler is null)
        return null;
    return traceHandler(ptr);
}


class Exception : Throwable
{
    this(string msg, Throwable next = null)
    {
        super(msg, next);
    }

    this(string msg, string file, size_t line, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}


class Error : Throwable
{
    this(string msg, Throwable next = null)
    {
        super(msg, next);
    }

    this(string msg, string file, size_t line, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}


///////////////////////////////////////////////////////////////////////////////
// ModuleInfo
///////////////////////////////////////////////////////////////////////////////


enum
{
    MIctorstart  = 1,   // we've started constructing it
    MIctordone   = 2,   // finished construction
    MIstandalone = 4,   // module ctor does not depend on other module
                        // ctors being done first
    MItlsctor    = 8,
    MItlsdtor    = 0x10,
    MIctor       = 0x20,
    MIdtor       = 0x40,
    MIxgetMembers = 0x80,
    MIictor      = 0x100,
    MIunitTest   = 0x200,
    MIimportedModules = 0x400,
    MIlocalClasses = 0x800,
    MInew        = 0x80000000	// it's the "new" layout
}


struct ModuleInfo
{
    struct New
    {
	uint flags;
	uint index;			// index into _moduleinfo_array[]

	/* Order of appearance, depending on flags
	 * tlsctor
	 * tlsdtor
	 * xgetMembers
	 * ctor
	 * dtor
	 * ictor
	 * importedModules
	 * localClasses
	 * name
	 */
    }
    struct Old
    {
	string          name;
	ModuleInfo*[]    importedModules;
	TypeInfo_Class[]     localClasses;
	uint            flags;

	void function() ctor;       // module shared static constructor (order dependent)
	void function() dtor;       // module shared static destructor
	void function() unitTest;   // module unit tests

	void* xgetMembers;          // module getMembers() function

	void function() ictor;      // module shared static constructor (order independent)

	void function() tlsctor;	// module thread local static constructor (order dependent)
	void function() tlsdtor;	// module thread local static destructor

	uint index;			// index into _moduleinfo_array[]

	void*[1] reserved;          // for future expansion
    }

    union
    {
	New n;
	Old o;
    }

    @property isNew() { return n.flags & MInew; }

    @property uint index() { return isNew ? n.index : o.index; }
    @property void index(uint i) { if (isNew) n.index = i; else o.index = i; }

    @property uint flags() { return isNew ? n.flags : o.flags; }
    @property void flags(uint f) { if (isNew) n.flags = f; else o.flags = f; }

    @property void function() tlsctor()
    {
	if (isNew)
	{
	    if (n.flags & MItlsctor)
	    {
		size_t off = New.sizeof;
		return *cast(typeof(return)*)(cast(void*)(&this) + off);
	    }
	    return null;
	}
	else
	    return o.tlsctor;
    }

    @property void function() tlsdtor()
    {
	if (isNew)
	{
	    if (n.flags & MItlsdtor)
	    {
		size_t off = New.sizeof;
		if (n.flags & MItlsctor)
		    off += o.tlsctor.sizeof;
		return *cast(typeof(return)*)(cast(void*)(&this) + off);
	    }
	    return null;
	}
	else
	    return o.tlsdtor;
    }

    @property void* xgetMembers()
    {
	if (isNew)
	{
	    if (n.flags & MIxgetMembers)
	    {
		size_t off = New.sizeof;
		if (n.flags & MItlsctor)
		    off += o.tlsctor.sizeof;
		if (n.flags & MItlsdtor)
		    off += o.tlsdtor.sizeof;
		return *cast(typeof(return)*)(cast(void*)(&this) + off);
	    }
	    return null;
	}
	return o.xgetMembers;
    }

    @property void function() ctor()
    {
	if (isNew)
	{
	    if (n.flags & MIctor)
	    {
		size_t off = New.sizeof;
		if (n.flags & MItlsctor)
		    off += o.tlsctor.sizeof;
		if (n.flags & MItlsdtor)
		    off += o.tlsdtor.sizeof;
		if (n.flags & MIxgetMembers)
		    off += o.xgetMembers.sizeof;
		return *cast(typeof(return)*)(cast(void*)(&this) + off);
	    }
	    return null;
	}
	return o.ctor;
    }

    @property void function() dtor()
    {
	if (isNew)
	{
	    if (n.flags & MIdtor)
	    {
		size_t off = New.sizeof;
		if (n.flags & MItlsctor)
		    off += o.tlsctor.sizeof;
		if (n.flags & MItlsdtor)
		    off += o.tlsdtor.sizeof;
		if (n.flags & MIxgetMembers)
		    off += o.xgetMembers.sizeof;
		if (n.flags & MIctor)
		    off += o.ctor.sizeof;
		return *cast(typeof(return)*)(cast(void*)(&this) + off);
	    }
	    return null;
	}
	return o.ctor;
    }

    @property void function() ictor()
    {
	if (isNew)
	{
	    if (n.flags & MIictor)
	    {
		size_t off = New.sizeof;
		if (n.flags & MItlsctor)
		    off += o.tlsctor.sizeof;
		if (n.flags & MItlsdtor)
		    off += o.tlsdtor.sizeof;
		if (n.flags & MIxgetMembers)
		    off += o.xgetMembers.sizeof;
		if (n.flags & MIctor)
		    off += o.ctor.sizeof;
		if (n.flags & MIdtor)
		    off += o.ctor.sizeof;
		return *cast(typeof(return)*)(cast(void*)(&this) + off);
	    }
	    return null;
	}
	return o.ictor;
    }

    @property void function() unitTest()
    {
	if (isNew)
	{
	    if (n.flags & MIunitTest)
	    {
		size_t off = New.sizeof;
		if (n.flags & MItlsctor)
		    off += o.tlsctor.sizeof;
		if (n.flags & MItlsdtor)
		    off += o.tlsdtor.sizeof;
		if (n.flags & MIxgetMembers)
		    off += o.xgetMembers.sizeof;
		if (n.flags & MIctor)
		    off += o.ctor.sizeof;
		if (n.flags & MIdtor)
		    off += o.ctor.sizeof;
		if (n.flags & MIictor)
		    off += o.ictor.sizeof;
		return *cast(typeof(return)*)(cast(void*)(&this) + off);
	    }
	    return null;
	}
	return o.unitTest;
    }

    @property ModuleInfo*[] importedModules()
    {
	if (isNew)
	{
	    if (n.flags & MIimportedModules)
	    {
		size_t off = New.sizeof;
		if (n.flags & MItlsctor)
		    off += o.tlsctor.sizeof;
		if (n.flags & MItlsdtor)
		    off += o.tlsdtor.sizeof;
		if (n.flags & MIxgetMembers)
		    off += o.xgetMembers.sizeof;
		if (n.flags & MIctor)
		    off += o.ctor.sizeof;
		if (n.flags & MIdtor)
		    off += o.ctor.sizeof;
		if (n.flags & MIictor)
		    off += o.ictor.sizeof;
		if (n.flags & MIunitTest)
		    off += o.unitTest.sizeof;
		auto plength = cast(size_t*)(cast(void*)(&this) + off);
		ModuleInfo** pm = cast(ModuleInfo**)(plength + 1);
		return pm[0 .. *plength];
	    }
	    return null;
	}
	return o.importedModules;
    }

    @property TypeInfo_Class[] localClasses()
    {
	if (isNew)
	{
	    if (n.flags & MIlocalClasses)
	    {
		size_t off = New.sizeof;
		if (n.flags & MItlsctor)
		    off += o.tlsctor.sizeof;
		if (n.flags & MItlsdtor)
		    off += o.tlsdtor.sizeof;
		if (n.flags & MIxgetMembers)
		    off += o.xgetMembers.sizeof;
		if (n.flags & MIctor)
		    off += o.ctor.sizeof;
		if (n.flags & MIdtor)
		    off += o.ctor.sizeof;
		if (n.flags & MIictor)
		    off += o.ictor.sizeof;
		if (n.flags & MIunitTest)
		    off += o.unitTest.sizeof;
		if (n.flags & MIimportedModules)
		{
		    auto plength = cast(size_t*)(cast(void*)(&this) + off);
		    off += size_t.sizeof + *plength * plength.sizeof;
		}
		auto plength = cast(size_t*)(cast(void*)(&this) + off);
		TypeInfo_Class* pt = cast(TypeInfo_Class*)(plength + 1);
		return pt[0 .. *plength];
	    }
	    return null;
	}
	return o.localClasses;
    }

    @property string name()
    {
	if (isNew)
	{
	    size_t off = New.sizeof;
	    if (n.flags & MItlsctor)
		off += o.tlsctor.sizeof;
	    if (n.flags & MItlsdtor)
		off += o.tlsdtor.sizeof;
	    if (n.flags & MIxgetMembers)
		off += o.xgetMembers.sizeof;
	    if (n.flags & MIctor)
		off += o.ctor.sizeof;
	    if (n.flags & MIdtor)
		off += o.ctor.sizeof;
	    if (n.flags & MIictor)
		off += o.ictor.sizeof;
	    if (n.flags & MIunitTest)
		off += o.unitTest.sizeof;
	    if (n.flags & MIimportedModules)
	    {
		auto plength = cast(size_t*)(cast(void*)(&this) + off);
		off += size_t.sizeof + *plength * plength.sizeof;
	    }
	    if (n.flags & MIlocalClasses)
	    {
		auto plength = cast(size_t*)(cast(void*)(&this) + off);
		off += size_t.sizeof + *plength * plength.sizeof;
	    }
	    auto p = cast(immutable(char)*)(cast(void*)(&this) + off);
	    auto len = strlen(p);
	    return p[0 .. len];
	}
	return o.name;
    }


    static int opApply(int delegate(ref ModuleInfo*) dg)
    {
        int ret = 0;

        foreach (m; _moduleinfo_array)
        {
            ret = dg(m);
            if (ret)
                break;
        }
        return ret;
    }
}


// Windows: this gets initialized by minit.asm
// Posix: this gets initialized in _moduleCtor()
extern (C) __gshared ModuleInfo*[] _moduleinfo_array;


version (linux)
{
    // This linked list is created by a compiler generated function inserted
    // into the .ctor list by the compiler.
    struct ModuleReference
    {
        ModuleReference* next;
        ModuleInfo*      mod;
    }

    extern (C) __gshared ModuleReference* _Dmodule_ref;   // start of linked list
}

version (FreeBSD)
{
    // This linked list is created by a compiler generated function inserted
    // into the .ctor list by the compiler.
    struct ModuleReference
    {
        ModuleReference* next;
        ModuleInfo*      mod;
    }

    extern (C) __gshared ModuleReference* _Dmodule_ref;   // start of linked list
}

version (Solaris)
{
    // This linked list is created by a compiler generated function inserted
    // into the .ctor list by the compiler.
    struct ModuleReference
    {
        ModuleReference* next;
        ModuleInfo*      mod;
    }

    extern (C) __gshared ModuleReference* _Dmodule_ref;   // start of linked list
}

version (OSX)
{
    extern (C)
    {
        extern __gshared void* _minfo_beg;
        extern __gshared void* _minfo_end;
    }
}

__gshared ModuleInfo*[] _moduleinfo_dtors;
__gshared uint          _moduleinfo_dtors_i;

ModuleInfo*[] _moduleinfo_tlsdtors;
uint          _moduleinfo_tlsdtors_i;

// Register termination function pointers
extern (C) int _fatexit(void*);

/**
 * Initialize the modules.
 */

extern (C) void _moduleCtor()
{
    debug(PRINTF) printf("_moduleCtor()\n");
    version (linux)
    {
        int len = 0;
        ModuleReference *mr;

        for (mr = _Dmodule_ref; mr; mr = mr.next)
            len++;
        _moduleinfo_array = new ModuleInfo*[len];
        len = 0;
        for (mr = _Dmodule_ref; mr; mr = mr.next)
        {   _moduleinfo_array[len] = mr.mod;
            len++;
        }
    }

    version (FreeBSD)
    {
        int len = 0;
        ModuleReference *mr;

        for (mr = _Dmodule_ref; mr; mr = mr.next)
            len++;
        _moduleinfo_array = new ModuleInfo*[len];
        len = 0;
        for (mr = _Dmodule_ref; mr; mr = mr.next)
        {   _moduleinfo_array[len] = mr.mod;
            len++;
        }
    }

    version (Solaris)
    {
        int len = 0;
        ModuleReference *mr;

        for (mr = _Dmodule_ref; mr; mr = mr.next)
            len++;
        _moduleinfo_array = new ModuleInfo*[len];
        len = 0;
        for (mr = _Dmodule_ref; mr; mr = mr.next)
        {   _moduleinfo_array[len] = mr.mod;
            len++;
        }
    }

    version (OSX)
    {
        /* The ModuleInfo references are stored in the special segment
         * __minfodata, which is bracketed by the segments __minfo_beg
         * and __minfo_end. The variables _minfo_beg and _minfo_end
         * are of zero size and are in the two bracketing segments,
         * respectively.
         */
         size_t length = cast(ModuleInfo**)&_minfo_end - cast(ModuleInfo**)&_minfo_beg;
         _moduleinfo_array = (cast(ModuleInfo**)&_minfo_beg)[0 .. length];
         debug printf("moduleinfo: ptr = %p, length = %d\n", _moduleinfo_array.ptr, _moduleinfo_array.length);

         debug foreach (m; _moduleinfo_array)
         {
             //printf("\t%p\n", m);
             printf("\t%.*s\n", m.name);
         }
    }    

    version (Windows)
    {
        // Ensure module destructors also get called on program termination
        //_fatexit(&_STD_moduleDtor);
    }

    _moduleinfo_dtors = new ModuleInfo*[_moduleinfo_array.length];
    debug(PRINTF) printf("_moduleinfo_dtors = x%x\n", cast(void*)_moduleinfo_dtors);
    _moduleIndependentCtors();
    _moduleCtor2(_moduleinfo_array, 0);
    _moduleTlsCtor();
}

extern (C) void _moduleIndependentCtors()
{
    debug(PRINTF) printf("_moduleIndependentCtors()\n");
    foreach (m; _moduleinfo_array)
    {
        if (m && m.ictor)
        {
            (*m.ictor)();
        }
    }
}

/********************************************
 * Run static constructors for shared global data.
 */
void _moduleCtor2(ModuleInfo*[] mi, int skip)
{
    debug(PRINTF) printf("_moduleCtor2(): %d modules\n", mi.length);
    for (uint i = 0; i < mi.length; i++)
    {
        ModuleInfo* m = mi[i];

        debug(PRINTF) printf("\tmodule[%d] = %p\n", i, m);
        if (!m)
            continue;
        debug(PRINTF) printf("\tmodule[%d] = '%.*s'\n", i, m.name);
        if (m.flags & MIctordone)
            continue;
        debug(PRINTF) printf("\tmodule[%d] = '%.*s', m = x%x\n", i, m.name, m);

        if (m.ctor || m.dtor)
        {
            if (m.flags & MIctorstart)
            {   if (skip || m.flags & MIstandalone)
                    continue;
		throw new Exception("Cyclic dependency in module " ~ m.name);
            }

            m.flags = m.flags | MIctorstart;
            _moduleCtor2(m.importedModules, 0);
            if (m.ctor)
                (*m.ctor)();
            m.flags = (m.flags & ~MIctorstart) | MIctordone;

            // Now that construction is done, register the destructor
            //printf("\tadding module dtor x%x\n", m);
            assert(_moduleinfo_dtors_i < _moduleinfo_dtors.length);
            _moduleinfo_dtors[_moduleinfo_dtors_i++] = m;
        }
        else
        {
            m.flags = m.flags | MIctordone;
            _moduleCtor2(m.importedModules, 1);
        }
    }
}

/********************************************
 * Run static constructors for thread local global data.
 */

extern (C) void _moduleTlsCtor()
{
    debug(PRINTF) printf("_moduleTlsCtor()\n");

    void* p = alloca(_moduleinfo_array.length * ubyte.sizeof);
    auto flags = cast(ubyte[])p[0 .. _moduleinfo_array.length];
    flags[] = 0;

    foreach (i, m; _moduleinfo_array)
    {
	if (m)
	    m.index = i;
    }

    _moduleinfo_tlsdtors = new ModuleInfo*[_moduleinfo_array.length];

    void _moduleTlsCtor2(ModuleInfo*[] mi, int skip)
    {
	debug(PRINTF) printf("_moduleTlsCtor2(skip = %d): %d modules\n", skip, mi.length);
	foreach (i, m; mi)
	{
	    debug(PRINTF) printf("\tmodule[%d] = '%p'\n", i, m);
	    if (!m)
		continue;
	    debug(PRINTF) printf("\tmodule[%d] = '%.*s'\n", i, m.name);
	    if (flags[m.index] & MIctordone)
		continue;
	    debug(PRINTF) printf("\tmodule[%d] = '%.*s', m = x%x\n", i, m.name, m);

	    if (m.tlsctor || m.tlsdtor)
	    {
		if (flags[m.index] & MIctorstart)
		{   if (skip || m.flags & MIstandalone)
			continue;
		    throw new Exception("Cyclic dependency in module " ~ m.name);
		}

		flags[m.index] |= MIctorstart;
		_moduleTlsCtor2(m.importedModules, 0);
		if (m.tlsctor)
		    (*m.tlsctor)();
		flags[m.index] &= ~MIctorstart;
		flags[m.index] |= MIctordone;

		// Now that construction is done, register the destructor
		//printf("**** adding module tlsdtor %p, [%d]\n", m, _moduleinfo_tlsdtors_i);
		assert(_moduleinfo_tlsdtors_i < _moduleinfo_tlsdtors.length);
		_moduleinfo_tlsdtors[_moduleinfo_tlsdtors_i++] = m;
	    }
	    else
	    {
		flags[m.index] |= MIctordone;
		_moduleTlsCtor2(m.importedModules, 1);
	    }
	}
    }

    _moduleTlsCtor2(_moduleinfo_array, 0);
}


/**
 * Destruct the modules.
 */

// Starting the name with "_STD" means under Posix a pointer to the
// function gets put in the .dtors segment.

extern (C) void _moduleDtor()
{
    debug(PRINTF) printf("_moduleDtor(): %d modules\n", _moduleinfo_dtors_i);

    _moduleTlsDtor();
    for (uint i = _moduleinfo_dtors_i; i-- != 0;)
    {
        ModuleInfo* m = _moduleinfo_dtors[i];

        debug(PRINTF) printf("\tmodule[%d] = '%.*s', x%x\n", i, m.name, m);
        if (m.dtor)
        {
            (*m.dtor)();
        }
    }
    debug(PRINTF) printf("_moduleDtor() done\n");
}

extern (C) void _moduleTlsDtor()
{
    debug(PRINTF) printf("_moduleTlsDtor(): %d modules\n", _moduleinfo_tlsdtors_i);
    version(none)
    {
        printf("_moduleinfo_tlsdtors = %d,%p\n", _moduleinfo_tlsdtors);
        foreach (i,m; _moduleinfo_tlsdtors[0..11])
            printf("[%d] = %p\n", i, m);
    }

    for (uint i = _moduleinfo_tlsdtors_i; i-- != 0;)
    {
        ModuleInfo* m = _moduleinfo_tlsdtors[i];

        debug(PRINTF) printf("\tmodule[%d] = '%.*s', x%x\n", i, m.name, m);
        if (m.tlsdtor)
        {
            (*m.tlsdtor)();
        }
    }
    debug(PRINTF) printf("_moduleTlsDtor() done\n");
}

// Alias the TLS ctor and dtor using "rt_" prefixes, since these routines
// must be called by core.thread.

extern (C) void rt_moduleTlsCtor()
{
    _moduleTlsCtor();
}

extern (C) void rt_moduleTlsDtor()
{
    _moduleTlsDtor();
}

///////////////////////////////////////////////////////////////////////////////
// Monitor
///////////////////////////////////////////////////////////////////////////////

alias Object.Monitor        IMonitor;
alias void delegate(Object) DEvent;

// NOTE: The dtor callback feature is only supported for monitors that are not
//       supplied by the user.  The assumption is that any object with a user-
//       supplied monitor may have special storage or lifetime requirements and
//       that as a result, storing references to local objects within Monitor
//       may not be safe or desirable.  Thus, devt is only valid if impl is
//       null.
struct Monitor
{
    IMonitor impl;
    /* internal */
    DEvent[] devt;
    /* stuff */
}

Monitor* getMonitor(Object h)
{
    return cast(Monitor*) (cast(void**) h)[1];
}

void setMonitor(Object h, Monitor* m)
{
    (cast(void**) h)[1] = m;
}

extern (C) void _d_monitor_create(Object);
extern (C) void _d_monitor_destroy(Object);
extern (C) void _d_monitor_lock(Object);
extern (C) int  _d_monitor_unlock(Object);

extern (C) void _d_monitordelete(Object h, bool det)
{
    Monitor* m = getMonitor(h);

    if (m !is null)
    {
        IMonitor i = m.impl;
        if (i is null)
        {
            _d_monitor_devt(m, h);
            _d_monitor_destroy(h);
            setMonitor(h, null);
            return;
        }
        if (det && (cast(void*) i) !is (cast(void*) h))
            delete i;
        setMonitor(h, null);
    }
}

extern (C) void _d_monitorenter(Object h)
{
    Monitor* m = getMonitor(h);

    if (m is null)
    {
        _d_monitor_create(h);
        m = getMonitor(h);
    }

    IMonitor i = m.impl;

    if (i is null)
    {
        _d_monitor_lock(h);
        return;
    }
    i.lock();
}

extern (C) void _d_monitorexit(Object h)
{
    Monitor* m = getMonitor(h);
    IMonitor i = m.impl;

    if (i is null)
    {
        _d_monitor_unlock(h);
        return;
    }
    i.unlock();
}

extern (C) void _d_monitor_devt(Monitor* m, Object h)
{
    if (m.devt.length)
    {
        DEvent[] devt;

        synchronized (h)
        {
            devt = m.devt;
            m.devt = null;
        }
        foreach (v; devt)
        {
            if (v)
                v(h);
        }
        free(devt.ptr);
    }
}

extern (C) void rt_attachDisposeEvent(Object h, DEvent e)
{
    synchronized (h)
    {
        Monitor* m = getMonitor(h);
        assert(m.impl is null);

        foreach (ref v; m.devt)
        {
            if (v is null || v == e)
            {
                v = e;
                return;
            }
        }

        auto len = m.devt.length + 4; // grow by 4 elements
        auto pos = m.devt.length;     // insert position
        auto p = realloc(m.devt.ptr, DEvent.sizeof * len);
        if (!p)
            onOutOfMemoryError();
        m.devt = (cast(DEvent*)p)[0 .. len];
        m.devt[pos+1 .. len] = null;
        m.devt[pos] = e;
    }
}

extern (C) void rt_detachDisposeEvent(Object h, DEvent e)
{
    synchronized (h)
    {
        Monitor* m = getMonitor(h);
        assert(m.impl is null);

        foreach (p, v; m.devt)
        {
            if (v == e)
            {
                memmove(&m.devt[p],
                        &m.devt[p+1],
                        (m.devt.length - p - 1) * DEvent.sizeof);
                m.devt[$ - 1] = null;
                return;
            }
        }
    }
}

extern (C)
{
    // from druntime/src/compiler/dmd/aaA.d

    size_t _aaLen(void* p);
    void* _aaGet(void** pp, TypeInfo keyti, size_t valuesize, ...);
    void* _aaGetRvalue(void* p, TypeInfo keyti, size_t valuesize, ...);
    void* _aaIn(void* p, TypeInfo keyti);
    void _aaDel(void* p, TypeInfo keyti, ...);
    void[] _aaValues(void* p, size_t keysize, size_t valuesize);
    void[] _aaKeys(void* p, size_t keysize, size_t valuesize);
    void* _aaRehash(void** pp, TypeInfo keyti);

    extern (D) typedef int delegate(void *) _dg_t;
    int _aaApply(void* aa, size_t keysize, _dg_t dg);

    extern (D) typedef int delegate(void *, void *) _dg2_t;
    int _aaApply2(void* aa, size_t keysize, _dg2_t dg);

    void* _d_assocarrayliteralT(TypeInfo_AssociativeArray ti, size_t length, ...);
}

struct AssociativeArray(Key, Value)
{
    void* p;

    size_t length() @property { return _aaLen(p); }

    Value[Key] rehash() @property
    {
        auto p = _aaRehash(&p, typeid(Value[Key]));
        return *cast(Value[Key]*)(&p);
    }

    Value[] values() @property
    {
        auto a = _aaValues(p, Key.sizeof, Value.sizeof);
        return *cast(Value[]*) &a;
    }

    Key[] keys() @property
    {
        auto a = _aaKeys(p, Key.sizeof, Value.sizeof);
        return *cast(Key[]*) &a;
    }

    int opApply(int delegate(ref Key, ref Value) dg)
    {
        return _aaApply2(p, Key.sizeof, cast(_dg2_t)dg);
    }

    int opApply(int delegate(ref Value) dg)
    {
        return _aaApply(p, Key.sizeof, cast(_dg_t)dg);
    }
}


void clear(T)(T obj) if (is(T == class))
{
    auto defaultCtor =
        cast(void function(Object)) obj.classinfo.defaultConstructor;
    version(none) // enforce isn't available in druntime
        _enforce(defaultCtor || (obj.classinfo.flags & 8) == 0);
    immutable size = obj.classinfo.init.length;
    static if (is(typeof(obj.__dtor())))
    {
        obj.__dtor();
    }
    auto buf = (cast(void*) obj)[0 .. size];
    buf[] = obj.classinfo.init;
    if (defaultCtor)
        defaultCtor(obj);
}

version(unittest) unittest
{
   {
       class A { string s = "A"; this() {} }
       auto a = new A;
       a.s = "asd";
       clear(a);
       assert(a.s == "A");
   }
   {
       static bool destroyed = false;
       class B
       {
           string s = "B";
           this() {}
           ~this()
           {
               destroyed = true;
           }
       }
       auto a = new B;
       a.s = "asd";
       clear(a);
       assert(destroyed);
       assert(a.s == "B");
   }
   {
       class C
       {
           string s;
           this()
           {
               s = "C";
           }
       }
       auto a = new C;
       a.s = "asd";
       clear(a);
       assert(a.s == "C");
   }
}

void clear(T)(ref T obj) if (is(T == struct))
{
   static if (is(typeof(obj.__dtor())))
   {
       obj.__dtor();
   }
   auto buf = (cast(void*) &obj)[0 .. T.sizeof];
   auto init = (cast(void*) &T.init)[0 .. T.sizeof];
   buf[] = init[];
}

version(unittest) unittest
{
   {
       struct A { string s = "A";  }
       A a;
       a.s = "asd";
       clear(a);
       assert(a.s == "A");
   }
   {
       static bool destroyed = false;
       struct B
       {
           string s = "B";
           ~this()
           {
               destroyed = true;
           }
       }
       B a;
       a.s = "asd";
       clear(a);
       assert(destroyed);
       assert(a.s == "B");
   }
}

void clear(T : U[n], U, size_t n)(/*ref*/ T obj)
{
    obj = T.init;
}

version(unittest) unittest
{
    int[2] a;
    a[0] = 1;
    a[1] = 2;
    clear(a);
    assert(a == [ 0, 0 ]);
}

void clear(T)(ref T obj)
    if (!is(T == struct) && !is(T == class) && !_isStaticArray!T)
{
    obj = T.init;
}

template _isStaticArray(T : U[N], U, size_t N)
{
    enum bool _isStaticArray = true;
}

template _isStaticArray(T)
{
    enum bool _isStaticArray = false;
}

version(unittest) unittest
{
   {
       int a = 42;
       clear(a);
       assert(a == 0);
   }
   {
       float a = 42;
       clear(a);
       assert(isnan(a));
   }
}

version (unittest)
{
    bool isnan(float x)
    {
        return x != x;
    }
}

version (none)
{
    // enforce() copied from Phobos std.contracts for clear(), left out until
    // we decide whether to use it.
    

    T _enforce(T, string file = __FILE__, int line = __LINE__)
        (T value, lazy const(char)[] msg = null)
    {
        if (!value) bailOut(file, line, msg);
        return value;
    }

    T _enforce(T, string file = __FILE__, int line = __LINE__)
        (T value, scope void delegate() dg)
    {
        if (!value) dg();
        return value;
    }

    T _enforce(T)(T value, lazy Exception ex)
    {
        if (!value) throw ex();
        return value;
    }

    private void _bailOut(string file, int line, in char[] msg)
    {
        char[21] buf;
        throw new Exception(cast(string)(file ~ "(" ~ intToString(buf[], line) ~ "): " ~ (msg ? msg : "Enforcement failed")));
    }
}