﻿module qscript.compiler.compiler;

import qscript.compiler.misc;
import qscript.compiler.tokengen;
import qscript.compiler.ast;
import qscript.compiler.astgen;
import qscript.compiler.codegen;

import utils.misc;

/// To store information about a pre-defined function, for use at compile-time
public struct Function{
	/// the name of the function
	string name;
	/// the data type of the value returned by this function
	DataType returnType;
	/// stores the data type of the arguments received by this function
	private DataType[] storedArgTypes;
	/// the data type of the arguments received by this function
	@property ref DataType[] argTypes(){
		return storedArgTypes;
	}
	/// the data type of the arguments received by this function
	@property ref DataType[] argTypes(DataType[] newArray){
		return storedArgTypes = newArray.dup;
	}
	/// constructor
	this (string functionName, DataType functionReturnType, DataType[] functionArgTypes){
		name = functionName;
		returnType = functionReturnType;
		storedArgTypes = functionArgTypes.dup;
	}
}

/// Stores compilation error
public alias CompileError = qscript.compiler.misc.CompileError;

/// stores data type
public alias DataType = qscript.compiler.misc.DataType;

/// compiles a script from string[] to bytecode (in string[]).
/// 
/// 
public string[] compileQScriptToByteCode(string[] script, Function[] predefinedFunctions, ref CompileError[] errors){
	/// called by ASTGen to get return type of pre-defined functions
	DataType onGetReturnType(string name, DataType[] argTypes){
		// some hardcoded stuff
		if (name == "setLength"){
			// return type will be same as the first argument type
			if (argTypes.length != 2){
				throw new Exception ("setLength called with invalid arguments");
			}
			return argTypes[1];
		}else if (name == "getLength"){
			// int
			return DataType(DataType.Type.Integer);
		}else if (name == "array"){
			// return array of the type received
			if (argTypes.length < 1){
				throw new Exception ("cannot make an empty array using 'array()', use [] instead");
			}
			DataType r = argTypes[0];
			r.arrayNestCount ++;
			return r;
		}else{
			// search in `predefinedFunctions`
			foreach (currentFunction; predefinedFunctions){
				if (currentFunction.name == name){
					return currentFunction.returnType;
				}
			}
			throw new Exception ("function '"~name~"' not defined");
		}
	}
	/// called by ASTGen to check if a pre-defined function is called with arguments of ok-type
	bool onCheckArgsType(string name, DataType[] argTypes){
		// over here, the QScript pre-defined functions are hardcoded :(
		if (name == "setLength"){
			// first arg, must be array, second must be int
			if (argTypes.length == 2 && argTypes[0].arrayNestCount > 0 &&
				argTypes[1].type == DataType.Type.Integer && argTypes[1].arrayNestCount == 0){
				return true;
			}else{
				return false;
			}
		}else if (name == "getLength"){
			// first arg, the array, that's it!
			if (argTypes.length == 1 && argTypes[0].arrayNestCount > 0){
				return true;
			}else{
				return false;
			}
		}else if (name == "array"){
			// must be at least one arg
			if (argTypes.length < 1){
				return false;
			}
			// and all args must be of same type
			foreach (type; argTypes){
				if (type != argTypes[0]){
					return false;
				}
			}
			return true;
		}else{
			// now check the other functions
			foreach (currentFunction; predefinedFunctions){
				if (currentFunction.name == name){
					return matchArguments(currentFunction.argTypes.dup, argTypes);
				}
			}
			throw new Exception ("function '"~name~"' not defined");
		}
	}
	// first convert to tokens
	errors = [];
	TokenList tokens = toTokens(script.dup, errors);
	if (errors.length > 0){
		return [];
	}
	// then generate the AST
	ScriptNode scriptAST;
	ASTGen astGenerator = ASTGen(&onGetReturnType, &onCheckArgsType);
	// generate the ast
	scriptAST = astGenerator.generateScriptAST(tokens, errors);
	if (errors.length > 0){
		return [];
	}
	// now finally the byte code
	CodeGen byteCodeGenerator;
	string[] code = byteCodeGenerator.generateByteCode(scriptAST, errors);
	if (errors.length > 0){
		return [];
	}
	return code;
}

