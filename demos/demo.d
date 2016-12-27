module main;

import qscript;
import std.stdio;
import std.datetime;

class Tqfuncs{
private:
	Tqvar qwrite(Tqvar[] args){
		foreach(arg; args){
			write(arg.s);
		}
		Tqvar r;
		return r;
	}
	Tqvar qread(Tqvar[] args){
		Tqvar r;
		r.s = readln;
		r.s.length--;
		return r;
	}
	Tqvar delegate(Tqvar[])[string] pList;
public:
	this(){
		pList = [
			"qwrite":&qwrite,
			"qread":&qread
		];
	}
	Tqvar call(string name, Tqvar[] args){
		Tqvar r;
		if (name in pList){
			r = pList[name](args);
		}else{
			throw new Exception("unrecognized function call "~name);
		}
		return r;
	}
}

/*run it like this from terminal:
 * './demo' '/path/to/the/script/file'
 */
void main(string[] args){
	debug{//This is only for me, comment this out if you plan to use -debug
		args.length = 2;
		args[1] = "/home/nafees/Desktop/q.qod";
	}
	Tqscript scr = new Tqscript;
	Tqfuncs scrF = new Tqfuncs;
	string[] errors = scr.loadScript(args[1]);
	if (errors){
		writeln("There are errors in script: ");
		foreach(error; errors){
			writeln(error);
		}
	}else{
		scr.setOnExec(&scrF.call);
		StopWatch sw;
		sw.start;
		scr.executeFunction("main",[]);
		sw.stop;
		writeln("\nExecution ended in ",sw.peek().msecs," msecs!");
	}
	delete scr;
	delete scrF;
}