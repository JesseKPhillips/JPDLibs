//Written in the D programming language

/**
 * Implements functionality to read Comma Separated Values and its variants
 * from a input range.
 *
 * TODO: What should be used where. Separator, comma, and delimiter are
 * synonyms; quote has no good synonym; input and data refer to the same but
 * data works well for documentation while input is nice for the
 * implementation.
 *
 * Comma Separated Values provide a simple means to transfer and store 
 * tabular data. It has been common for programs to use their own
 * variant of the CSV format. This parser will loosely follow the
 * $(WEB tools.ietf.org/html/rfc4180, RFC-4180). CSV data should follow
 * the following rules.
 *
 * $(UL
 *     $(LI A record is separated by a new line (CRLF,LF,CR))
 *     $(LI A final record may end with a new line)
 *     $(LI Header may be provided as first line in file)
 *     $(LI A record has fields separated by a comma (customizable))
 *     $(LI A field containing new lines, commas, or double quotes
 *          should be enclosed in double quotes (customizable))
 *     $(LI Double quotes in a field are escaped with a double quote)
 *     $(LI Each record should contain the same number of fields)
 *   )
 *
 * This module allows content to be iterated by record stored in a struct
 * or into a range of fields. Upon detection of an error an
 * IncompleteCellException is thrown (can be disabled). csvNextToken has been
 * made public to allow for attempted recovery.
 *
 * Disabling exceptions will lift many restrictions specified above. A quote
 * can appear in a field if the field was not quoted. If in a quoted field any
 * quote by itself, not at the end of a field, will end processing for that
 * field. The field is ended when there is no data, even if the quote was not
 * closed.
 *
 * Written by Jesse Phillips
 *   Copyright: Copyright 2011
 *   License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 *   Authors:   Jesse Phillips
 *   Source:    $(PHOBOSSRC std/_csv.d)
 */
module csv;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.range;
import std.stdio;
import std.traits;

