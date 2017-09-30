﻿module qscript.compiler.astgen;

import qscript.compiler.misc;
import qscript.compiler.tokengen;
import qscript.compiler.ast;

import utils.misc;
import utils.lists;

/// contains functions and stuff to convert a QScript from tokens to Syntax Trees
struct ASTGen{
	/// generates an AST representing a script.
	/// 
	/// The script must be converted to tokens using `qscript.compiler.tokengen.toTokens`
	/// If any errors occur, they will be contanied in `qscript.compiler.misc.`
	static public ScriptNode generateScriptAST(TokenList tokens){
		ScriptNode scriptNode;
		LinkedList!FunctionNode functions = new LinkedList!FunctionNode;
		// go through the script, compile function nodes, link them to this node
		for (uinteger i = 0, lastIndex = tokens.tokens.length - 1; i < tokens.tokens.length; i ++){
			// look for TokenType.Keyword where token.token == "function"
			if (tokens.tokens[i].type == Token.Type.Keyword && tokens.tokens[i].token == "function"){
				uinteger errorCount = compileErrors.count;
				FunctionNode functionNode = generateFunctionAST(tokens, i);
				i --;
				// check if error free
				if (compileErrors.count == errorCount){
					functions.append(functionNode);
				}
			}
		}
		scriptNode = ScriptNode(functions.toArray);
		.destroy(functions);
		return scriptNode;
	}
	static private{
		/// reads a type from TokensList
		/// 
		/// returns type in DataType struct, changes `index` to token after last token of type
		DataType readType(TokenList tokens, ref uinteger index){
			uinteger startIndex = index;
			for (; index < tokens.tokens.length; index ++){
				if (tokens.tokens[index].type != Token.Type.IndexBracketOpen &&
					tokens.tokens[index].type != Token.Type.IndexBracketClose){
					break;
				}
			}
			string sType = tokens.toString(tokens.tokens[startIndex .. index]);
			return DataType(sType);
		}
		/// generates AST for a function definition 
		/// 
		/// changes `index` to the token after function definition
		FunctionNode generateFunctionAST(TokenList tokens, ref uinteger index){
			FunctionNode functionNode;
			BlockNode fBody;
			DataType returnType;
			LinkedList!(FunctionNode.Argument) args = new LinkedList!(FunctionNode.Argument);
			string fName;
			// make sure it's a function
			if (tokens.tokens[index].type == Token.Type.Keyword && tokens.tokens[index].token == "function"){
				// read the type
				index++;
				returnType = readType(tokens, index);
				// above functionCall moves index to fName
				// now index is at function name
				fName = tokens.tokens[index].token;
				index ++;
				// now for the argument types, and the functionBody
				if (tokens.tokens[index].type == Token.Type.BlockStart){
					// no args, just body
					fBody = generateBlockAST(tokens, index);
				}else{
					/// TODO add code to read arguments + types
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a function definition"));
			}
			return functionNode;
		}
		
		/// generates AST for a {block-of-code}
		/// 
		/// changes `index` to token after block end
		BlockNode generateBlockAST(TokenList tokens, ref uinteger index){
			BlockNode blockNode;
			// make sure it's a block
			if (tokens.tokens[index].type == Token.Type.BlockStart){
				uinteger brackEnd = tokens.tokens.bracketPos!(true)(index);
				blockNode = BlockNode(generateStatementsAST(tokens, index+1, brackEnd-1));
				index = brackEnd+1;
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a block"));
			}
			return blockNode;
		}
		
		/// generates ASTs for statements in a block
		StatementNode[] generateStatementsAST(TokenList tokens, uinteger index, uinteger endIndex){
			enum StatementType{
				FunctionCall,
				IfWhile,
				Assignment,
				VarDeclare,
				NoValidType
			}
			StatementType getStatementType(TokenList tokens, uinteger index, uinteger endIndex){
				// check if its a function call, or if/while
				if (tokens.tokens[index].type == Token.Type.Keyword){
					if (tokens.tokens[index].token == "if" || tokens.tokens[index].token == "while"){
						return StatementType.IfWhile;
					}
				}else if (tokens.tokens[index].type == Token.Type.DataType){
					return StatementType.VarDeclare;
				}else if (index+3 <= endIndex && tokens.tokens[index].type == Token.Type.Identifier && 
					tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
					// is a function call
					return StatementType.FunctionCall;
				}else{
					// check if first token is var
					if (tokens.tokens[index].type == Token.Type.Identifier){
						// index brackets are expected
						uinteger i;
						for (i = index+1; i < endIndex; i ++){
							if (tokens.tokens[i].type == Token.Type.IndexBracketOpen){
								i = tokens.tokens.bracketPos(i);
							}else{
								break;
							}
						}
						// if it reached here, it means previous checks passed, now to see if there's an `=` token or not
						if (tokens.tokens[i].type == Token.Type.Operator && tokens.tokens[i].token == "="){
							return StatementType.Assignment;
						}
					}
				}
				return StatementType.NoValidType;
			}
			

			LinkedList!StatementNode nodeList = new LinkedList!StatementNode;
			// separate statements
			for (uinteger i = index, readFrom = index; i <= endIndex; i ++){
				// check if is a block for if/while, then skip
				if (tokens.tokens[i].type == Token.Type.Keyword){
					if (tokens.tokens[i].token == "if" || tokens.tokens[i].token == "while"){
						// make sure its followed by a paranthese, then by a brace, and then skip that brace
						if (tokens.tokens[i+1].type == Token.Type.ParanthesesOpen){
							i = tokens.tokens.bracketPos(i+1)+1;
							// then skip the brace
							if (tokens.tokens[i].type == Token.Type.BlockStart){
								i = tokens.tokens.bracketPos(i);
							}else{
								compileErrors.append(CompileError(tokens.getTokenLine(i),
										"if/while statement not followed by a block"));
							}
						}else{
							compileErrors.append(CompileError(tokens.getTokenLine(i),
									"if/while statement not complete"));
						}
					}
				}
				if (tokens.tokens[i].type == Token.Type.StatementEnd && readFrom < i){
					StatementType type = getStatementType(tokens, readFrom, i);
					if (type == StatementType.NoValidType){
						compileErrors.append(CompileError(tokens.getTokenLine(readFrom), "invalid statement"));
						break;
					}else if (type == StatementType.Assignment){
						nodeList.append(
							StatementNode(generateAssignmentAST(tokens, readFrom, i-1))
							);
					}else if (type == StatementType.FunctionCall){
						nodeList.append(
							StatementNode(generateFunctionCallAST(tokens, readFrom, i-1))
								);
					}else if (type == StatementType.VarDeclare){
						nodeList.append(
							StatementNode(generateVarDeclareAST(tokens, readFrom, i-1))
							);
					}else if (type == StatementType.IfWhile){
						nodeList.append(
							StatementNode(generateIfWhileAST(tokens, readFrom, i))
							);
					}
					readFrom = i+1;
				}else if (tokens.tokens[i].type == Token.Type.BlockStart && readFrom < i){
					// add it
					nodeList.append(StatementNode(generateBlockAST(tokens, i)));
					// skip the block's body
					i = tokens.tokens.bracketPos(i);
					readFrom = i+1;
				}
			}
			StatementNode[] statementNodes = nodeList.toArray;
			.destroy(nodeList);
			return statementNodes;
		}
		
		FunctionCallNode generateFunctionCallAST(TokenList tokens, uinteger index, uinteger endIndex){
			FunctionCallNode functionCallNode;
			// check if is function call
			if (tokens.tokens[index].type == Token.Type.Identifier && tokens.tokens[index + 1].type == Token.Type.ParanthesesOpen){
				// check if there's a bracket
				uinteger brackEnd = tokens.tokens.bracketPos(index + 1);
				if (brackEnd <= endIndex){
					// now for the arguments
					LinkedList!CodeNode args = new LinkedList!CodeNode;
					for (uinteger i = index+2, readFrom = index+2; i <= endIndex; i ++){
						Token token = tokens.tokens[i];
						if ([Token.Type.ParanthesesOpen, Token.Type.IndexBracketOpen, Token.Type.BlockStart].
							hasElement(token.type)){
							//skip to end of that bracket
							i = tokens.tokens.bracketPos(i);
						}
						if (readFrom < i && (token.type == Token.Type.Comma || token.type == Token.Type.ParanthesesClose)){
							args.append(generateCodeAST(tokens, readFrom, i-1));
							readFrom = i+1;
						}
					}
					functionCallNode = FunctionCallNode(tokens.tokens[index].token, args.toArray);
					.destroy(args);
					
					return functionCallNode;
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index), "not a valid function call"));
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a valid function call"));
			}
			return functionCallNode;
		}
		
