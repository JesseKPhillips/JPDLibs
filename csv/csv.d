import std.array;
import std.range;
import std.conv;
import std.traits;
import std.stdio;

struct RecordList(T) {
private:
	string _input;
	dchar _separator;
	dchar _quote;
	dchar _recordBreak;
public:
	this(string input, dchar separator, dchar quote, dchar recordBreak)
	{
		_input = input;
		_separator = separator;
		_quote = quote;
		_recordBreak = recordBreak;
	}

	@property auto front()
	{
		assert(!empty);
		static if(is(T == struct) || is(T == class)) {
			auto r = Record!string(_input, _separator, _quote, _recordBreak);
			r.popFront();
			alias FieldTypeTuple!(T) types;
			T recordType;
			foreach(i, t; types) {
				auto token = csvToken(_input, _separator,_quote,_recordBreak,false);
				auto v = to!(t)(token);
				recordType.tupleof[i] = v;
			}

			return recordType;
		} else {
			auto r = Record!T(_input, _separator, _quote, _recordBreak);
			r.popFront();
			return r;
		}
	}

	@property bool empty()
	{
		return _input.empty;
	}

	void popFront()
	{
		while(csvToken(_input, _separator,_quote,_recordBreak,false) !is null) {}
		if(!_input.empty && _input.front == _recordBreak)
			_input.popFront();
	}
}

struct Record(T) if(!is(T == class) && !is(T == struct)) {
private:
	string _input;
	dchar _separator;
	dchar _quote;
	dchar _recordBreak;
	T curToken;
	bool _empty;
public:
	this(ref string input, dchar separator, dchar quote, dchar recordBreak)
	{
		_input = input;
		_separator = separator;
		_quote = quote;
		_recordBreak = recordBreak;
	}

	@property T front()
	{
		assert(!empty);
		return curToken;
	}

	@property bool empty()
	{
		return _empty;
	}

	void popFront()
	{
		auto str = csvToken(_input, _separator, _quote, _recordBreak,false);
		if(str is null) {
			_empty = true;
			return;
		}

		curToken = to!T(str);
	}
}

auto csv(T = string)(string data) {
	return RecordList!T(data, ',', '"', '\n');
}

unittest {
	string str = `Hello,World,"Hi ""There""","",` ~ "\"It is\nme\"\nNot here";
	auto records = csv(str);

	int count;
	foreach(record; records) {
		foreach(cell; record) {
			count++;
		}
	}
	assert(count == 6);
}

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

	auto records = csv!Layout(str);

	int count;
	foreach(record; records) {
		ans[count].name = record.name;
		ans[count].value = record.value;
		ans[count].other = record.other;
		count++;
	}
	assert(count == 2);
}

unittest {
	string str = `76,26,22`;
	int[] ans = [76,26,22];
	auto records = csv!int(str);

	int count;
	foreach(record; records) {
		foreach(cell; record) {
			assert(ans[count] == cell);
			count++;
		}
	}
	assert(count == 3);
}

string csvNextToken(dchar sep = ',', dchar quote = '"', dchar recordBreak = '\n')
                 (ref string line, bool quoted = false) {
	return csvToken(line, sep, quote, recordBreak, quoted);
}
string csvToken(ref string line, dchar sep = ',', dchar quote = '"',
	               dchar recordBreak = '\n', bool startQuoted = false) {
	bool quoted = startQuoted;
	bool escQuote;
	string ans = line.empty ? null : "";

	while(!line.empty) {
		assert(!(quoted && escQuote));
		if(line.front == quote) {
			// By turning off quoted and turning on escQuote
			// I can tell when to add a quote to the string
			// escQuote is turned to false when it escapse a
			// quote or is followed by o non-quote (see outside else).
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

class IncompleteCellException : Exception {
	string partialData;
	this(string cellPartial, string msg) {
		super(msg);
		partialData = cellPartial;
	}
}

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

unittest {
	string str = "Hello,";
	auto a = csvNextToken(str);
	assert(a == "Hello");
	assert(str == ",");

	a = csvNextToken(str);
	assert(a == "");
	assert(a !is null);
}

unittest {
	string str = "\"It is me\nNot here";

	try {
		auto a = csvNextToken(str);
		assert(0);
	} catch (IncompleteCellException ice) {
		assert(ice.partialData == "It is me\nNot here");
		assert(str == "");
	}
}

unittest {
	string str = "It is me Not here\"";

	try {
		auto a = csvNextToken(str);
		assert(0);
	} catch (IncompleteCellException ice) {
		assert(ice.partialData == "It is me Not here");
		assert(str == "");
	}
}


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

unittest {
	string str = `Hello|World|/Hi ""There""/|//|` ~ "/It is\nme/-Not here";

	alias csvNextToken!('|','/','\0') nToken;
	auto a = nToken(str);
	a = nToken(str);
	a = nToken(str);
	a = nToken(str);
	a = nToken(str);
	assert(a !is null);
	assert(str == "");

	a = nToken(str);
	assert(a is null);
}
