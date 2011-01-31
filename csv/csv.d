/**
 * Written by Jesse Phillips
 *
 * License is Boost
 *
 * Example for integer data:
 *
 * -------
 * string str = `76,26,22`;
 * int[] ans = [76,26,22];
 * auto records = csvText!int(str);
 * 
 * int count;
 * foreach(record; records) {
 *  foreach(cell; record) {
 *      assert(ans[count] == cell);
 *      count++;
 *  }
 * }
 * -------
 * 
 * Example using a struct:
 * 
 * -------
 * string str = "Hello,65,63.63\nWorld,123,3673.562";
 * struct Layout {
 *  string name;
 *  int value;
 *  double other;
 * }
 * 
 * auto records = csvText!Layout(str);
 * 
 * foreach(record; records) {
 *  writeln(record.name);
 *  writeln(record.value);
 *  writeln(record.other);
 * }
 * -------
 */
module csv;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.range;
import std.stdio;
import std.traits;
import newadds;

/**
 * Builds a RecordList range for iterating over tokens found in data.
 * This function simplifies the process for standard text input.
 * For other data create RecordList yourself.
 *
 * -------
 * string str = `76,26,22`;
 * int[] ans = [76,26,22];
 * auto records = csvText!int(str);
 * 
 * int count;
 * foreach(record; records) {
 *  foreach(cell; record) {
 *      assert(ans[count] == cell);
 *      count++;
 *  }
 * }
 * -------
 *
 * Returns:
 *      If Contents is a struct or class, the range will return a
 *      struct/class populated by a single record.
 *
 *      Otherwise the range will return a Record range of the type.
 *
 * Throws:
 *       IncompleteCellToken When data is shown to not be complete.
 */
auto csvText(Contents = string,
             Malformed ErrorLevel = Malformed.throwException, Range)
            (Range data) if (isSomeString ! Range)
{
    return RecordList!(Contents, ErrorLevel, Range, string)
                      (data, ",", "\"", "\n");
}

auto csvText(Contents = string,
             Malformed ErrorLevel = Malformed.throwException, Range)
            (Range data, Range[] heading) if (isSomeString ! Range)
{
    return RecordList!(Contents, ErrorLevel, Range, string)
                      (data, ",", "\"", "\n", heading);
}

deprecated alias csvText csv;

// Test standard iteration over data.
unittest
{
    string str = `Hello,World,"Hi ""There""","",` ~ "\"It is\nme\"\nNot here";
    auto records = csvText(str);

    int count;
    foreach (record; records)
    {
        foreach (cell; record)
        {
            count++;
        }
    }
    assert(count == 6);
}

// Test structure conversion interface.
unittest
{
  string str = "Hello,65,63.63\nWorld,123,3673.562";
  struct Layout
  {
    string name;
    int value;
    double other;
  }
    Layout ans[2];
    ans[0].name = "Hello";
    ans[0].value = 65;
    ans[0].other = 63.63;
    ans[1].name = "World";
    ans[1].value = 123;
    ans[1].other = 3673.562;

    auto records = csvText!Layout(str);

    int count;
    foreach (record; records)
    {
        assert(ans[count].name == record.name);
        assert(ans[count].value == record.value);
        assert(ans[count].other == record.other);
        count++;
    }
    assert(count == 2);
}

// Test struct & header interface
unittest
{
    string str = "a,b,c\nHello,65,63.63\nWorld,123,3673.562";
    struct Layout
    {
        int value;
        double other;
        string name;
    }

    auto records = csvText!Layout(str, ["b","c","a"]);

    Layout ans[2];
    ans[0].name = "Hello";
    ans[0].value = 65;
    ans[0].other = 63.63;
    ans[1].name = "World";
    ans[1].value = 123;
    ans[1].other = 3673.562;

    int count;
    foreach (record; records)
    {
        assert(ans[count].name == record.name);
        assert(ans[count].value == record.value);
        assert(ans[count].other == record.other);
        count++;
    }
    assert(count == 2);
}

