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
 * 	foreach(cell; record) {
 * 		assert(ans[count] == cell);
 * 		count++;
 * 	}
 * }
 * -------
 * 
 * Example using a struct:
 * 
 * -------
 * string str = "Hello,65,63.63\nWorld,123,3673.562";
 * struct Layout {
 * 	string name;
 * 	int value;
 * 	double other;
 * }
 * 
 * auto records = csvText!Layout(str);
 * 
 * foreach(record; records) {
 * 	writeln(record.name);
 * 	writeln(record.value);
 * 	writeln(record.other);
 * }
 * -------
 */
module csv;

import std.array;
import std.range;
import std.conv;
import std.traits;
import std.stdio;

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
 * 	foreach(cell; record) {
 * 		assert(ans[count] == cell);
 * 		count++;
 * 	}
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
auto csvText(Contents = string, Range)(Range data) if(isSomeString!Range) {
	return RecordList!(Contents,Range,ElementType!Range)(data, ',', '"', '\n');
}

deprecated alias csvText csv;

// Test standard iteration over data.
unittest {
	string str = `Hello,World,"Hi ""There""","",` ~ "\"It is\nme\"\nNot here";
	auto records = csvText(str);

	int count;
	foreach(record; records) {
		foreach(cell; record) {
			count++;
		}
	}
	assert(count == 6);
}

