module newadds;

import std.algorithm;
import std.range;
import std.string;
import std.traits;

/**
If $(D haystack) supports slicing, returns the smallest number $(D n)
such that $(D haystack[n .. $].startsWith!pred(needle)). Oherwise,
returns the smallest $(D n) such that after $(D n) calls to $(D
haystack.popFront), $(D haystack.startsWith!pred(needle)). If no such
number could be found, return $(D -1).
 */
sizediff_t countUntil(alias pred = "a == b", R1, Ranges...)(R1 haystack, Ranges needle)
if (is(typeof(startsWith!pred(haystack, needle))))
{
    static if (isNarrowString!R1)
    {
        // Narrow strings are handled a bit differently
        auto length = haystack.length;
        for (; !haystack.empty; haystack.popFront)
        {
            if (startsWith!pred(haystack, needle))
            {
                return length - haystack.length;
            }
        }
    }
    else
    {
        typeof(return) result;
        for (; !haystack.empty; ++result, haystack.popFront())
        {
            if (startsWith!pred(haystack, needle)) return result;
        }
    }
    return -1;
}