// Test data conversion interface
unittest
{
    string str = `76,26,22`;
    int[] ans = [76,26,22];
    auto records = csvText!int(str);

    int count;
    foreach (record; records)
    {
        foreach (cell; record)
        {
            assert (ans[count] == cell);
            count++;
        }
    }
    assert(count == 3);
}

// Test unchecked read
unittest
{
    string str = "It is me \"Not here\"";
    foreach (record; csvText!(string, Malformed.ignore)(str))
    {
        foreach (cell; record)
        {
            assert (cell == "It is me \"Not here\"");
        }
    }

    str = "It is me \"Not here\",In \"the\" sand";
    struct Ans
    {
        string a, b;
    }
    foreach(record; csvText!(Ans, Malformed.ignore) (str))
    {
        assert (record.a == "It is me \"Not here\"");
        assert (record.b == "In \"the\" sand");
    }
}

/**
 * Range which provides access to CSV Records and Tokens.
 */
struct RecordList(Contents = string,
                  Malformed ErrorLevel = Malformed.throwException, 
                  Range, Separator)
{
private:
    Range _input;
    Separator _separator;
    Separator _quote;
    Separator _recordBreak;
    size_t[] indices;
public:
    /**
     */
    this(Range input, Separator separator, Separator quote,
         Separator recordBreak)
    {
        _input = input;
        _separator = separator;
        _quote = quote;
        _recordBreak = recordBreak;
    }

    /**
     */
    this(Range input, Separator separator, Separator quote,
         Separator recordBreak, Range[] colHeaders)
    {
        this(input, separator, quote, recordBreak);

        size_t[Range] colToIndex;
        foreach(i, h; colHeaders)
        {
            colToIndex[h] = size_t.max;
        }

        auto r = Record!(Range, ErrorLevel, Range, Separator)
            (_input, _separator, _quote, _recordBreak);
        r.popFront();

        size_t colIndex;
        foreach(col; r)
        {
            auto ptr = col in colToIndex;
            if(ptr)
                *ptr = colIndex;
            colIndex++;
        }

        indices.length = colHeaders.length;
        foreach(i, h; colHeaders)
        {
            immutable index = colToIndex[h];
            static if(Malformed.throwException)
                enforce(index < size_t.max,
                        "Header not found: " ~ to!string(h));
            indices[i] = index;
        }
        popFront();
    }

    /**
     */
    @property auto front()
    {
        assert(!empty);
        static if(is(Contents == struct) || is(Contents == class))
        {
            auto r = Record!(Range, ErrorLevel, Range, Separator)
                              (_input, _separator, _quote, _recordBreak);
            r.popFront();

            Contents recordContentsype;
            if(indices.empty)
            {
                foreach (i, U; FieldTypeTuple!(Contents))
                {
                    auto token = r.front;
                    auto v = to!(U)(token);
                    recordContentsype.tupleof[i] = v;
                    r.popFront ();
                }
            }
            else 
            {
                size_t colIndex;
                foreach(colData; r)
                {
                    scope(exit) colIndex++;
                    foreach(ti, ToType; FieldTypeTuple!(Contents))
                    {
                        if(indices[ti] == colIndex)
                        {
                            recordContentsype.tupleof[ti] = to!ToType(colData);
                        }
                    }
                }
            }

            return recordContentsype;
        }
        else
        {
            auto recordRange = Record!(Contents, ErrorLevel, Range, Separator)
                                    (_input, _separator, _quote, _recordBreak);
            recordRange.popFront();
            return recordRange;
        }
    }

    /**
     */
    @property bool empty()
    {
        return _input.empty;
    }

    /**
     */
    void popFront()
    {
        while(!_input.empty && !startsWith(_input, _recordBreak)) 
        {
            skipOver(_input, _separator);
            csvNextToken!ErrorLevel(_input, _separator,_quote,_recordBreak);
        }
        skipOver(_input, _recordBreak);
    }
}