// Test structure conversion interface.
unittest {
	string str = "Hello,65,63.63\nWorld,123,3673.562";
	struct Layout {
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
	foreach(record; records) {
		ans[count].name = record.name;
		ans[count].value = record.value;
		ans[count].other = record.other;
		count++;
	}
	assert(count == 2);
}

// Test data conversion interface
unittest {
	string str = `76,26,22`;
	int[] ans = [76,26,22];
	auto records = csvText!int(str);

	int count;
	foreach(record; records) {
		foreach(cell; record) {
			assert(ans[count] == cell);
			count++;
		}
	}
	assert(count == 3);
}

/**
 * Range which provides access to CSV Records and Tokens.
 */
struct RecordList(Contents, Range, Separator)
{
private:
	Range _input;
	Separator _separator;
	Separator _quote;
	Separator _recordBreak;
public:
	/**
	 */
	this(Range input, Separator separator, Separator quote, Separator recordBreak)
	{
		_input = input;
		_separator = separator;
		_quote = quote;
		_recordBreak = recordBreak;
	}

	/**
	 */
	@property auto front()
	{
		assert(!empty);
		static if(is(Contents == struct) || is(Contents == class)) {
			auto r = Record!(Range,Range,Separator)(_input, _separator, _quote, _recordBreak);
			r.popFront();
			alias FieldTypeTuple!(Contents) types;
			Contents recordContentsype;
			foreach(i, U; types) {
				auto token = csvToken(_input, _separator,_quote,_recordBreak,false);
				auto v = to!(U)(token);
				recordContentsype.tupleof[i] = v;
			}

			return recordContentsype;
		} else {
			auto r = Record!(Contents,Range,Separator)(_input, _separator, _quote, _recordBreak);
			r.popFront();
			return r;
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
		while(csvToken(_input, _separator,_quote,_recordBreak,false) !is null) {}
		if(!_input.empty && _input.front == _recordBreak)
			_input.popFront();
	}
}

/**
 */
struct Record(Contents, Range, Separator) if(!is(Contents == class) && !is(Contents == struct)) {
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
	this(ref Range input, Separator separator, Separator quote, Separator recordBreak)
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
		auto str = csvToken(_input, _separator, _quote, _recordBreak,false);
		if(str is null) {
			_empty = true;
			return;
		}

		curContentsoken = to!Contents(str);
	}
}

/**
 * Lower level control over parsing CSV. Templated for aliasing with a
 * custom sep, quote and recordBreak. At this time it is not ready for
 * public consumption.
 *
 * This function consumes the input and will not consume or surpass
 * the recordBreak.
 *
 * Returns:
 *        The next CSV token.
 *        null if there is no data or are at the end of the record.
 */
private string csvNextToken
           (dchar sep = ',', dchar quote = '"', dchar recordBreak = '\n')
           (ref string input, bool quoted = false) {
	return csvToken(input, sep, quote, recordBreak, quoted);
}

/**
 * Used internally to return a token based on the sep, quote, and recordBreak.
 *
 * Returns:
 *        The next CSV Token.
 *        null if there is no data or are at the end of the record.
 */
private string csvToken(ref string line, dchar sep = ',', dchar quote = '"',
	               dchar recordBreak = '\n', bool startQuoted = false) {
	bool quoted = startQuoted;
	bool escQuote;
	string ans = line.empty ? null : "";

	while(!line.empty) {
		assert(!(quoted && escQuote));
		if(line.front == quote) {
			// By turning off quoted and turning on escQuote
			// I can tell when to add a quote to the string
			// escQuote is turned to false when it escapes a
			// quote or is followed by a non-quote (see outside else).
			// They are mutually exclusive, but provide different information.
			if(quoted) {
				escQuote = true;
				quoted = false;
			} else {
				quoted = true;
				if(escQuote) {
					ans ~= quote;
					escQuote=false;
				}
			}
		} else
			// Quoted text only worries about quotes, handled above.
			if(quoted)
				ans ~= line.front;
			else {
				escQuote = false; // Can only escape quotes when quoted.
				if(line.front == sep) { // When not quoted the token ends at sep
					if(line.length > 1) // TODO: should make work with non-ascii
						line.popFront();
					break;
				}
				// No data to process
				if(line.front == recordBreak) {
					if(ans == "")
						ans = null;
					break;
				}
				ans ~= line.front;
			}
		line.popFront();
	}

	if(quoted && line.empty)
		throw new IncompleteCellException(ans,
		          "Data continues on future lines or trailing quote");

	return ans;
}

/**
 * Exception thrown when a Token is identified to not be
 * completed.
 */
class IncompleteCellException : Exception {
	string partialData;
	this(string cellPartial, string msg) {
		super(msg);
		partialData = cellPartial;
	}
}

// Test csvNextToken on simplest form and correct formats.
unittest {
	string str = "Hello,65,63.63\nWorld,123,3673.562";

	auto a = csvNextToken(str);
	assert(a == "Hello");
	assert(str == "65,63.63\nWorld,123,3673.562");

	a = csvNextToken(str);
	assert(a == "65");
	assert(str == "63.63\nWorld,123,3673.562");

	a = csvNextToken(str);
	assert(a == "63.63");
	assert(str == "\nWorld,123,3673.562");

	str.popFront();
	a = csvNextToken(str);
	assert(a == "World");
	assert(str == "123,3673.562");

	a = csvNextToken(str);
	assert(a == "123");
	assert(str == "3673.562");

	a = csvNextToken(str);
	assert(a == "3673.562");
	assert(str == "");

	a = csvNextToken(str);
	assert(a == "");
	assert(a is null);
	assert(a.empty);
}

// Test quoted tokens
unittest {
	string str = `Hello,World,"Hi ""There""","",` ~ "\"It is\nme\"\nNot here";

	auto a = csvNextToken(str);
	assert(a == "Hello");
	assert(str == `World,"Hi ""There""","",` ~ "\"It is\nme\"\nNot here");

	a = csvNextToken(str);
	assert(a == "World");
	assert(str == `"Hi ""There""","",` ~ "\"It is\nme\"\nNot here");

	a = csvNextToken(str);
	assert(a == "Hi \"There\"");
	assert(str == `"",` ~ "\"It is\nme\"\nNot here");

	a = csvNextToken(str);
	assert(a == "");
	assert(a !is null);
	assert(str == "\"It is\nme\"\nNot here");
	
	a = csvNextToken(str);
	assert(a == "It is\nme");
	assert(str == "\nNot here");

	a = csvNextToken(str);
	assert(a == "");
	assert(a is null);
	assert(str == "\nNot here");
}

// Test empty data is pulled at end of record.
unittest {
	string str = "Hello,";
	auto a = csvNextToken(str);
	assert(a == "Hello");
	assert(str == ",");

	a = csvNextToken(str);
	assert(a == "");
	assert(a !is null);
}

// Test exceptions
unittest {
	string str = "\"It is me\nNot here";

	try {
		auto a = csvNextToken(str);
		assert(0);
	} catch (IncompleteCellException ice) {
		assert(ice.partialData == "It is me\nNot here");
		assert(str == "");
	}

	str = "It is me Not here\"";

	try {
		auto a = csvNextToken(str);
		assert(0);
	} catch (IncompleteCellException ice) {
		assert(ice.partialData == "It is me Not here");
		assert(str == "");
	}
}


// Test modifying token separators
unittest {
	string str = `Hello|World|/Hi ""There""/|//|` ~ "/It is\nme/-Not here";

	alias csvNextToken!('|','/','-') nToken;

	auto a = nToken(str);
	assert(a == "Hello");
	assert(str == `World|/Hi ""There""/|//|` ~ "/It is\nme/-Not here");

	a = nToken(str);
	assert(a == "World");
	assert(str == `/Hi ""There""/|//|` ~ "/It is\nme/-Not here");

	a = nToken(str);
	assert(a == `Hi ""There""`);
	assert(str == `//|` ~ "/It is\nme/-Not here");

	a = nToken(str);
	assert(a == "");
	assert(a !is null);
	assert(str == "/It is\nme/-Not here");
	
	a = nToken(str);
	assert(a == "It is\nme");
	assert(str == "-Not here");

	a = nToken(str);
	assert(a == "");
	assert(a is null);
	assert(str == "-Not here");
}

// Test using csvNextToken as a splitter with "quoting"
unittest {
	string str = `Hello|World|/Hi ""There""/|//|` ~ "It is\nme-Not here";

	alias csvNextToken!('|','/','\0') nToken;
	auto a = nToken(str);
	a = nToken(str);
	a = nToken(str);
	a = nToken(str);
	a = nToken(str);
	assert(a == "It is\nme-Not here");
	assert(str == "");

	a = nToken(str);
	assert(a is null);
}
