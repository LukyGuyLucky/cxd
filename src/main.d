module main;

import backend.codegen;
import frontend;
import builder;
import updater;
import errors;
import utils;
import env;

import std.path : dirName, baseName, extension;
import std.stdio : writeln, writefln, dwrite = write;
import core.stdc.stdlib : exit;
import std.algorithm;
import std.exception;
import std.process;
import std.format;
import std.getopt;
import std.array;
import std.file;
import std.string:startsWith,replace;

__gshared Generic generic;
__gshared bool noHeader;
__gshared string stdDir, OS;

pragma(inline, true)
bool isCommand(string[] argv, string command)
{
	return argv.length > 1 ? argv[1] == command : false;
}

pragma(inline, true)
void check_diagnostic(Diagnostics d)
{
	if (d.report())
		exit(1);
}

struct CXArgs 
{
	bool emitc, opt, dbg, verMessage, helpMessage, genHeader, cpp, gcc, stackTrace, checkNullPtr;
	string[] link, cflags;
	string output, target;
}

pragma(inline, true)
void showHelp()
{
	writeln("Usage:");
	writeln("	cx <command>");
	writeln("	cx <file.cx> [options]");
	writeln();
	writeln("Commands:");
	writeln("        update          Update your compiler to the latest version.");
	writeln("        compile         Compile your Cx project.");
	writeln("        init            Create your Cx project.");
	writeln("        run             Compile and execute your Cx project.");
	writeln();
	writeln("Options:");
	writeln(
		"  -o, --output <name>   Set the output binary name (default: input filename without .cx)");
	writeln("  -L, --link <lib>      Link an external library (can be used multiple times)");
	writeln("      --opt             Enable optimizations (-O2 in the underlying C compiler)");
	writeln("      --emit-c          Only emit the generated .c file, without compiling it");
	writeln("  -d, --debug           Print debug information, such as the C compiler in use");
	writeln("  -h, --help            Show this help message and exit");
	writeln("  -v, --version         Show the compiler version and exit");
	writeln("      --no-header       It will not automatically generate the Cx header.");
	writeln("      --gen-header      It will generate a .h file and a .c file without compiling at the end.");
	writeln("      --cflags      	Pass compilation flags to the C compiler.");
	writeln("      --cpp      	Compiles with a C++ compiler.");
	writeln("      --gcc      	Set GCC as the default compiler.");
	writeln("      --stack-trace  	Enables the compiler's stack-trace system in the binary.");
	writeln("      --check-null-ptr	Checks if the pointer is null upon each access.");
	writeln();
	writeln("Environment:");
	writeln("  CC                    C compiler used to build the output (default: tcc -> gcc -> cc)");
	writeln();
	writeln("Examples:");
	writeln("  cx update");
	writeln("  cx init");
	writeln("  cx run");
	writeln("  cx compile");
	writeln();
	writeln("  cx main.cx");
	writeln("  cx main.cx --opt -o main");
	writeln("  cx main.cx --cflags=\"--O2 -o main\"");
	writeln("  cx main.cx --emit-c");
	writeln("  cx main.cx -L m -L pthread -o app");
	writeln("  CC=x86_64-w64-mingw32-gcc cx main.cx -o main.exe");
	writeln();
	writeln("Made in Brazil");
}

pragma(inline, true)
void showVersion()
{
	writefln("Cx Compiler - Version (%s)", COMPILER_VERSION);
}

bool which(string c)
{
    version(Windows)
        return executeShell(format("where %s >nul 2>nul", c)).status == 0;
    else
        return executeShell(format("which %s", c)).status == 0;
}

