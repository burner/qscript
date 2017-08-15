﻿module qscript.compiler.optimizer;

import qscript.qscript : QData; // for VarStore
import qscript.compiler.ast;
import qscript.compiler.misc;
import utils.misc;
import utils.lists;

/// struct providing functions to optimize an check the AST for errors
public struct ASTOptimize{
	/// stores the VarStore where all variables will be stored
	VarStore vars;
	/// stores a list telling whether a function is static or not
	bool[string] staticFunctions;
	/// stores a list of script-defined functions
	/// the struct which will be used to check if a node is static or not
	CheckStatic isStatic;
	/// stores name of functions(index) defined in script and if they were used or not (bool, true/false)
	private bool[string] functionsUsed;
	/// optimizes and looks for errors in the scriptNode. Returns the optimized scriipt
	/// Errors are appended to `qscript.compiler.misc.compileErrors`
	/// 
	/// `script` is the ASTNode with type as ASTNode.Type.Script
	/// `staticFuncs` is a list of functions that are static, and are ok with being evaluated at compile time
	public ASTNode optimizeScript(ASTNode script, string[] staticFuncs){
		// make sure scriptNode was received
		if (script.type == ASTNode.Type.Script){
			// put all staticFuncs in staticFunctions
			foreach (funcName; staticFuncs){
				staticFunctions[funcName] = true;
			}
			// add all sctipt-defined-functions to list, and put them all in a list
			foreach (subNode; script.subNodes){
				functionsUsed[subNode.data] = false;
			}
			// now comes the time to init the Check if Static
			isStatic = CheckStatic(&vars, staticFuncs, functionsUsed.keys.dup);
			// make sure all suNodes are functions, and call functions to optimize & check those nodes as well
			foreach (i, subNode; script.subNodes){
				// optimize it
				script.subNodes[i] = optimizeFunction(subNode);
			}
			// removed all unused functions
			for (uinteger i = 0; i < script.subNodes.length; i ++){
				if (script.subNodes[i].data !in functionsUsed || functionsUsed[script.subNodes[i].data] == false){
					// not used, remove it
					script.subNodes = script.subNodes.deleteElement(i);
					i --;
				}
			}
			return script;
		}else{
			compileErrors.append(CompileError(script.lineno, "ASTOptimize.optimizeScript can only be called with a node of type script"));
			return script;
		}
	}

	/// optimizes and looks for errors in functions nodes
	private ASTNode optimizeFunction(ASTNode functionNode){
		// make sure it is a function
		if (functionNode.type == ASTNode.Type.Function){
			// ok
			ASTNode block;
			integer blockIndex = functionNode.readSubNode(ASTNode.Type.Block);
			if (blockIndex == -1){
				compileErrors.append(CompileError(functionNode.lineno, "Function definition has no body"));
			}
			block = functionNode.subNodes[blockIndex];
			// check and optimize each and every node
			foreach (i, statement; block.subNodes){
				block.subNodes[i] = optimizeStatement(statement);
			}
			functionNode.subNodes[blockIndex] = block;
			return functionNode;
		}else{
			compileErrors.append(CompileError(functionNode.lineno, "ASTOptimize.optimizeFunction can only be called with a node of type function"));
			return functionNode;
		}
	}

	/// optimizes and looks for errors in a statement
	/// TODO complete this function
	private ASTNode optimizeStatement(ASTNode statement){
		// TODO continue from here
		// check if is a functionCall
		if (statement.type == ASTNode.Type.FunctionCall){
			statement = optimizeFunctionCall(statement);
		}else if (statement.type == ASTNode.Type.Assign){

		}else if (statement.type == ASTNode.Type.Block){

		}else if (statement.type == ASTNode.Type.IfStatement){

		}else if (statement.type == ASTNode.Type.VarDeclare){

		}else if (statement.type == ASTNode.Type.WhileStatement){

		}else{
			// not a valid statement
			compileErrors.append(CompileError(statement.lineno, "Not a valid statement"));
		}
		return statement;
	}

	/// optimizes and looks for erros in a functionCall
	/// TODO complete this function
	private ASTNode optimizeFunctionCall(ASTNode fCall){
		// can only optimize arguments, i.e: put in var value if static etc
		// add it to the called list
		if (fCall.data in functionsUsed){
			functionsUsed[fCall.data] = true;
		}
		// check arguments
		integer argsIndex = fCall.readSubNode(ASTNode.Type.Arguments);
		ASTNode args;
		if (argsIndex >= 0){
			args = fCall.subNodes[argsIndex];
		}
		// go through each arg


		return fCall;
	}
}


