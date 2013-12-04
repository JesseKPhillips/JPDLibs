/**
 * Spelling suggestion based on the Spelling Corrector found at:
 * norvig.com/spell-correct.html
 * 
 * A word list, big.txt can also be downloaded from the website:
 * norvig.com/big.txt
 *
 * Synopsis:
 * --------
 * buildList(std.file.readText("big.txt").replace(regex(".?!"), " ").split);
 *
 * if(misspelled(args[1]))
 *     std.stdio.writeln(giveWord(args[1]));
 * --------
 */

module spelling.suggestion;

import std.algorithm;
import std.array;
import std.file;
import std.functional;
import std.regex;
import std.string;

private int[string] model;
/**
 * Give a suggested word based the given word.
 *
 * The selection is based on the fequency of words per the training
 * and the edit distance of the given word to the suggestion.
 * If there are no known words within an edit distance of two
 * the given word is returned unchanged.
 *
 * The word with the fewest edits is returned unless the predicate is true.
 * Where a is the fequency of edit distance one and b is the frequency of
 * edit distance two.
 */
public string giveWord(alias predicate = "a <= 1 && b > 4")(string word) {
	auto candy = candidates(word);
	if(candy[0].empty && candy[1].empty) return word;

	auto ld1 = minPos!((a,b) => model[a] > model[b])(candy[0]);
	auto ld2 = minPos!((a,b) => model[a] > model[b])(candy[1]);
	if(ld1.empty) return ld2.front;
	if(ld2.empty) return ld1.front;

	if(binaryFun!predicate(model[ld1.front], model[ld2.front]))
		return ld2.front;

	return ld1.front;
}

unittest {
    scope(exit) model = null;
    buildList(["hello","hello","held","hells","electronic"]);
    auto hello = giveWord("helo");
    assert(hello == "hello");
    auto electronic = giveWord("ellectonic");
    assert(electronic == "electronic");
    auto uknwon = giveWord("uknwon");
    assert(uknwon == "uknwon");
}

/**
 * Takes a Range of words and adds them to the dictionary
 * while at the same time increasing frequency of use.
 *
 * This is similar to training the dictionary, but it assumes
 * all words are spelled correctly.
 */
public void buildList(Range)(Range words) {
	foreach(w; words)
		model[w] += 1;
}

/**
 * Takes a list of words and increases the frequency of use
 * only if the word is spelled correctly
 *
 * You must first add words with buildList for this to work
 * it does not add new words to the list.
 */
public void train(Range)(Range words) {
	foreach(w; words)
		if(!misspelled(w))
			model[w] += 1;
}

/// Tells if a given word is misspelled
public bool misspelled(string word) {
	if(word.empty) return false;
	if(word in model)
		return false;
	return true;
}

unittest {
    assert(!misspelled(""));
    assert(!misspelled(null));
}

/**
 * Returns two arrays of words that could be used for spelling correction.
 * The first list is of edit distence of one and the second of edit distance
 * of two.
 */
private string[][] candidates(string word) {
	string[][] candy = new string[][2];
	if(!misspelled(word))
        return candy;
    foreach(w, i; model) {
        if(std.math.abs(cast(long)word.length - cast(long)w.length) > 2)
        { /* a length difference greater than 2 is more than 2 edits */ }
        else {
            auto dist = levenshteinDistance(w, word);
            if(dist == 1)
                candy[0] ~= w;
            if(dist == 2)
                candy[1] ~= w;
        }
    }
	return candy;
}

unittest {
    scope(exit) model = null;
    buildList(["hello","held","hells"]);
    auto candy = candidates("helo");
    assert(candy[0].sort.equal(["hello", "held"].sort));
    assert(candy[1].equal(["hells"]));
}

version(spelling_main) {
import std.stdio;
import std.datetime;

alias std.regex.split split;

	void main(string[] args) {
		if(args.length < 2) {
			std.stdio.writeln("Please pass a word to check");
			return;
		}

        StopWatch sw;
        sw.start();
		buildList(std.file.readText("big.txt").toLower().match(regex(r"\w+", "g")).map!(a => a.hit)());

		writefln("Build %s msecs", sw.peek().msecs);

        sw.reset();
        sw.start();
		if(misspelled(args[1]))
			std.stdio.writeln(giveWord(args[1]));
		else
			std.stdio.writeln("Why you little");

		writefln("Suggest %s msec", sw.peek().msecs);
	}
}