/**
 * Builds a RecordList range for iterating over records found in data.
 *
 * This function simplifies the process for standard text input.
 * For other data create RecordList yourself.
 *
 * The Content of the data can be provided if if all the records are the same
 * type. The ErrorLevel can be set to Malformed.ignore if best guess processing
 * should take place.
 *
 * An optional heading can be provided. The first line will be read in as the
 * heading. If the Content type is a struct then the heading provided is
 * expected to correspond to the fields in the struct. When Content is non-struct
 * the heading must be provided in the same order as the file or an exception
 * is thrown.
 *
 * TODO: Providing a heading for non-struct data has no clear choice. If the
 * order of the provided heading is different from the file, it
 * processes what it can in order, it reorders the provided heading to match
 * that of the data, or it throws when the provided header is out of order.
 *
 * The delimiter (comma), and quote can optionally be changed.
 *
 * TODO: RecordList provides this custum sep, are the extra functions with
 * it? 
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
 *
 * Returns:
 *      If Contents is a struct, the range will return a
 *      struct populated by a single record.
 *
 *      Otherwise the range will return a Record range of the type.
 *
 * Throws:
 *       IncompleteCellToken When a quote is found in an unquoted field, data
 *       continues after a closing quote, or the quoted field was not closed
 *       before data was empty.
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

/// Ditto
auto csvText(Contents = string, Malformed ErrorLevel 
             = Malformed.throwException, Range)(string delimiter, string quote,
                                                Range data)
    if(isSomeString!Range)
{
    return RecordList!(Contents,ErrorLevel,Range,ElementType!Range)
        (data, delimiter, quote);
}

/// Ditto
auto csvText(Contents = string, Malformed ErrorLevel 
             = Malformed.throwException, Range)(string delimiter, string quote,
                                                Range data, string[] heading)
    if(isSomeString!Range)
{
    return RecordList!(Contents,ErrorLevel,Range,ElementType!Range)
        (data, delimiter, quote, heading);
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

// Test newline on last record
unittest
{
    string str = "one,two\nthree,four\n";
    auto records = csvText(str);
    records.popFront();
    records.popFront();
    assert(records.empty);
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

// Test header interface
unittest
{
    string str = "a,b,c\nHello,65,63.63\nWorld,123,3673.562";
    auto records = csvText(str, ["b"]);

    auto ans = ["65","123"];
    foreach(record; records)
        foreach(cell; record) {
            assert(cell == ans.front);
            ans.popFront();
        }

    try {
        records = csvText(str, ["b","a"]);
        assert(0);
    } catch(Exception e) {
    }

    auto records2 = csvText!(string, Malformed.ignore)(str, ["b","a"]);

    ans = ["Hello","65","World","123"];
    foreach(record; records2)
        foreach(cell; record) {
            assert(cell == ans.front);
            ans.popFront();
        }
}

// Test null header interface
unittest
{
    string str = "a,b,c\nHello,65,63.63\nWorld,123,3673.562";
    auto records = csvText(str, cast(string[])null);

    assert(records.heading == ["a","b","c"]);
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
 * Range which provides access to CSV Records and Fields.
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
    /// Array of the heading contained in the file.
    Range[] heading;

    /**
     * Constructor to initialize the input, separator and quote for data
     * without a heading.
     */
    this(Range input, Separator separator, Separator quote)
    {
        _input = input;
        _separator = separator;
        _quote = quote;
        
        static if(is(Contents == struct))
        {
            indices.length =  FieldTypeTuple!(Contents).length;
            foreach(i, j; FieldTypeTuple!Contents)
                indices[i] = i;
        }
        prime();
    }

    /**
     * Constructor to initialize the input, separator and quote for data
     * with a heading.
     */
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
            (&_input, _separator, _quote, indices);

        size_t colIndex;
        foreach(col; r)
        {
            heading ~= col;
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

        static if(!is(Contents == struct))
        {
            static if(ErrorLevel == Malformed.ignore)
            {
                sort(indices);
            }
            else 
            {
                enforce(isSorted(indices));
            }
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

        if(_input.empty)
            _empty = true;

        prime();
    }
    
    private void prime()
    {
        if(_empty)
            return;
        static if(is(Contents == struct))
        {
            recordRange = typeof(recordRange)
                                 (&_input, _separator, _quote, null);
        }
        else
        {
            recordRange = typeof(recordRange)
                                 (&_input, _separator, _quote, indices);
        }
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
    size_t[] _popCount;
public:
    /**
     */
    this(Range* input, Separator separator, Separator quote, size_t[] indices)
    {
        _input = input;
        _separator = separator;
        _quote = quote;
        _front = appender!(char[])();
        _popCount = indices.dup;

        // If a header was given, each call to popFront will need
        // to eliminate so many tokens. This calculates
        // how many will be skipped to get to the next header column
        size_t normalizer;
        foreach(ref c; _popCount) {
            c -= normalizer;
            normalizer += c + 1;
        }

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
     * Record is complete when input
     * is empty or starts with record break
     */
    private bool recordEnd() {
        if((*_input).empty
           || (*_input).front == '\n' 
           || (*_input).front == '\r')
        {
            return true;
        }
        return false;
    }


    /**
     */
    void popFront()
    {
        if(_popCount && _popCount.empty) {
            while(!recordEnd())
            {
                prime(1);
            }
        }

        if(recordEnd())
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

    /**
     * Handles moving to the next skipNum token.
     */
    private void prime(size_t skipNum) {
        foreach(i; 0..skipNum) {
            _front.shrinkTo(0);
            if((*_input).front == _separator)
                (*_input).popFront();
            csvNextToken!(ErrorLevel, Range, Separator)
                                   (*_input, _front, _separator, _quote,false);
        }
    }

    private void prime()
    {
        csvNextToken!(ErrorLevel, Range, Separator)
                               (*_input, _front, _separator, _quote,false);

        auto skipNum = _popCount.empty ? 0 : _popCount.front;
        if(!_popCount.empty)
            _popCount.popFront();
        if(skipNum)
            prime(skipNum);
        curContentsoken = to!Contents(_front.data);
    }
}

/**
 * Lower level control over parsing CSV
 *
 * The expected use of this would be to create a parser. And
 * may also be useful when handling errors within a CSV file.
 *
 * This function consumes the input. After each call the input will
 * start with either a separator or record break (\n, \r\n, \r) which 
 * must be removed for subsequent calls.
 *
 * params:
 *       input - Any CSV data
 *       ans   - The first field in the input
 *       sep   - The character to represent a comma in the specification
 *       quote - The character to represent a quote in the specification
 *       startQuoted - Whether the input should be considered to already be in
 * quotes
 *
 */
void csvNextToken(Malformed ErrorLevel = Malformed.throwException,
                           Range, Separator)
                          (ref Range input, ref Appender!(char[]) ans,
                           Separator sep, Separator quote,
                           bool startQuoted = false)
{
    bool quoted = startQuoted;
    bool escQuote;
    if(input.empty)
        return;
    
    if(input.front == '\n')
        return;
    if(input.front == '\r')
        return;

    if(input.front == quote)
    {
        quoted = true;
        input.popFront();
    }

    while(!input.empty)
    {
        assert(!(quoted && escQuote));
        if(!quoted)
        {
            // When not quoted the token ends at sep
            if(input.front == sep) 
                break;
            if(input.front == '\r')
                break;
            if(input.front == '\n')
                break;
        }
        if(!quoted && !escQuote)
        {
            if(input.front == quote)
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
                ans.put(input.front);
            }
        }
        else
        {
            if(input.front == quote)
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
                ans.put(input.front);
            }
        }
        input.popFront();
    }

    static if(ErrorLevel == Malformed.throwException)
        if(quoted && (input.empty || input.front == '\n' || input.front == '\r'))
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