/// provides functions to check if something can be evaluated at runtime
private struct CheckStatic{

	/// stores a ref to the VarStore, so it can retrieve if a var is known or not
	VarStore* vars;
	private enum IsStatic{
		Yes,
		No,
		Undefined
	}
	/// stores a list of all functions, and if they are static or not
	IsStatic[string] functions;


	this(VarStore* varStore, string[] staticFuncs, string[] scriptDefinedFuncs){
		vars = varStore;
		// put all static functions in it now
		foreach (funcName; staticFuncs){
			functions[funcName] = IsStatic.Yes;
		}
		// put scriptDefinedFuncs in functions
		foreach (funcName; scriptDefinedFuncs){
			// need to determine if it's static or not, coz these are script-defined
			functions[funcName] = IsStatic.Undefined;
		}
	}



	/// checks if a node is static (true), or not (false)
	/// 
	/// works with:
	/// 1. FunctionCall
	/// 2. FunctionDefinition
	/// 3. IfStatement
	/// 4. WhileStatement
	/// 5. Block
	/// 6. Assign
	/// 7. Operator
	/// 8. Variable
	/// 9. StaticArray
	/// 9. NumberLiteral (always returns true on this, obviously)
	/// 9. StringLiteral (alwats return true no this, obviously)
	/// 
	/// TODO complete this
	bool isStatic(ASTNode node){
		if (node.type == ASTNode.Type.NumberLiteral){
			return true;
		}else if (node.type == ASTNode.Type.StringLiteral){
			return true;
		}else if (node.type == ASTNode.Type.FunctionCall){
			return functionCallIsStatic(node);
		}else if (node.type == ASTNode.Type.Function){
			return functionIsStatic(node);
		}else if (node.type == ASTNode.Type.IfStatement){
			return ifWhileStatementIsStatic(node);
		}else if (node.type == ASTNode.Type.WhileStatement){
			return ifWhileStatementIsStatic(node);
		}else if (node.type == ASTNode.Type.Block){
			return blockIsStatic(node);
		}else if (node.type == ASTNode.Type.Assign){
			return assignIsStatic(node);
		}else if (node.type == ASTNode.Type.Operator){
			return operatorIsStatic(node);
		}else if (node.type == ASTNode.Type.Variable){
			return variableIsStatic(node);
		}else if (node.type == ASTNode.Type.StaticArray){
			return staticArrayIsStatic(node);
		}else{
			// anything else cannot/shouldn't be optimized
			return false;
		}
	}

	/// checks if a functionCall is static (i.e if all of it's arguments are constant)
	private bool functionCallIsStatic(ASTNode fCall){
		// check if is it's already stored
		if (fCall.data in functions && functions[fCall.data] == IsStatic.No){
			return false;
		}else{
			// only need to look in arguments
			integer argsIndex = fCall.readSubNode(ASTNode.Type.Arguments);
			ASTNode args;
			if (argsIndex >= 0){
				args = fCall.subNodes[argsIndex];
			}
			// check the args
			foreach (arg; args.subNodes){
				if (!isStatic(arg)){
					return false;
				}
			}
			return true;
		}
	}
	
	/// checks if an operator is static
	private bool operatorIsStatic(ASTNode operator){
		// get operands
		ASTNode[] operands = operator.subNodes;
		if (operands.length != 2){
			// invalid, no idea how it escaped `ast.d`
			compileErrors.append(CompileError(operator.lineno, "operators can only receive 2 arguments"));
			return false;
		}else{
			// check if static
			foreach (operand; operands){
				if (!isStatic(operand)){
					return false;
				}
			}
			return true;
		}
	}

	/// checks if a function is static, i.e, if it can be evaluated at compile time
	private bool functionIsStatic(ASTNode fDef){
		// check if already known
		if (fDef.data in functions && functions[fDef.data] != IsStatic.Undefined){
			if (functions[fDef.data] == IsStatic.Yes){
				return true;
			}else{
				return false;
			}
		}else{
			// only need to check the block
			ASTNode block;
			{
				integer blockIndex = fDef.readSubNode(ASTNode.Type.Block);
				if (blockIndex == -1){
					compileErrors.append(CompileError(fDef.lineno, "function has no body"));
					return false;
				}
				block = fDef.subNodes[blockIndex];
			}
			// mark it as static/non-static, to make stuff faster
			bool r = blockIsStatic(block);
			functions[fDef.data] = IsStatic.No;
			if (r){
				functions[fDef.data] = IsStatic.Yes;
			}
			return r;
		}
	}