int compile(string filename, ref CXArgs args)
{
	cx_enforce(extension(filename) == ".cx", "The file is not a valid .cx file.");
	cx_enforce(exists(filename), format("The file '%s' does not exist.", filename));

	string dir = dirName(filename) ~ "/";
	string content = readText(filename);
	string file = baseName(filename);
	args.output = args.output == "" ? file[0 .. $ - 3] : args.output;

	Diagnostics err = new Diagnostics;
	TypeRegistry registry = new TypeRegistry;

	Lexer l = new Lexer(file, dir, content, err, registry);
	ImportResolverContext* ctx = new ImportResolverContext(stdDir);
	generic = new Generic(registry);
	Program program;
	
	try {
		Token[] tokens = l.tokenizer();
		check_diagnostic(err);
		Parser p = new Parser(tokens, err, registry, generic, ctx);
		program = p.parse();
	}
	catch (Exception e)
	{
		check_diagnostic(err);
		writefln("An internal error occurred: %s", e.message);
		if (args.dbg) writeln(e);
		return 1;
	}

	check_diagnostic(err);

	// evaluate __eval(...) expressions at compile time
	new Comptime(program, err).resolve();
	check_diagnostic(err);

	// do two passes for the complete solution
	generic.resolve(program);
	generic.resolve(program);

	TypeResolver resolver = new TypeResolver(registry, err);
	resolver.resolve(program);
	check_diagnostic(err);

	program.body = ResolveSymbols.resolve(err, ctx, program.body);
	check_diagnostic(err);

	new StructOrder(err).resolve(program);
	check_diagnostic(err);

	string fileh = args.output ~ (args.cpp ? ".hpp" : ".h");
	string filec = args.output ~ (args.cpp ? ".cpp" : ".c");
	string[2] src = new CodeGen(program, registry, ctx.statics, noHeader, args.genHeader, 
		fileh, ctx, args.cpp, resolver, args.stackTrace, args.checkNullPtr).compile();
	check_diagnostic(err);
	write(filec, src[0]);

	if (args.genHeader)
	{
		write(fileh, src[1]);
		writefln("Success: two individual files, '%s' and '%s', were generated.", filec, fileh);
		return 0;
	}

	if (args.emitc)
	{
		writefln("File '%s' generated.", filec);
		return 0;
	}

	string comp = args.gcc ? "gcc" : (which("tcc") ? "tcc" : (which("gcc") ? "gcc" : "cc"));
	if (args.cpp)
	{
		// decide o compilador a ser usado
		comp = which("g++") ? "g++" : (which("clang++") ? "clang++" : "");
		if (!comp)
		{
			writeln("It was not possible to define a default C++ compiler. Use the CC variable to define one.");
			return 1;
		}
	}

	//string c_compiler = environment.get("CC", comp);
	string c_compiler;
	if (args.cpp)
	{
		c_compiler = which("g++") ? "g++" : (which("clang++") ? "clang++" : environment.get("CC", "g++"));
	}
	else
	{
		c_compiler = environment.get("CC", comp);
	}
	
	string cppLib = args.cpp ? "-lstdc++ -fpermissive" : "";
	
	string cflagsJoined = args.cflags.join(" ").replace("\n", " ").replace("\r", " ");
	string command = format("%s %s %s %s -o %s %s %s %s",
		c_compiler,
		filec,
		!args.stackTrace ? "-DCX_NO_TRACE" : "",
		(args.opt ? "-O2" : ""),
		args.output,
		args.link.length > 0 ? (args.link.map!(l => format("-l%s", l).array).join(" ")) : "",
		cppLib,
		cflagsJoined);
	
	if (args.dbg)
		writeln("C Compiler: ", c_compiler);

	auto exec = executeShell(command);
	if (args.dbg)
		writeln("Command: ", command);

	if (exec.status != 0)
	{
		writeln("An error occurred while compiling the program.");
		writeln(exec.output);
		return exec.status;
	}

	executeShell(format("rm -f %s", filec));
	return 0;
}

int runTest(string[] argv)
{
    cx_enforce(argv.length >= 3, "Usage: cx test <file.cx>");
    string filename = argv[2];

    cx_enforce(extension(filename) == ".cx", "Not a .cx file.");
    cx_enforce(exists(filename), format("File '%s' not found.", filename));

    string dir = dirName(filename) ~ "/";
    string content = readText(filename);
    string file = baseName(filename);
    string output = file[0 .. $ - 3];

    Diagnostics err = new Diagnostics;
    TypeRegistry registry = new TypeRegistry;

    Lexer l = new Lexer(file, dir, content, err, registry);
    ImportResolverContext* ctx = new ImportResolverContext(stdDir);
    generic = new Generic(registry);

    Program program;
    try
    {
        Token[] tokens = l.tokenizer();
        check_diagnostic(err);
        Parser p = new Parser(tokens, err, registry, generic, ctx);
        program = p.parse();
    }
    catch (Exception e)
    {
        check_diagnostic(err);
        writefln("Parse error: %s", e.message);
        writeln(e);
        return 1;
    }
    check_diagnostic(err);

    // Collect test blocks
    TestBlock[] tests;
    foreach (node; program.body)
    {
        if (auto tb = cast(TestBlock) node)
            tests ~= tb;
    }

    if (tests.length == 0)
    {
        writeln("No test blocks found in ", filename);
        return 0;
    }

    // Rename user `main` to avoid conflict with generated runner
    foreach (ref node; program.body)
    {
        if (auto fn = cast(FnDecl) node)
            if (fn.name == "main")
                fn.name = "__cx_user_main";
    }

    // Generate one runner function per test block
    foreach (i, tb; tests)
    {
        string fnName = format("__cx_test_%d", i);
        FnDecl runner = new FnDecl(fnName, [], tb.body,
            new TypeExprNamed("void"), tb.pos, 0);
        program.body ~= runner;
    }

    // Generate main() that calls all runners and reports
    Node[] mainBody;
    foreach (i, tb; tests)
    {
        mainBody ~= new CallExpr(
            new IdentExpr(format("__cx_test_%d", i),
                new TypeExprNamed("void"), tb.pos),
            [], tb.pos);
    }

    mainBody ~= new CallExpr(
        new IdentExpr("printf", new TypeExprNamed("int"), Position.init),
        [
            new StringLit("\\n=== %d passed, %d failed ===\\n", Position.init),
            new IdentExpr("__cx_test_passed", new TypeExprNamed("int"), Position.init),
            new IdentExpr("__cx_test_failed", new TypeExprNamed("int"), Position.init)
        ],
        Position.init);

    mainBody ~= new ReturnStmt(
        new IdentExpr("__cx_test_failed", new TypeExprNamed("int"), Position.init),
        Position.init);

    program.body ~= new FnDecl("main", [], mainBody,
        new TypeExprNamed("int"), Position.init, 0);

    // Standard pipeline
    generic.resolve(program);
    generic.resolve(program);

    TypeResolver resolver = new TypeResolver(registry, err);
    resolver.resolve(program);
    check_diagnostic(err);

    program.body = ResolveSymbols.resolve(err, ctx, program.body);
    check_diagnostic(err);

    new StructOrder(err).resolve(program);
    check_diagnostic(err);

    string filec = output ~ ".c";
    string[2] src = new CodeGen(program, registry, ctx.statics, noHeader, false,
        "", ctx, false, resolver, false, false).compile();
    check_diagnostic(err);
    write(filec, src[0]);

    // Compile
    string comp = which("gcc") ? "gcc" : "cc";
    string command = format("%s %s -o %s", comp, filec, output);
    auto exec = executeShell(command);
    if (exec.status != 0)
    {
        writeln("Compile failed:");
        writeln(exec.output);
        return 1;
    }

    // Run
    string execPath = OS == "windows" ? output ~ ".exe" : "./" ~ output;
    auto run = executeShell(execPath);
    dwrite(run.output);
    return run.status;
}

