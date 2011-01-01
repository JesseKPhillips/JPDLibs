/*
 */
import std.stdio;

import csv;

void main() {
	writeln("Printing strings");
	strings();
	writeln("\nPrinting doubles");
	doubles();
	writeln("\nPrinting with string based sep");
	doubleSep();
}

void strings() {
	string str = `Hello|World|"Hi ""There"""|""|`
	  "line 1\nline 2&New record";
	auto records = RecordList!(string,"Checked",string,dchar)(str, '|', '"', '&');

	foreach(record; records) {
		writeln("-----------");
		foreach(cell; record) {
			writeln("[", cell, "]");
		}
	}
}

void doubles() {
	string str = "5|35.5|63.15";
	auto records = RecordList!(double,"Checked",string,dchar)(str, '|', '"', '&');

	foreach(record; records) {
		writeln("-----------");
		foreach(cell; record) {
			writeln("[", cell, "]");
		}
	}
}

void doubleSep() {
	string str = "5||35.5||63.15";
	auto records = RecordList!(double,"Checked",string,string)(str, "||", "\"", "&");

	foreach(record; records) {
		writeln("-----------");
		foreach(cell; record) {
			writeln("[", cell, "]");
		}
	}
}
