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
 *    foreach(cell; record) {
 *        assert(ans[count] == cell);
 *        count++;
 *    }
 * }
 * -------
 * 
 * Example using a struct:
 * 
 * -------
 * string str = "Hello,65,63.63\nWorld,123,3673.562";
 * struct Layout {
 *     string name;
 *     int value;
 *     double other;
 * }
 * 
 * auto records = csvText!Layout(str);
 * 
 * foreach(record; records) {
 *     writeln(record.name);
 *     writeln(record.value);
 *     writeln(record.other);
 * }
 * -------
 */
module csv;

import std.array;
import std.conv;
import std.exception;
import std.range;
import std.stdio;
import std.traits;

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
 *     foreach(cell; record) {
 *         assert(ans[count] == cell);
 *         count++;
 *     }
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
auto csvText(Contents = string, Malformed ErrorLevel 
             = Malformed.throwException, Range)(Range data)
    if(isSomeString!Range)
{
    return RecordList!(Contents,ErrorLevel,Range,ElementType!Range)
        (data, ',', '"');
}

/// Ditto
auto csvText(Contents = string, Malformed ErrorLevel 
             = Malformed.throwException, Range)(Range data, string[] heading)
    if(isSomeString!Range)
{
    return RecordList!(Contents,ErrorLevel,Range,ElementType!Range)
        (data, ',', '"', heading);
}

deprecated alias csvText csv;

// Test standard iteration over data.
unittest
{
    string str = `one,two,"three ""quoted""","",` ~ "\"five\nnew line\"\nsix";
    auto records = csvText(str);
    
    int count;
    foreach(record; records)
    {
        foreach(cell; record)
        {
            count++;
        }
    }
    assert(count == 6);
}

