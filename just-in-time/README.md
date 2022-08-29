# Just-in-time

## Explanation of the challenge

This challenge implements a [just-in-time](https://en.wikipedia.org/wiki/Just-in-time_compilation) compiler written in Solidity. The contract `JIT` has a function `invoke` that takes two argument, `_program` and `stdin`, of type `bytes`. The first one is the input code written with custom opcodes that we will describe later, that will be translated to EVM opcodes during the compilation. After the compilation, the function deploys a contract with the bytecode obtained by the compilation, and makes a `delegatecall` to the deployed contract with `_stdin` as input data.

The objective of the challenge is to steal 50 ethers that are given to the contract at the begining.

## Compiler description

### Input opcodes

The custom opcodes of the input program are given as bytes, that are the UTF-8 hexadecimal encoding of the presented characters. They are the following:
> `>` Adds 32 to the last item on the stack.  
> `<` Removes 32 to the last item on the stack.  
> `+` Adds 1 to the item at the memory address that is the last item on the stack.  
> `-` Removes 1 to the item at the memory address that is the last item on the stack.  
> `.` Logs the last byte of the item at the memory address that is the last item on the stack.  
> `,` Loads the n<sup>th</sup> byte of the calldata, stores it at the memory address that is the last item on the stack, and increments n, where n is the second item on the stack.  
> `[` Begins a loop.  
> `]` Ends a loop.  
> `#` Does nothing.  

The loops are running while the item at the memory address that is the last item on the stack is not nul. If this condition is not met at a `[` character, it will directly jump to the matching `]` character. For example, the program `[-]` will decrement the item in the memory until it is nul.

### Pseudo-opcodes

In addition to these opcodes, there are pseudo-opcodes. They do not provide more possibilities, but they optimize by a lot the execution. The available pseudo-codes are the following:
> `R` that is equivalent to the character `>` *x* times where *x* is the number represented by the two following bytes.  
> `L` that is equivalent to the character `<` *x* times where *x* is the number represented by the two following bytes.  
> `A` that is equivalent to the character `+` *x* times where *x* is the number represented by the two following bytes.  
> `S` that is equivalent to the character `-` *x* times where *x* is the number represented by the two following bytes.  
> `0` that resets the item at the memory address that is the last item on the stack to 0. It is equivalent to `[-]`.

For example, `A000c` (encoded `41000c`) is equivalent to `++++++++++++` (encoded `2b2b2b2b2b2b2b2b2b2b2b2b`). These pseudo-opcodes are used during the pre-processing, before the compilation, to optimize duplications of opcodes and `[-]` loops (replaced by `0##`). For example, `>>>>>>>` (encoded `3e3e3e3e3e3e3e`) is replaced by `R0007####` (encoded `52000723232323`). It is not clear if it is intentional, but we can use these pseudo-opcodes in the input program.

## Presentation of some unexpected behaviors of the compiler

The compiler presents some unexpected behaviors (and the author apologizes for this in the comments of the contract). We list here all the ones we found, but not all of them we be used in our solution.

### Pseudo-opcodes don't escape the following characters

The four pseudo-opcodes `R`, `L`, `A` and `S` read during the compilation the two following bytes to determine the number of repetitions. But these two bytes are considered as normal input opcodes during the pre-processing, especially during the loop detection. So, if for example there is in the input programe the opcodes `A005b` (encoded `41005b`) to add 91 to the last elemtn on the stack, it will be interpreted as `A00[` (because `[` is encoded by `5b`) during the pre-processing. So, during the loop detection, it will consider that there is here the begining of a new loop. It can make the transaction revert (it can happen if all the brackets are not matched), or worse, add unexpected loops in the code.

### The optimization pass doesn't replace the correct number of opcodes

To optimize the duplications of characters, the optimization pass replaces them by pseudo-opcodes. To avoid reindexing the opcodes in the list, the difference of opcodes are replaced by `#` (the opcodes that does nothing). For example, `++++++++++++` is replaced by `A000c#########`. But, the number of opcodes to replace is miscomputed. Indeed, in a series of several identical opcodes, the opcodes `#` are ignored (because `+++###+++-` is equivalent `++++++`), but the number of ignored opcodes is not computed. So, `+++###+++-` wil be replaced by `+++A0006###-` instead of `A0006######-`. Note that here the final `-` is necessary because the compiler doesn't replace a repetition of opcodes if it is at the end of the input program (another unexpected behaviour but without any repercussion). Eventually, 9 will be added istead of 6. In the general case, it will execute more time that expective the action.

## Building the solution