		/// generates AST for "actual code" like `2 + 2 - 6`.
		CodeNode generateCodeAST(TokenList tokens, uinteger index, uinteger endIndex){
			CodeNode lastNode;
			bool separatorExpected = false;
			for (uinteger i = index; i <= endIndex; i ++){
				Token token = tokens.tokens[i];
				if (!separatorExpected){
					// an identifier, or literal (i.e some data) was expected
					lastNode = CodeNode(generateNodeAST(tokens, i));
					i --;
					separatorExpected = true;
				}else{
					// an operator or something that deals with data was expected
					if (token.type == Token.Type.Operator){
						lastNode = CodeNode(generateOperatorAST(tokens, lastNode, i));
						i --;
					}else{
						compileErrors.append(CompileError(tokens.getTokenLine(i), "unexpected token"));
					}
				}
			}
			return lastNode;
		}
		
		/// generates AST for operators like +, -...
		/// 
		/// `firstOperand` is the first operand for the operator.
		/// `index` is the index of the token which is the operator
		/// 
		/// changes `index` to the index of the token after the last token related to the operator
		OperatorNode generateOperatorAST(TokenList tokens, CodeNode firstOperand, ref uinteger index){
			OperatorNode operator;
			// make sure it's an operator, and there is a second operand
			if (tokens.tokens[index].type == Token.Type.Operator && index+1 < tokens.tokens.length){
				// read the next operand
				CodeNode secondOperand;
				if (BOOL_OPERATORS.hasElement(tokens.tokens[index].token)){
					// look where the operand is ending
					uinteger i;
					for (i = index + 1; i < tokens.tokens.length; i ++){
						Token token = tokens.tokens[i];
						if ([Token.Type.ParanthesesOpen, Token.Type.IndexBracketOpen, Token.Type.BlockStart].
							hasElement(token.type)){
							//skip to end of that bracket
							i = tokens.tokens.bracketPos(i);
						}
						if ([Token.Type.Comma, Token.Type.ParanthesesClose, Token.Type.StatementEnd].hasElement(token.type)){
							break;
						}
					}
					secondOperand = generateCodeAST(tokens, index + 1, i-1);
					index = i;
				}else{
					uinteger i = index + 1;
					secondOperand = CodeNode(generateNodeAST(tokens, i));
					index = i;
				}
				// put both operands under one node
				operator = OperatorNode(tokens.tokens[index].token, firstOperand, secondOperand);
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "no second operand found"));
			}
			return operator;
		}
		
		/// generates AST for a variable (or array) and changes value of index to the token after variable ends
		VariableNode generateVariableAST(TokenList tokens, ref uinteger index){
			VariableNode var;
			// make sure first token is identifier
			if (tokens.tokens[index].type == Token.Type.Identifier){
				// set var name
				var.varName = tokens.tokens[index].token;
				index ++;
				// check if indexes are specified, case yes, add em
				if (tokens.tokens[index].type == Token.Type.IndexBracketOpen){
					LinkedList!CodeNode indexes = new LinkedList!CodeNode;
					for (index = index; index < tokens.tokens.length; index ++){
						if (tokens.tokens[index].type == Token.Type.IndexBracketOpen){
							// add it
							uinteger brackEnd = tokens.tokens.bracketPos!true(index);
							indexes.append(generateCodeAST(tokens, index+1, brackEnd - 1));
						}else{
							break;
						}
					}
					var.indexes = indexes.toArray;
					.destroy(indexes);
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a variable"));
			}
			return var;
		}
		
		/// generates AST for assignment operator
		AssignmentNode generateAssignmentAST(TokenList tokens, uinteger index, uinteger endIndex){
			AssignmentNode assignment;
			// get the variable to assign to
			VariableNode var = generateVariableAST(tokens, index);
			// now at index, the token should be a `=` operator
			if (tokens.tokens[index].type == Token.Type.Operator && tokens.tokens[index].token == "="){
				// everything's ok till the `=` operator
				CodeNode val = generateCodeAST(tokens, index+1, endIndex);
				assignment = AssignmentNode(var, val);
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not an assignment statement"));
			}
			return assignment;
		}
		
		/// generates AST for variable declarations
		VarDeclareNode generateVarDeclareAST(TokenList tokens, uinteger index, uinteger endIndex){
			VarDeclareNode varDeclare;
			// make sure it's a var declaration, and the vars are enclosed in parantheses
			if (tokens.tokens[index].type == Token.Type.Keyword && DATA_TYPES.hasElement(tokens.tokens[index].token) &&
				index+1 < endIndex){
				// read the type
				uinteger i = index;
				DataType type = readType(tokens, i);
				// check if brackEnd == endIndex
				if (tokens.tokens.bracketPos(i) == endIndex){
					// now go through all vars, check if they are vars, and are aeparated by comma
					bool commaExpected = false;
					LinkedList!string vars = new LinkedList!string;
					for (i = i+1; i < endIndex; i ++){
						Token token = tokens.tokens[i];
						if (commaExpected){
							if (token.type != Token.Type.Comma){
								compileErrors.append(CompileError(tokens.getTokenLine(i),
										"variable names in declaration must be separated by a comma"));
							}
							commaExpected = false;
						}else{
							if (token.type != Token.Type.Identifier){
								compileErrors.append(CompileError(tokens.getTokenLine(i),
										"variable name expected in varaible declaration, unexpected token found"));
							}else{
								vars.append(token.token);
							}
							commaExpected = true;
						}
					}
					varDeclare = VarDeclareNode(type, vars.toArray);
					.destroy(vars);
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(index), "invalid variable declaration"));
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "invalid variable declaration"));
			}
			return varDeclare;
		}
		
		/// generates AST for if/while statements
		ASTNode generateIfWhileAST(TokenList tokens, uinteger index, uinteger endIndex){
			ASTNode ifWhile;
			if (tokens.tokens[index].token == "while"){
				ifWhile = ASTNode(ASTNode.Type.WhileStatement, tokens.getTokenLine(index));
			}else if (tokens.tokens[index].token == "if"){
				ifWhile = ASTNode(ASTNode.Type.IfStatement, tokens.getTokenLine(index));
			}
			// check if is an if/while
			if (index+3 < endIndex && tokens.tokens[index].type == Token.Type.Keyword &&
				tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
				// now do the real work
				uinteger brackEnd = tokens.tokens.bracketPos(index+1);
				ASTNode condition = generateCodeAST(tokens, index+2, brackEnd-1);
				ifWhile.addSubNode(condition);
				// make sure there's a block at the end of the condition
				if (brackEnd+1 < endIndex && tokens.tokens[brackEnd+1].type == Token.Type.BlockStart){
					ASTNode block = generateBlockAST(tokens, brackEnd+1);
					ifWhile.addSubNode(block);
				}else{
					compileErrors.append(CompileError(tokens.getTokenLine(brackEnd+1), "if/while statement not followed by a block"));
				}
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "not a valid if/while statement"));
			}
			return ifWhile;
		}
		
		/// generates AST for static arrays: like: `[x, y, z]`
		ASTNode generateStaticArrayAST(TokenList tokens, uinteger index, uinteger endIndex){
			ASTNode array;
			// check if is a static array
			if (tokens.tokens[index].type == Token.Type.IndexBracketOpen &&
				tokens.tokens.bracketPos(index) == endIndex){
				// init the node
				array = ASTNode(ASTNode.Type.StaticArray, tokens.getTokenLine(index));
				// add each element using `generateNodeAST`
				bool commaExpected = false;
				for (uinteger i = index+1; i < endIndex; i ++){
					if (commaExpected){
						if (tokens.tokens[i].type != Token.Type.Comma){
							compileErrors.append(CompileError(tokens.getTokenLine(i),
									"elements in static arrays must be separated by a comma"));
						}
						commaExpected = false;
					}else{
						ASTNode element = generateNodeAST(tokens, i);
						i --;
						commaExpected = true;
						array.addSubNode(element);
					}
				}
			}
			return array;
		}
		
		/// returns a node representing either of the following:
		/// 
		/// 1. String literal
		/// 2. Number literal
		/// 3. Function Call (uses `generateFunctionCallAST`)
		/// 4. Variable (uses `generateVariableAST`)
		/// 5. Some code inside parantheses (uses `generateCodeAST`)
		/// 6. A static array (`[x, y, z]`)
		/// 
		/// This function is used by `generateCodeAST` to separate nodes, and by `generateOperatorAST` to read operands
		ASTNode generateNodeAST(TokenList tokens, ref uinteger index){
			Token token = tokens.tokens[index];
			ASTNode node;
			// an identifier, or literal (i.e some data) was expected
			if (token.type == Token.Type.Identifier){
				if (index+1 < tokens.tokens.length && tokens.tokens[index+1].type == Token.Type.ParanthesesOpen){
					uinteger brackEnd = tokens.tokens.bracketPos(index+1);
					node = generateFunctionCallAST(tokens, index, brackEnd);
					index = brackEnd+1;
				}else{
					// just a var
					node = generateVariableAST(tokens, index);
				}
				
			}else if (token.type == Token.Type.ParanthesesOpen){
				uinteger brackEnd = tokens.tokens.bracketPos(index);
				node = generateCodeAST(tokens, index+1, brackEnd-1);
				index = brackEnd+1;
				
			}else if (token.type == Token.Type.IndexBracketOpen){
				uinteger brackEnd = tokens.tokens.bracketPos(index);
				node = generateStaticArrayAST(tokens, index, brackEnd);
				index = brackEnd+1;
				
			}else if (token.type == Token.Type.Number){
				node = ASTNode(ASTNode.Type.NumberLiteral, token.token, tokens.getTokenLine(index));
				index ++;
			}else if (token.type == Token.Type.String){
				node = ASTNode(ASTNode.Type.StringLiteral, token.token, tokens.getTokenLine(index));
				index ++;
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(index), "unexpected token"));
			}
			return node;
		}
		
		
	}
}