// Test structure conversion interface.
unittest {
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
    ans[0].other = 663.63;
    ans[1].name = "World";
    ans[1].value = 65;
    ans[1].other = 663.63;

    auto records = csvText!Layout(str);

    int count;
    foreach(record; records)
    {
        ans[count].name = record.name;
        ans[count].value = record.value;
        ans[count].other = record.other;
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
    foreach(record; records)
    {
        foreach(cell; record)
        {
            assert(ans[count] == cell);
            count++;
        }
    }
    assert(count == 3);
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

// Test unchecked read
unittest
{
    string str = "one \"quoted\"";
    foreach(record; csvText!(string, Malformed.ignore)(str))
    {
        foreach(cell; record)
        {
            assert(cell == "one \"quoted\"");
        }
    }

    str = "one \"quoted\",two \"quoted\" end";
    struct Ans
    {
        string a,b;
    }
    foreach(record; csvText!(Ans, Malformed.ignore)(str))
    {
            assert(record.a == "one \"quoted\"");
            assert(record.b == "two \"quoted\" end");
    }
}

// Test Windows line break
unittest
{
    string str = "one,two\r\nthree";

    auto records = csvText(str);
    auto record = records.front;
    assert(record.front == "one");
    record.popFront();
    assert(record.front == "two");
    records.popFront();
    record = records.front;
    assert(record.front == "three");
}

/**
 * Range which provides access to CSV Records and Tokens.
 */
struct RecordList(Contents, Malformed ErrorLevel, Range, Separator)
{
private:
    Range _input;
    Separator _separator;
    Separator _quote;
    size_t[] indices;
    bool _empty;
    static if(is(Contents == struct))
    {
        Contents recordContent;
        Record!(Range, ErrorLevel, Range, Separator) recordRange;
    }
    else
        Record!(Contents, ErrorLevel, Range, Separator) recordRange;
public:
    /**
     */
    this(Range input, Separator separator, Separator quote)
    {
        _input = input;
        _separator = separator;
        _quote = quote;
        
        indices.length =  FieldTypeTuple!(Contents).length;
        foreach(i, j; FieldTypeTuple!Contents)
            indices[i] = i;
        prime();
    }

    this(Range input, Separator separator, Separator quote, string[] colHeaders)
    {
        _input = input;
        _separator = separator;
        _quote = quote;

        size_t[string] colToIndex;
        foreach(i, h; colHeaders)
        {
            colToIndex[h] = size_t.max;
        }

        auto r = Record!(Range, ErrorLevel, Range, Separator)
            (&_input, _separator, _quote);

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
            static if(!Malformed.ignore)
                enforce(index < size_t.max,
                        "Header not found: " ~ to!string(h));
            indices[i] = index;
        }
        
        popFront();
    }

    this(this)
    {
        recordRange._input = &_input;
    }

    /**
     */
    @property auto front()
    {
        assert(!empty);
        static if(is(Contents == struct))
        {
            return recordContent;
        }
        else
        {
            recordRange._input = &_input;
            return recordRange;
        }
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
        recordRange._input = &_input;

        while(!recordRange.empty)
        {
            recordRange.popFront();
        }

        if(_input.empty)
            _empty = true;
        if(!_input.empty)
        {
           if(_input.front == '\r') 
           {
               _input.popFront();
               if(_input.front == '\n') 
                   _input.popFront();
           }
           else if(_input.front == '\n') 
               _input.popFront();
        }
        prime();
    }
    
    void prime()
    {
        if(_empty)
            return;
        recordRange = typeof(recordRange)
                             (&_input, _separator, _quote);
        static if(is(Contents == struct))
        {
            size_t colIndex;
            foreach(colData; recordRange)
            {
                scope(exit) colIndex++;
                if(indices.length > 0) 
                {
                    foreach(ti, ToType; FieldTypeTuple!(Contents))
                    {
                        if(indices[ti] == colIndex)
                        {
                            recordContent.tupleof[ti] = to!ToType(colData);
                        }
                    }
                }
                else
                {
                    foreach(ti, ToType; FieldTypeTuple!(Contents))
                    {
                        recordContent.tupleof[ti] = to!ToType(colData);
                    }
                }
            }
            
        }
    }
}

/**
 */
struct Record(Contents, Malformed ErrorLevel, Range, Separator)
    if(!is(Contents == class) && !is(Contents == struct))
{
private:
    Range* _input;
    Separator _separator;
    Separator _quote;
    Contents curContentsoken;
    typeof(appender!(char[])()) _front;
    bool _empty;
public:
    /**
     */
    this(Range* input, Separator separator, Separator quote)
    {
        _input = input;
        _separator = separator;
        _quote = quote;
        _front = appender!(char[])();
        prime();
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
        //Record is complete when input
        // is empty or starts with record break
        if((*_input).empty
           || (*_input).front == '\n' 
           || (*_input).front == '\r')
        {
            _empty = true;
            return;
        }

        // Separator is left on the end of input from the last call. 
        // This cannot be moved to after the call to csvNextToken as 
        // there may be an empty record after it.
        if((*_input).front == _separator)
            (*_input).popFront();

        _front.shrinkTo(0);
        prime();
    }

    void prime()
    {
        csvNextToken!(ErrorLevel, Range, Separator)
                                (*_input, _front, _separator, _quote,false);

        curContentsoken = to!Contents(_front.data);
    }
}

/**
 * Lower level control over parsing CSV. At this time it is not ready for
 * public consumption.
 *
 * The expected use of this would be to create a parser. And
 * may also be useful when handling errors within a CSV file.
 *
 * This function consumes the input. After each call the input will
 * start with either a separator or record break (\n, \r\n, \r) which 
 * must be removed for subsequent calls.
 *
 * Returns:
 *        The next CSV token.
 */
private void csvNextToken(Malformed ErrorLevel = Malformed.throwException,
                           Range, Separator)
                          (ref Range line, ref Appender!(char[]) ans,
                           Separator sep, Separator quote,
                           bool startQuoted = false)
{
    bool quoted = startQuoted;
    bool escQuote;
    if(line.empty)
        return;
    
    if(line.front == '\n')
        return;
    if(line.front == '\r')
        return;

    if(line.front == quote)
    {
        quoted = true;
        line.popFront();
    }

    while(!line.empty)
    {
        assert(!(quoted && escQuote));
        if(!quoted)
        {
            // When not quoted the token ends at sep
            if(line.front == sep) 
                break;
            if(line.front == '\r')
                break;
            if(line.front == '\n')
                break;
        }
        if(!quoted && !escQuote)
        {
            if(line.front == quote)
            {
                // Not quoted, but quote found
                static if(ErrorLevel == Malformed.throwException)
                    throw new IncompleteCellException(ans.data.idup,
                          "Quote located in unquoted token");
                else static if(ErrorLevel == Malformed.ignore)
                    ans.put(quote);
            }
            else
            {
                // Not quoted, non-quote character
                ans.put(line.front);
            }
        }
        else
        {
            if(line.front == quote)
            {
                // Quoted, quote found
                // By turning off quoted and turning on escQuote
                // I can tell when to add a quote to the string
                // escQuote is turned to false when it escapes a
                // quote or is followed by a non-quote (see outside else).
                // They are mutually exclusive, but provide different
                // information.
                if(escQuote)
                {
                    escQuote = false;
                    quoted = true;
                    ans.put(quote);
                } else
                {
                    escQuote = true;
                    quoted = false;
                }
            }
            else
            {
                // Quoted, non-quote character
                if(escQuote)
                {
                    static if(ErrorLevel == Malformed.throwException)
                        throw new IncompleteCellException(ans.data.idup,
                          "Content continues after end quote, " ~
                          "or needs to be escaped.");
                    else static if(ErrorLevel == Malformed.ignore)
                        break;
                }
                ans.put(line.front);
            }
        }
        line.popFront();
    }

    static if(ErrorLevel == Malformed.throwException)
        if(quoted && (line.empty || line.front == '\n' || line.front == '\r'))
            throw new IncompleteCellException(ans.data.idup,
                  "Data continues on future lines or trailing quote");

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
class IncompleteCellException : Exception
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

    auto a = appender!(char[]);
    csvNextToken(str,a,',','"');
    assert(a.data == "Hello");
    assert(str == ",65,63.63\nWorld,123,3673.562");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "65");
    assert(str == ",63.63\nWorld,123,3673.562");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "63.63");
    assert(str == "\nWorld,123,3673.562");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "World");
    assert(str == ",123,3673.562");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "123");
    assert(str == ",3673.562");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "3673.562");
    assert(str == "");
}