/**
 */
struct Record(Contents, Malformed ErrorLevel = Malformed.throwException,
              Range, Separator)
             if(!is(Contents == class) && !is(Contents == struct)) {
private:
    Range _input;
    Separator _separator;
    Separator _quote;
    Separator _recordBreak;
    Contents curContentsoken;
    bool _empty;
public:
    /**
     */
    this(ref Range input, Separator separator, Separator quote, Separator
         recordBreak)
    {
        _input = input;
        _separator = separator;
        _quote = quote;
        _recordBreak = recordBreak;
    }

    /**
     */
    @property Contents front()
    {
        assert(!empty);
        return curContentsoken;
    }

    /**
     */
    @property bool empty()
    {
        return _empty;
    }

    /**
     */
    void popFront()
    {
        if(_input.empty || startsWith(_input, _recordBreak)) 
        {
            _empty = true;
            return;
        }

        auto str = csvNextToken!(ErrorLevel, Range, Separator)
                                (_input, _separator, _quote, _recordBreak);
        curContentsoken = to!Contents(str);
        skipOver(_input, _separator);
    }
}

/**
 * Lower level control over parsing CSV. At this time it is not ready
 * for public consumption.
 *
 * The expected use of this would be to create a parser. And
 * may also be useful when handling errors within a CSV file.
 *
 * This function consumes the input. After each call the input will
 * start with either a separator or recordBreak which must be removed
 * for subsequent calls.
 *
 * Returns:
 *        The next CSV token.
 */
private Range csvNextToken(Malformed ErrorLevel = Malformed.throwException,
                           Range)
                          (ref Range line) if(hasSlicing!Range)
{
    return csvNextToken!(ErrorLevel, Range)(line, ",", "\"", "\n");
}
 
/// Ditto
private Range csvNextToken(Malformed ErrorLevel = Malformed.throwException,
                           Range, Separator)
                          (ref Range line, Separator sep,
                           Separator quote, Separator recordBreak) 
                          if(hasSlicing!Range && isInputRange!Range)
{
    bool escQuote;
    if(line.empty || startsWith(line, recordBreak))
        return line;

    if(startsWith(line, quote)) 
    {
        skipOver(line, quote);
        auto count = countUntil(line, quote);
        // Should find either an closing quote or an escaping quote
        if(count == -1) 
        {
            static if(ErrorLevel == Malformed.throwException)
                throw new IncompleteCellException(line,
                      "In quoted section but input is empty.");
            else static if(ErrorLevel == Malformed.ignore)
                return line;
        }

        Range ans = Range.init;

        for (;;)
        {
            if (startsWith(line[count..$], quote))
            {
                // Quoted, quote found
                // By turning off quoted and turning on escQuote
                // I can tell when to add a quote to the string
                // escQuote is turned to false when it escapes a
                // quote or is followed by a non-quote (see outside else).
                // They are mutually exclusive, but provide different
                // information.
                if (line[count..$].empty)
                    break;

                auto next = startsWith(line[count + quote.length..$], 
                                       quote, sep, recordBreak);
                if(next == 0)
                {
                    throw new IncompleteCellException(line[0..count],
                          "Content continues after end quote, needs to be" ~
                          "escaped.");
                }
                else if(next == 1)
                {
                    count += quote.length;
                    ans ~= line[0..count];
                    line = line[count + quote.length..$];
                    count = 0;
                }
                else if(next > 1)
                {
                    ans ~= line[0..count];
                    count += quote.length;
                    break;
                }
                auto add = countUntil (line[count..$], quote);
                if(add == -1)
                {
                    static if(ErrorLevel == Malformed.throwException)
                        throw new IncompleteCellException(line,
                             "In quoted section but input is empty.");
                    else static if(ErrorLevel == Malformed.ignore)
                    {
                        ans ~= line;
                        break;
                    }
                }
                else
                    count += add;
            }
        }

        line = line[count..$];
        return ans;

    }
    else 
    {
        static if(ErrorLevel == Malformed.throwException)
        {
            auto count = countUntil(line, sep, recordBreak, quote);
            if(count != -1)
                if(startsWith(line[count..$], quote))
                    throw new IncompleteCellException(line[0..count],
                          "Quote located in unquoted token");
        }
        else static if(ErrorLevel == Malformed.ignore)
            auto count = countUntil(line, sep, recordBreak);

        if(count == -1)
            count = line.length;

        auto ans = line[0..count];
        line = line[count..$];
        return ans;
    }
}

