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
import std.date;
import std.file;
import std.functional;
import std.regex;
import std.string;

version(spelling_main) import std.stdio;

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

	auto ld1 = bestWord(candy[0]);
	auto ld2 = bestWord(candy[1]);
	if(ld1 is null) return ld2;
	if(ld2 is null) return ld1;

	if(binaryFun!predicate(model[ld1], model[ld2]))
		return ld2;	

	return ld1;
}

private string bestWord(string[] words) {
	if(words is null) return null;
	string curWord = words[0];
	foreach(candy; words)
	{
		if(model[curWord] < model[candy])
			curWord = candy;
	}

	return curWord;
}

/// Takes a Range of words and adds them to the dictionary
/// while at the same time increasing frequency of use.
/// This is similar to training the dictionary, but it assumes
/// all words are spelled correctly.
public void buildList(Range)(Range words) {
	foreach(w; words)
		model[w] += 1;
}

/// Takes a list of words and increases the frequency of use
/// only if the word is spelled correctly
/// You must first add words with buildList for this to work
/// it does not add new words to the list.
public void train(Range)(Range words) {
	foreach(w; words)
		if(!misspelled(w))
			model[w] += 1;
}

/// Tells if a given word is misspelled
public bool misspelled(string word) {
	if(word == "") return false;
	if(!match(word, regex(r"\d")).empty) return false;
	if(word in model)
		return false;
	return true;
}

/**
 * Returns two arrays of words that could be used for spelling correction.
 * The first list is of edit distence of one and the second of edit distance
 * of two.
 */
private string[][] candidates(string word) {
	string[][] candy = new string[][2];
	if(misspelled(word)) {
		foreach(w, i; model) {
			if(std.math.abs(cast(long)word.length - cast(long)w.length) > 1)
			{}
			else {
				auto dist = levenshteinDistance(w, word);
				if(dist == 1)
					candy[0] ~= w;
				if(dist == 2)
					candy[1] ~= w;
			}
		}
	}
	return candy;
}

version(spelling_main) {
	void main(string[] args) {
		if(args.length < 2) {
			std.stdio.writeln("Please pass a word to check");
			return;
		}

		auto start = getUTCtime();
		buildList(std.file.readText("big.txt").replace(regex(".?!"), " ").split);


		std.stdio.writeln((cast(float)(getUTCtime() - start))/ticksPerSecond);

		start = getUTCtime();


		if(misspelled(args[1]))
			std.stdio.writeln(giveWord(args[1]));
		else
			std.stdio.writeln("Why you little");
		std.stdio.writeln((cast(float)(getUTCtime() - start))/ticksPerSecond);
	}
}