int main(string[] argv)
{
	/*
	version (Windows)
	{
		writeln(
			"The compiler does not yet support Windows, even though there is a build script and you managed to compile it.");
		return 1;
	}
	*/
	CXArgs args;
	
	version (OSX)
	    OS = "macos";
	else version (linux)
	    OS = "linux";
	else version (Posix)
	    OS = "unix";
	else version (Windows)
		OS = "windows";
	else
	    OS = "unknown";

	if (OS == "unknown")
	{
		writefln("Unable to detect your operating system, please create an issue in the GitHub repository: '%s'", 
			GITHUB_REPO);
		return 0;
	}

	version (Windows)
	{
		string home = thisExePath().dirName();
		stdDir = home ~ "/";
	}
	else
	{
		string home = environment.get("HOME", "");
		stdDir = home ~ "/" ~ ".cx/";
	}

	if (!exists(stdDir))
	{
		writefln("An error occurred while validating the compiler installation.");
		// ...
		return 0;
	}

	if (isCommand(argv, "update"))
		return runUpdate();

	if (isCommand(argv, "init"))
		return runBuild();

	if (isCommand(argv, "test"))
		return runTest(argv);

	bool isRun = isCommand(argv, "run");
	if (isCommand(argv, "compile") || isRun)
	{
		if (argv.canFind("--debug") || argv.canFind("-d"))
			args.dbg = true;
			
		foreach (i, arg; argv) {
			if (arg == "--cflags" && i + 1 < argv.length)
				args.cflags ~= argv[i + 1].replace("\n", " ").replace("\r", " ");
			else if (arg.startsWith("--cflags="))
				args.cflags ~= arg["--cflags=".length .. $].replace("\n", " ").replace("\r", " ");
		}
		
		if (argv.canFind("--cpp"))
			args.cpp = true;
		if (argv.canFind("--gcc"))
			args.gcc = true;
		if (argv.canFind("--opt"))
			args.opt = true;
		return runCompile(isRun, args);
	}

	try
		getopt(argv,
			"opt", 		  	  &args.opt,
			"version|v",  	  &args.verMessage,
			"help|h", 	  	  &args.helpMessage,
			"debug|d",    	  &args.dbg,
			"emit-c",     	  &args.emitc,
			"link|L",     	  &args.link,
			"output|o",   	  &args.output,
			"target", 	  	  &args.target,
			"no-header",  	  &noHeader,
			"gen-header", 	  &args.genHeader,
			"cflags",     	  &args.cflags,
			"cpp", 	      	  &args.cpp,
			"gcc", 	      	  &args.gcc,
			"stack-trace",	  &args.stackTrace,
			"check-null-ptr", &args.checkNullPtr,
		);
	catch (GetOptException e)
	{
		writefln("Invalid flag '%s'.", e.message[20 .. $]);
		return 1;
	}

	if (args.verMessage)
	{
		showVersion();
		return 0;
	}

	if (args.helpMessage)
	{
		showHelp();
		return 0;
	}

	cx_enforce(argv.length == 2, "The compiler expects at least one file, see 'cx -h'.");
	return compile(argv[1], args);
}
