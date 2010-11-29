/**
 * Handling of interaction with users via standard input.
 *
 * Provides functions for simple and common interacitons with users in
 * the form of question and answer.
 *
 * Copyright: Copyright Jesse Phillips 2010
 * License:   boost.org/LICENSE_1_0.txt, Boost License 1.0.
 * Authors:   nascent.freeshell.org Jesse Phillips
 *
 * Synopsis:
 *
 * --------
 * import cmdln.interact;
 *
 * auto age = userInput!int("Please Enter you age");
 * 
 * if(userInput!bool("Do you want to continue?"))
 * {
 *     auto outputFolder = pathLocation("Where you do want to place the output?");
 *     auto color = menu!string("What color would you like to use?", ["Blue", "Green"]);
 * }
 *
 * auto num = require!(int, "a > 0 && a <= 10")("Enter a number from 1 to 10");
 * --------
 */
module cmdln.interact;

import std.array;
import std.conv;
import std.file;
import std.functional;
import std.range;
import std.stdio;
import std.string;
import std.traits;

/**
 * The $(D userInput) function provides a means to accessing a single
 * value from the user. Each invocation outputs a provided 
 * statement/question and takes an entire line of input. The result is then
 * converted to the requested type; default is a string.
 *
 * --------
 * auto name = userInput("What is your name");
 * --------
 *
 * Returns: User response as type T.
 *
 * Where type is bool: 
 *
 *          true on "ok", "continue", 
 *          and if the response starts with 'y' or 'Y'.
 *
 *          false on all other input, include no response (will not throw).
 *
 * Throws: $(D NoInputException) if the user does not enter anything.
 * 	     $(D ConvError) when the string could not be converted to the desired type.
 */
T userInput(T = string)(string question = "") {
	write(question ~ "\n> ");
	auto ans = readln();

	static if(is(T == bool)) {
		switch(ans.front) {
			case 'y', 'Y':
				return true;
			default:
		}
		switch(ans.strip) {
			case "continue":
			case "ok":
				return true;
			default:
				return false;
		}
	} else {
		if(ans == "\x0a")
			throw new NoInputException("Value required, "
			                           "cannot continue operation.");
		static if(isSomeChar!T) {
			return to!(T)(ans[0]);
		} else
			return to!(T)(ans.strip);
	}
}

/**
 * Gets a valid path folder from the user. The string will not contain
 * quotes, if you are using in a system call and the path contain spaces
 * wrapping in quotes may be required.
 *
 * --------
 * auto confFile = pathLocation("Where is the configuration file?");
 * --------
 *
 * Throws: NoInputException if the user does not provide a path.
 */
string pathLocation(string action) {
	string ans;

	do {
		if(ans !is null)
			writeln("Could not locate that file.");
		ans = userInput(action);
		// Quotations will generally cause problems when
		// using the path with std.file and Windows. This removes the quotes.
		ans = ans.removechars("\";").strip;
		ans = ans[0] == '"' ? ans[1..$] : ans; // removechars skips first char
	} while(!exists(ans));

	return ans;
}

/**
 * Creates a menu from a Range of strings.
 * 
 * It will require that a number is selected within the number of options.
 * 
 * If the the return type is a string, the string in the options parameter will
 * be returned.
 *
 * Throws: NoInputException if the user wants to quit.
 */
T menu(T = ElementType!(Range), Range) (string question, Range options)
                     if((is(T==ElementType!(Range)) || is(T==int)) &&
                       isForwardRange!(Range)) {
	string ans;
	int maxI;
	int i;

	while(true) {
		writeln(question);
		i = 0;
		foreach(str; options) {
			writefln("%8s. %s", i+1, str);
			i++;
		}
		maxI = i+1;

		writefln("%8s. %s", "No Input", "Quit");
		ans = userInput!(string)("").strip;
		int ians;

		try {
			ians = to!(int)(ans);
		} catch(ConvError ce) {
			bool found;
			i = 0;
			foreach(o; options) {
				if(ans.tolower == to!string(o).tolower) {
					found = true;
					ians = i+1;
					break;
				}
				i++;
			}
			if(!found)
				throw ce;

		}

		if(ians > 0 && ians <= maxI)
			static if(is(T==ElementType!(Range)))
				static if(isRandomAccessRange!(Range))
					return options[ians-1];
				else {
					take!(ians-1)(options);
					return options.front;
				}
			else
				return ians;
		else
			writeln("You did not select a valid number.");
	}
}

/**
 * Requires that a value be provided and valid based on
 * the delegate passed in. It must also check against null input.
 *
 * --------
 * auto num = require!(int, "a > 0 && a <= 10")("Enter a number from 1 to 10");
 * --------
 *
 * Throws: NoInputException if the user does not provide any value.
 *         ConvError if the user does not provide any value.
 */
T require(T, alias cond)(ref string question) {
	alias unaryFun!(cond) call;
	T ans;
	do {
		ans = userInput!T(question);
	} while(!call(ans));

	return ans;
}

/**
 * Used when input was not provided.
 */
class NoInputException: Exception {
	this(string msg) {
		super(msg);
	}
}