/**
 * Determines the behavior for when an error is detected.
 */
enum Malformed
{
    ///
    ignore,
    ///
    throwException
}

/**
 * Exception thrown when a Token is identified to not be
 * completed.
 */
class IncompleteCellException:Exception
{
    string partialData;
    this(string cellPartial, string msg)
    {
        super(msg);
        partialData = cellPartial;
    }
}

// Test csvNextToken on simplest form and correct format.
unittest 
{
    string str = "Hello,65,63.63\nWorld,123,3673.562";

    auto a = csvNextToken(str);
    assert(a == "Hello");
    assert(str == ",65,63.63\nWorld,123,3673.562");

    str.popFront();
    a = csvNextToken(str);
    assert(a == "65");
    assert(str == ",63.63\nWorld,123,3673.562");

    str.popFront();
    a = csvNextToken(str);
    assert(a == "63.63");
    assert(str == "\nWorld,123,3673.562");

    str.popFront();
    a = csvNextToken(str);
    assert(a == "World");
    assert(str == ",123,3673.562");

    str.popFront();
    a = csvNextToken(str);
    assert(a == "123");
    assert(str == ",3673.562");

    str.popFront();
    a = csvNextToken(str);
    assert(a == "3673.562");
    assert(str == "");
}

// Test quoted tokens
unittest 
{
    string str = `Hello,World,"Hi ""There""","",` ~ "\"It is\nme\"\nNot here";

    auto a = csvNextToken(str);
    assert(a == "Hello");
    assert(str == `,World,"Hi ""There""","",` ~ "\"It is\nme\"\nNot here");

    str.popFront();
    a = csvNextToken(str);
    assert(a == "World");
    assert(str == `,"Hi ""There""","",` ~ "\"It is\nme\"\nNot here");

    str.popFront();
    a = csvNextToken(str);
    assert(a == "Hi \"There\"");
    assert(str == `,"",` ~ "\"It is\nme\"\nNot here");

    str.popFront();
    a = csvNextToken(str);
    assert(a == "");
    assert(a !is null);
    assert(str == ",\"It is\nme\"\nNot here");
    
    str.popFront();
    a = csvNextToken(str);
    assert(a == "It is\nme");
    assert(str == "\nNot here");

    str.popFront();
    a = csvNextToken(str);
    assert(a == "Not here");
    assert(str == "");
}

// Test empty data is pulled at start of record.
unittest 
{
    string str = ",Hello";
    auto a = csvNextToken(str);
    assert(a == "");
    assert(str == ",Hello");
}

// Test empty data is pulled at end of record.
unittest 
{
    string str = "Hello,";
    auto a = csvNextToken(str);
    assert(a == "Hello");
    assert(str == ",");

    a = csvNextToken(str);
    assert(a == "");
    assert(a !is null);
    assert(str == ",");
}

