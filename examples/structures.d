/**
 * This example uses a structure for iterating over records.
 */
import std.stdio;

import csv;

void main() {
	structs();
}

struct CustType {
	int aint;
	string astring;
	double adouble;
}

void structs() {
	auto str = "20,M,5.8\n34,F,5.5";
	auto records = csvText!CustType(str);

	foreach(data; records) {
		writeln("--------");
		writeln(data.astring);
		writeln(data.aint);
		writeln(data.adouble, "'");
	}

}
