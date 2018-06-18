# QScript
A fast, static typed, scripting language, with a syntax similar to D Language.
## Setting it up
To add QScript to your dub package or project, add the following into dub.json dependencies:
```
"qscript": "~>0.6.1"
```
or if you have dub.sdl:
```
dependency "qscript" version="~>0.6.1"
```
After adding that, look at the `source/demo.d` to see how to use the `QScript` class to execute scripts.

---

## Getting Started:
To get started on using QScript, see the following documents:

* `spec/syntax.md`		- Contains the specification for QScript's syntax.
* `spec/functions.md`	- Contains a list of predefined QScript functions.
* `demos/demo.d`		- A demo usage of QScript in D langauage. Shows how to add new functions

And for the documentation on the code, including QScript's compiler, it is stored in `docs/`.  
The spec for QScript's byte code is also available, in `spec/bytecode.md`, but knowing it is not necessary for using QScript.

### Building Demo:
To be able to run basic scripts, you can build the demo using:  
`dub build --config=demo --build=release`  
This will create an executable named `demo` in the directory. To run a script through it, do:  
`./demo path/to/script`  
You can also use the demo build to see the generated byte code for your scripts using:  
`./demo "path/to/script" "output/bytecode/file/path"`

## Features:
1. Syntax similar to D
2. Dynamic arrays
3. Very fast execution speed. QScript has a virtual machine for this purpose, no interpretation is done at run time.
4. Static typed. This eliminates a lot of errors.

## TODO For Upcoming Versions
1. Implement `do-while` and `for` loops. - Already done, will be present in next release
2. Change syntax of variable declarations to the way it's done in D-lang.
3. Add Structs and classes.

---

## Example Scripts:
These scripts can be run through the demo configuration.
### Hello World:
```
function void main(){
	writeln ("Hello World!");
}
```
### Arrays:
```
function void main{
	int[] (array);
	array = array(1, 2, 3, 4);
	int (i, length);
	i = 0;
	length = getLength(array);
	while (i < length){
		writeln (intToStr(array[i]));
		i = i + 1;
	}
}
```