import utils.lists;

import qscript.qscript : QData;

/// converts bytecode into an array of functions-pointer. Can be used to convert to other types as well
T[][string] convertByteCodeInstructions(T)(string[] bCode, T[string] instructions, ref string[] errors){
	/// converts byte code into separate byte code for separate functions
	static string[][string] separateFunctions(string[] byteCode){
		string name = null; // name of function being read
		string[][string] r;
		for (uinteger i = 0, readFrom, lastInd = byteCode.length-1; i < byteCode.length; i ++){
			if (name == null){
				// function name expected
				if (byteCode[i].length > 0 &&  byteCode[i][0] != '\t'){
					name = byteCode[i];
					readFrom = i+1;
					continue;
				}else{
					throw new Exception("syntax error in byte code");
				}
			}else{
				if (byteCode[i].length > 0){
					// check if this function is over
					if (byteCode[i][0] != '\t'){
						// save last function
						r[name] = bCode[readFrom .. i].dup;
						name = byteCode[i];
						readFrom = i+1;
						continue;
					}
				}else{
					throw new Exception ("syntax error in byte code");
				}
				// or if it's the last line, then too save the byte code
				if (i == lastInd){
					r[name] = byteCode[readFrom .. i+1].dup;
				}
			}
		}
		return r;
	}

	/// returns arguments of instruction, in string (as it-is), or in QData
	static auto getInstructionArgs(bool inQData=true)(string instruction){
		if (instruction.length == 0){
			throw new Exception ("instruction cannot be empty string");
		}
		if (instruction[0] != '\t'){
			throw new Exception ("invalid instruction, not begining with a tab");
		}
		// first, skip the instruction
		uinteger i;
		for (i = 1; i < instruction.length; i ++){
			if (instruction[i] == ' '){
				break;
			}
		}
		if (i >= instruction.length){
			return []; // no args
		}
		// else, there are args
		string argsString = instruction[i+1 .. instruction.length];
		LinkedList!string argsList = new LinkedList!string;
		i = 0;
		for (uinteger lastInd = argsString.length-1, readFrom = 0; i < argsString.length; i++){
			if (argsString[i] == ' '){
				argsList.append (argsString[readFrom .. i]);
				readFrom = i + 1;
				continue;
			}else if (i == lastInd){
				argsList.append (argsString[readFrom .. i+1]);
				break;
			}
		}
		string[] args = argsList.toArray;
		.destroy (argsList);
		// convert to QData
		QData[] r;
		r.length = args.length;
		foreach (i, arg; args){
			r[i] = stringToQData(arg);
		}
		return r;
	}
	/// adds a jump index
	struct{
		/// stores jump indexes, for current function
		private uinteger[string] jumpIndex;
		/// adds a new jump index, if the name is already taken, it's over-written
		public void addJumpIndex(string jumpName, uinteger index){
			jumpIndex[jumpName] = index;
		}
		/// returns a index for a jump name, throws Exception if doesnt exist
		public uinteger getJumpIndex(string jumpName){
			if (jumpName in jumpIndex){
				return jumpIndex[jumpName];
			}else{
				throw new Exception("jump '"~jumpName~"' not found");
			}
		}
		/// removes all jump indexes/names
		public void resetJumps(){
			foreach (key; jumpIndex.keys){
				jumpIndex.remove (key);
			}
		}
		/// adds jumps from byte code, throws Exception on any error,
		/// the byte code must be of a single function, without the fnuctionName at start
		void addJumpIndex(string[] byteCode){
			foreach (i, line; byteCode){
				if (line.length > 0 && line[line.length-1] == ':'){
					// is a jump
					// read the name
					uinteger readFrom;
					for (readFrom = 0; readFrom < line.length; readFrom ++){
						if (line[readFrom] != ' ' && line[readFrom] != '\t'){
							break;
						}
					}
					string jumpName = line[readFrom .. line.length - 1];
					jumpIndex[jumpName] = i;
				}
			}
		}
	}
}