// Test quoted tokens
unittest
{
    string str = `one,two,"three ""quoted""","",` ~ "\"five\nnew line\"\nsix";

    auto a = appender!(char[]);
    csvNextToken(str,a,',','"');
    assert(a.data == "one");
    assert(str == `,two,"three ""quoted""","",` ~ "\"five\nnew line\"\nsix");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "two");
    assert(str == `,"three ""quoted""","",` ~ "\"five\nnew line\"\nsix");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "three \"quoted\"");
    assert(str == `,"",` ~ "\"five\nnew line\"\nsix");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "");
    assert(str == ",\"five\nnew line\"\nsix");
    
    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "five\nnew line");
    assert(str == "\nsix");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "six");
    assert(str == "");
}

// Test empty data is pulled at end of record.
unittest
{
    string str = "one,";
    auto a = appender!(char[]);
    csvNextToken(str,a,',','"');
    assert(a.data == "one");
    assert(str == ",");

    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "");
}

// Test exceptions
unittest
{
    string str = "\"one\nnew line";

    try
    {
    auto a = appender!(char[]);
        csvNextToken(str,a,',','"');
        assert(0);
    }
    catch (IncompleteCellException ice)
    {
        assert(ice.partialData == "one\nnew line");
        assert(str == "");
    }

    str = "Hello world\"";

    try
    {
    auto a = appender!(char[]);
        csvNextToken(str,a,',','"');
        assert(0);
    }
    catch (IncompleteCellException ice)
    {
        assert(ice.partialData == "Hello world");
        assert(str == "\"");
    }

    str = "one, two \"quoted\" end";

    auto a = appender!(char[]);
    csvNextToken!(Malformed.ignore)(str,a,',','"');
    assert(a.data == "one");
    str.popFront();
    a.shrinkTo(0);
    csvNextToken!(Malformed.ignore)(str,a,',','"');
    assert(a.data == " two \"quoted\" end");
}


// Test modifying token separators
unittest
{
    string str = `one|two|/three "quoted"/|//`;

    auto a = appender!(char[]);
    csvNextToken(str,a, '|','/');
    assert(a.data == "one");
    assert(str == `|two|/three "quoted"/|//`);

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a, '|','/');
    assert(a.data == "two");
    assert(str == `|/three "quoted"/|//`);

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a, '|','/');
    assert(a.data == `three "quoted"`);
    assert(str == `|//`);

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a, '|','/');
    assert(a.data == "");
}
