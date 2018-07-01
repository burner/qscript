/++
Functions to check if a script is valid (or certain nodes) by its generated AST
+/
module qscript.compiler.astcheck;

import qscript.compiler.misc;
import qscript.compiler.ast;
import qscript.compiler.compiler : Function;

import utils.misc;
import utils.lists;

/// Contains functions to check ASTs for errors  
/// One instance of this class can be used to check for errors in a script's AST.
class ASTCheck{
private:
	/// stores the pre defined functions' names, arg types, and return types
	Function[] preDefFunctions;
	/// stores the script defined functions' names, arg types, and return types
	Function[] scriptDefFunctions;
	/// stores all the errors that are there in the AST being checked
	LinkedList!CompileError compileErrors;
	
	/// stores data types of variables in currently-being-checked-FunctionNode
	DataType[string] varTypes;
	/// stores the scope-depth of each var in currently-being-checked-FunctionNode which is currently in scope
	uinteger[string] varScope;
	/// stores current scope-depth
	uinteger scopeDepth;
	/// registers a new var in current scope
	/// 
	/// Returns: false if it was already registered, true if it was successful
	bool addVar(string name, DataType type){
		if (name in varTypes){
			return false;
		}
		varTypes[name] = type;
		varScope[name] = scopeDepth;
		return true;
	}
	/// Returns: the data type of a variable
	/// 
	/// Throws: Exception if that variable was not declared, or is not available in current scope
	DataType getVarType(string name){
		if (name in varTypes){
			return varTypes[name];
		}
		throw new Exception("variable "~name~" was not declared, or is out of scope");
	}
	/// Returns: true if a var is available in current scope
	bool varExists(string name){
		if (name in varTypes)
			return true;
		return false;
	}
	/// increases the scope-depth
	/// 
	/// this function should be called before any AST-checking in a sub-BlockNode or anything like that is started
	void increaseScope(){
		scopeDepth ++;
	}
	/// decreases the scope-depth
	/// 
	/// this function should be called right after checking in a sub-BlockNode or anything like that is finished  
	/// it will put the vars declared inside that scope go out of scope
	void decreaseScope(){
		foreach (key; varScope.keys){
			if (varScope[key] == scopeDepth){
				varScope.remove(key);
				// remove from varDataTypes too!
				varTypes.remove(key);
			}
		}
		if (scopeDepth > 0){
			scopeDepth --;
		}
	}
	/// Returns: return type of a function, works for both script-defined and predefined functions
	/// 
	/// Throws: Exception if the function does not exist
	DataType getFunctionType(string name){
		foreach (func; scriptDefFunctions){
			if (func.name == name){
				return func.returnType;
			}
		}
		foreach (func; preDefFunctions){
			if (func.name == name){
				return func.returnType;
			}
		}
		throw new Exception ("function "~name~" does not exist");
	}
	/// Returns: return type of a function, works for both script-defined and predefined functions
	/// 
	/// Throws: Exception if the function does not exist
	DataType getFunctionType(string name, DataType[] argTypes){
		foreach (func; scriptDefFunctions){
			if (func.name == name && func.argTypes == argTypes){
				return func.returnType;
			}
		}
		foreach (func; preDefFunctions){
			if (func.name == name && func.argTypes == argTypes){
				return func.returnType;
			}
		}
		throw new Exception ("function "~name~" does not exist");
	}
	/// Returns: return type for a CodeNode
	/// 
	/// Throws: Exception in each of these cases:  
	/// 1. CodeNode is a function call and function does not exist
	/// 2. CodeNode is a variable and that variable does not exist
	/// 3. CodeNode is a operator and both operands are not of same type
	/// 4. CodeNode is array-read-element (`abc[someIndex]`) but the declared dimensions of array are less than one's present
	DataType getReturnType(CodeNode node){
		if (node.type == CodeNode.Type.FunctionCall){
			DataType[] argTypes;
			FunctionCallNode fCall = node.node!(CodeNode.Type.FunctionCall);
			argTypes.length = fCall.arguments.length;
			foreach (i, arg; fCall.arguments){
				argTypes[i] = getReturnType(arg);
			}
			return getFunctionType(fCall.fName, argTypes);
		}else if (node.type == CodeNode.Type.Literal){
			return node.node!(CodeNode.Type.Literal).returnType;
		}else if (node.type == CodeNode.Type.Operator){
			OperatorNode opNode = node.node!(CodeNode.Type.Operator);
			DataType[2] operandTypes = [getReturnType(opNode.operands[0]), getReturnType(opNode.operands[1])];
			if (operandTypes[0] != operandTypes[1]){
				throw new Exception("both operands of an operator must be of same data type");
			}
			return operandTypes[0];
		}else if (node.type == CodeNode.Type.ReadElement){
			ReadElement arrayRead = node.node!(CodeNode.Type.ReadElement);
			DataType readFromType = getReturnType(arrayRead.readFromNode);
			if (readFromType.arrayDimensionCount == 0){
				if (readFromType.type == DataType.Type.String){
					return DataType(DataType.Type.String);
				}else{
					throw new Exception ("Cannot use [..] on non-array and non-string data");
				}
			}
			readFromType.arrayDimensionCount --;
			return readFromType;
		}else if (node.type == CodeNode.Type.Variable){
			VariableNode varNode = node.node!(CodeNode.Type.Variable);
			return getVarType(varNode.varName);
		}
		return DataType(DataType.Type.Void);
	}
	/// reads all FunctionNode from ScriptNode and writes them into `scriptDefFunctions`
	/// 
	/// any error is appended to compileErrors
	void readFunctions(ScriptNode node){
		/// stores index of functions in scriptDefFunctions
		uinteger[][string] funcIndex;
		scriptDefFunctions.length = node.functions.length;
		foreach (i, func; node.functions){
			// read arg types into a single array
			DataType[] argTypes;
			argTypes.length = func.arguments.length;
			foreach (index, arg; func.arguments)
				argTypes[i] = arg.argType;
			scriptDefFunctions[i] = Function(func.name, func.returnType, argTypes);
			if (func.name in funcIndex)
				funcIndex[func.name] ~= i;
			else
				funcIndex[func.name] = [i];
		}
		// now make sure that all functions with same names have different arg types
		foreach (funcName; funcIndex.keys){
			if (funcIndex[funcName].length > 1){
				// check these indexes
				uinteger[] indexes = funcIndex[funcName];
				/// stores the arg type combinations which have already been used
				DataType[][] usedArgCombinations;
				usedArgCombinations.length = indexes.length;
				foreach (i, index; indexes){
					if (usedArgCombinations[0 .. i].indexOf(scriptDefFunctions[index].argTypes) >= 0){
						compileErrors.append(CompileError(node.functions[index].lineno,
								"functions with same name must have different argument types"
							));
					}
					usedArgCombinations[i] = scriptDefFunctions[index].argTypes;
				}
			}
		}
	}
protected:
	/// checks if a FunctionNode is valid
	void checkAST(FunctionNode node){
		increaseScope();
		// add the arg's to the var scope. make sure one arg name is not used more than once
		foreach (i, arg; node.arguments){
			if (!addVar(arg.argName, arg.argType)){
				compileErrors.append(CompileError(node.lineno, "argument name '"~arg.argName~"' has been used more than once"));
			}
		}
		// now check the statements
		checkAST(node.bodyBlock);
	}
	/// checks if a StatementNode is valid
	void checkAST(StatementNode node){
		if (node.type == StatementNode.Type.Assignment){
			checkAST(node.node!(StatementNode.Type.Assignment));
		}else if (node.type == StatementNode.Type.Block){
			checkAST(node.node!(StatementNode.Type.Block));
		}else if (node.type == StatementNode.Type.DoWhile){
			checkAST(node.node!(StatementNode.Type.DoWhile));
		}else if (node.type == StatementNode.Type.For){
			checkAST(node.node!(StatementNode.Type.For));
		}else if (node.type == StatementNode.Type.FunctionCall){
			checkAST(node.node!(StatementNode.Type.FunctionCall));
		}else if (node.type == StatementNode.Type.If){
			checkAST(node.node!(StatementNode.Type.If));
		}else if (node.type == StatementNode.Type.VarDeclare){
			checkAST(node.node!(StatementNode.Type.VarDeclare));
		}else if (node.type == StatementNode.Type.While){
			checkAST(node.node!(StatementNode.Type.While));
		}
	}
	/// checks a AssignmentNode
	void checkAST(AssignmentNode node){
		// make sure var exists, checkAST(VariableNode) does that
		chectAST(node.var);
		// check if the indexes provided for the var are possible, i.e if the var declaration has >= those indexes
		if (node.var.varType.arrayDimensionCount < node.indexes.length){
			compileError.append(CompileError(node.var.lineno, "array's dimension count in assignment differes from declaration"));
		}else{
			// check if the data type of the value and var (considering the indexes used) match
			DataType expectedType = node.var.varType;
			expectedType.arrayDimensionCount -= node.indexes.length;
			if (node.val.returnType != expectedType){
				compileErrors.append(CompileError(node.val.lineno, "cannot assign value with different data type to variable"));
			}
			// now check the CodeNode's for indexes
			foreach (indexCodeNode; node.indexes){
				checkAST(indexCodeNode);
			}
			// now check the value's CodeNode
			checkAST(node.val);
		}
	}
	/// checks a BlockNode
	void checkAST(BlockNode node, bool ownScope = true){
		if (ownScope)
			increaseScope();
		foreach (statement; node.statements){
			checkAST(statement);
		}
		if (ownScope)
			decreaseScope();
	}
	/// checks a DoWhileNode
	void checkAST(DoWhileNode node){
		increaseScope();
		if (node.statement.type == StatementNode.Type.Block){
			checkAST(node.statement.node!(StatementNode.Type.Block), false);
		}else{
			checkAST(node.statement);
		}
		checkAST(node.condition);
		decreaseScope();
	}
	/// checks a ForNode
	void checkAST(ForNode node){
		increaseScope();
		// first the init statement
		checkAST(node.initStatement);
		// then the condition
		checkAST(node.condition);
		// then the increment one
		checkAST(node.incStatement);
		// finally the loop body
		checkAST(node.statement);
		decreaseScope();
	}
	/// checks a FunctionCallNode
	void checkAST(FunctionCallNode node){
		/// store the arguments types
		DataType[] argTypes;
		argTypes.length = node.arguments.length;
		// while moving the type into separate array, perform the checks on the args themselves
		foreach (i, arg; node.arguments){
			argTypes[i] = arg.returnType;
			checkAST(arg);
		}
		// now make sure that that function exists, and the arg types match
		bool isScriptDef = false;
		bool functionExists = false;
		foreach (func; scriptDefFunctions){
			if (func.name == node.fName && matchArguments(func.argTypes, argTypes)){
				functionExists = true;
			}
		}
		if (!functionExists){
			foreach (func; preDefFunctions){
				if (func.name == node.fName && func.argTypes == argTypes){
					functionExists = true;
				}
			}
		}
		if (!functionExists){
			compileErrors.append(CompileError(node.lineno,
					"function "~node.fName~" does not exist or cannot be called with these arguments"));
		}
	}
	/// checks an IfNode
	void checkAST(IfNode node){
		// first the condition
		checkAST(node.condition);
		// then statements
		increaseScope();
		checkAST(node.statement);
		decreaseScope();
		if (node.hasElse){
			increaseScope();
			checkAST(node.elseStatement);
			decreaseScope();
		}
	}
	/// checks a VarDeclareNode
	void checkAST(VarDeclareNode node){
		foreach (i, varName; node.vars){
			if (varExists(varName)){
				compileErrors.append(CompileError(node.lineno, "variable "~varName~" has already been declared"));
			}else if (node.hasValue(varName)){
				// match values
				CodeNode value = node.getValue(varName);
				checkAST(value);
				// make sure that value can be assigned
				DataType valueType;
				try{
					valueType = getReturnType(value);
					if (valueType != node.type){
						compileErrors.append(CompileError(node.lineno, "cannot assign value of different data type"));
					}
				}catch (Exception e){
					// any error that exception tells was already added by the check that was done before, so destroy it
					.destroy(e);
				}
			}
		}
	}
	/// checks a WhileNode
	void checkAST(WhileNode node){
		// first condition
		checkAST(node.condition);
		// the the statement
		increaseScope();
		checkAST(node.statement);
		decreaseScope();
	}
public:
	this (Function[] predefinedFunctions){
		compileErrors = new LinkedList!CompileError;
		preDefFunctions = predefinedFunctions.dup;
	}
	~this(){
		.destroy(compileErrors);
	}
	/// checks a script's AST for any errors
	/// 
	/// Returns: errors in CompileError[] or just an empty array if there were no errors
	CompileError[] checkAST(ScriptNode node){
		// empty everything
		scriptDefFunctions = [];
		compileErrors.clear;
		varTypes.clear;
		varScope.clear;
		scopeDepth = 0;
		readFunctions(node);
		// call checkAST on every FunctionNode
		foreach (functionNode; node.functions){
			checkAST(functionNode);
		}
		CompileError[] r = compileErrors.toArray;
		.destroy(compileErrors);
		return r;
	}
}