// Test exceptions
unittest 
{
    string str = "\"It is me\nNot here";

    try 
    {
        auto a = csvNextToken(str);
        assert(0);
    }
    catch(IncompleteCellException ice) 
    {
        assert(ice.partialData == "It is me\nNot here");
    }

    str = "It is me Not here\"";

    try 
    {
        auto a = csvNextToken(str);
        assert(0);
    } 
    catch(IncompleteCellException ice) 
    {
        assert(ice.partialData == "It is me Not here");
    }

    str = "Break me, off a \"Kit Kat\" bar";

    auto a = csvNextToken!(Malformed.ignore)(str);
    assert(a == "Break me");
    str.popFront();
    a = csvNextToken!(Malformed.ignore)(str);
    assert(a == " off a \"Kit Kat\" bar");

    str = "off a \"Kit Kat\" bar";

    try 
    {
        csvNextToken(str);
        assert(0);
    }
    catch(IncompleteCellException ice) 
    {
        assert(ice.partialData == "off a ");
    }
}


// Test modifying token separators
unittest 
{
    string str = `Hello|World|/Hi ""There""/|//|` ~ "/It is\nme/-Not here";

    auto a = csvNextToken(str, "|","/","-");
    assert(a == "Hello");
    assert(str == `|World|/Hi ""There""/|//|` ~ "/It is\nme/-Not here");

    str.popFront();
    a = csvNextToken(str, "|","/","-");
    assert(a == "World");
    assert(str == `|/Hi ""There""/|//|` ~ "/It is\nme/-Not here");

    str.popFront();
    a = csvNextToken(str, "|","/","-");
    assert(a == `Hi ""There""`);
    assert(str == `|//|` ~ "/It is\nme/-Not here");

    str.popFront();
    a = csvNextToken(str, "|","/","-");
    assert(a == "");
    assert(a !is null);
    assert(str == "|/It is\nme/-Not here");
    
    str.popFront();
    a = csvNextToken(str, "|","/","-");
    assert(a == "It is\nme");
    assert(str == "-Not here");

    str.popFront();
    a = csvNextToken(str, "|","/","-");
    assert(a == "Not here");
    assert(str == "");
}

// Test using csvNextToken as a splitter with "quoting"
unittest 
{
    string str = `Hello|World|/Hi ""There""/|//|` ~ "It is\nme-Not here";

    auto a = csvNextToken(str, "|","/","\0");
    str.popFront();
    a = csvNextToken(str, "|","/","\0");
    str.popFront();
    a = csvNextToken(str, "|","/","\0");
    str.popFront();
    a = csvNextToken(str, "|","/","\0");
    str.popFront();
    a = csvNextToken(str, "|","/","\0");
    assert(a == "It is\nme-Not here");
    assert(str == "");
}

version(none) 
{
// Test Windows CSV files
unittest 
{
    string str = `Hello,World,"Hi ""There""","",` 
        ~ "\"It is\r\nme\"\r\nNot here";

    auto a = csvNextToken(str);
    assert(a == "Hello");
    assert(str == `,World,"Hi ""There""","",` ~ "\"It is\r\nme\"\r\nNot here");

    str.popFront();
    a = csvNextToken(str);
    assert(a == "World");
    assert(str == `,"Hi ""There""","",` ~ "\"It is\r\nme\"\r\nNot here");

    str.popFront();
    a = csvNextToken(str);
    assert(a == "Hi \"There\"");
    assert(str == `,"",` ~ "\"It is\r\nme\"\r\nNot here");

    str.popFront();
    a = csvNextToken(str);
    assert(a == "");
    assert(a !is null);
    assert(str == ",\"It is\r\nme\"\r\nNot here");
    
    str.popFront();
    a = csvNextToken(str);
    assert(a == "It is\r\nme");
    assert(str == "\r\nNot here");

    str.popFront();
    a = csvNextToken(str);
    assert(a == "Not here");
    assert(str == "");
}
}

// Testing string separators
unittest 
{
    string str = "5||35.5||63.15";
    auto records =
        RecordList!(double, Malformed.throwException, string, string)
                   (str, "||", "\"", "&");
    auto ans = [5,35.5,63.15];

    foreach(record; records)
    {
        int count;
        foreach(cell; record)
        {
            assert(ans[count] == cell);
            count++;
        }
    }
}
