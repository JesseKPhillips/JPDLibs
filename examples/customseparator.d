/*
 */
import std.stdio;

import csv;

void main() {
	writeln("Printing strings");
	strings();
	writeln("\nPrinting doubles");
	doubles();
}

void strings() {
	string str = `one|two|"three ""quoted"""|""|`
	  "\"line 1\nline 2\"\nNew record";
	auto records = RecordList!(string,Malformed.throwException,string,dchar)(str, '|', '"');

	foreach(record; records) {
		writeln("-----------");
		foreach(cell; record) {
			writeln("[", cell, "]");
		}
	}
}

void doubles() {
	string str = "5|35.5|63.15";
	auto records = RecordList!(double,Malformed.throwException,string,dchar)(str, '|', '"');

	foreach(record; records) {
		writeln("-----------");
		foreach(cell; record) {
			writeln("[", cell, "]");
		}
	}
}

