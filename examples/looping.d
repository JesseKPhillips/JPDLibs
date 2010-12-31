/**
 * This example iterates over each cell of each record and
 * demonstrates this method over several data types.
 */
module examples.looping;

import std.stdio;

import csv;

void main() {
	writeln("Printing strings");
	strings();
	writeln("\nPrinting doubles");
	doubles();
}

void strings() {
	string str = `Hello,World,"Hi ""There""","",` 
	  ~ "\"line 1\nline 2\"\nNew record";
	auto records = csvText(str);

	foreach(record; records) {
		writeln("-----------");
		foreach(cell; record) {
			writeln("[", cell, "]");
		}
	}
}

void doubles() {
	string str = "5,35.5,63.15";
	auto records = csvText!double(str);

	foreach(record; records) {
		writeln("-----------");
		foreach(cell; record) {
			writeln("[", cell, "]");
		}
	}
}