	/// checks if a block is static
	private bool blockIsStatic(ASTNode block){
		// check each and every statement using `isStatic`
		foreach (statement; block.subNodes){
			if (!isStatic(statement)){
				return false;
			}
		}
		return true;
	}

	/// checks if an if/while statement is static, i.e if the condition can be evaluated at compile-time
	private bool ifWhileStatementIsStatic(ASTNode ifStatement){
		// make sure there are 2 nodes, one is the condition, other is the block
		if (ifStatement.subNodes.length != 2){
			compileErrors.append(CompileError(ifStatement.lineno, "if statement has other than 2 nodes"));
			return false;
		}else{
			ASTNode condition = ifStatement.subNodes[0];
			if (ifStatement.subNodes[1].type != ASTNode.Type.Block){
				condition = ifStatement.subNodes[1];
			}
			// now check if it is static or not
			return isStatic(condition);
		}
	}

	/// checks if an assignment is static
	private bool assignIsStatic(ASTNode assign){
		// on is var, if the var has indexes, make sure the indexes are also static, and the lvalue must also be static
		// make sure it has only 2 subNodes
		if (assign.subNodes.length != 2){
			compileErrors.append(CompileError(assign.lineno, "assingment statemnt has other than 2 nodes"));
			return false;
		}else{
			ASTNode var = assign.subNodes[0];
			ASTNode lvalue = assign = assign.subNodes[1];
			if (assign.subNodes[1].type == ASTNode.Type.Variable){
				var = assign.subNodes[1];
				lvalue = assign.subNodes[0];
			}
			// now the real work
			bool r = true;
			// check the indexes of the var
			foreach (index; var.subNodes){
				// make sure it is an index
				if (index.type == ASTNode.Type.ArrayIndex){
					if (!isStatic(index)){
						return false;
					}
				}else{
					compileErrors.append(CompileError(index.lineno, "variable can only have ArrayIndex as subNode"));
					return false;
				}
			}
			// now check the lvalue, only if indexes are static
			if (r){
				r = isStatic(lvalue);
			}
			return r;
		}
	}

	/// checks if a var is static, i.e if it's value is known at runtime, and if it's an array, the indexes are static
	private bool variableIsStatic(ASTNode var){
		// check if value is known
		if (vars.valKnown(var.data)){
			// check indexes
			foreach (index; var.subNodes){
				// make sure it is an index
				if (index.type == ASTNode.Type.ArrayIndex){
					if (!isStatic(index)){
						return false;
					}
				}else{
					compileErrors.append(CompileError(index.lineno, "variable can only have ArrayIndex as subNode"));
					return false;
				}
			}
			return true;
		}else{
			return false;
		}
	}

	/// checks if a static array (`[x, y, z]`) is static, i.e if all the elements in it are known at compile time
	private bool staticArrayIsStatic(ASTNode array){
		// just check the subNodes
		ASTNode[] elements = array.subNodes;
		foreach (element; elements){
			if (!isStatic(element)){
				return false;
			}
		}
		return true;
	}
}


/// provides functions to store variables at compile time
private struct VarStore{
	/// Used to store vars
	private QData[string] vars;

	/// adds a var to the list, with undefined type
	/// 
	/// returns true if var was added, false if the var with the same name already exists, or if type is invalid
	bool addVar(string name){
		if (name !in vars){
			vars[name] = QData();
			return true;
		}else{
			return false;
		}
	}

	/// adds a var to the list, with a known type
	/// 
	/// returns true if var was added, false if the var with the same name already exists, or if type is invalid
	bool addVar(T)(string name, T val){
		if (name !in vars){
			// check what type it is
			QData var;
			var.value = val;
			vars[name] = var;
			return true;
		}else{
			return false;
		}
	}

	/// changes value of a var
	/// 
	/// returns true if var was added, false if the var does not exist, or if type is invalid
	bool setVal(T)(string name, T newVal){
		if (name in vars){
			try{
				vars[name].value = newVal;
			}catch (Exception e){
				.destroy(e);
				return false;
			}
			return true;
		}else{
			return false;
		}
	}

	/// returns value of a stored variable
	/// 
	/// throws Exception on failure
	QData getVal(string name){
		if (name in vars){
			return vars[name];
		}else{
			throw new Exception("Variable does not exist");
		}
	}

	/// removes a variable from list
	/// 
	/// returns true if successful, false if var did not exist
	bool removeVar(string name){
		if (name in vars){
			vars.remove(name);
			return false;
		}else{
			return false;
		}
	}

	/// returns true if a value of a var is known
	bool valKnown(string name){
		if (name in vars){
			return true;
		}
		return false;
	}
}