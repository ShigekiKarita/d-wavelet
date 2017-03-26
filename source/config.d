module config;
import std.stdio;
import std.getopt;
import file = std.file;

import std.json;
import std.traits;

/// Converts a JSONValue to a primitive D type known at compile time
T convertJsonTo(T)(JSONValue value)
{
	// TODO: replace this function with custom function if more advanced JSON values in config are required

	static if (is(T == string))
		return value.str;
	else static if (isFloatingPoint!T)
		return cast(T) value.floating;
	else static if (isNumeric!T)
		return cast(T) value.integer;
	else static if (isArray!T)
	{
		T[] ret = new T[value.array.length];
		foreach (i, member; value.array)
			ret[i] = convertJsonTo!(typeof(ret[0]))(member);
		return ret;
	}
	else
		static assert(0, "Can't cast JSONValue to type " ~ T.stringof);
}

/// Reads a config value from the specified config and writes it to `valueOutput`
/// Returns: true if value was found
bool readFromConfig(T)(ref T valueOutput, JSONValue config, string key)
{
	auto valuePointer = key in config;
	if (valuePointer)
	{
		valueOutput = convertJsonTo!T(*valuePointer);
		return true;
	}
	else
		return false;
}


// config/command line variables
string input;

int configMain(string[] args)
{
	if (file.exists("config.json"))
	{
		// parse JSON from config.json if exists
		auto config = parseJSON(file.readText("config.json"));

		// Read a value from config.json if exists
		input.readFromConfig(config, "input");
		// TODO: add own config values
	}

	//dfmt off
	// TODO: add own command line arguments
	auto helpInformation = getopt(args,
		"input", "Input file to process", &input);
	//dfmt on

	if (helpInformation.helpWanted)
	{
		defaultGetoptPrinter("Some information about the program", helpInformation.options);
		return 2;
	}

	// Program code here
	writeln("File to process: ", input ? input : "stdin");

	return 0;
}


