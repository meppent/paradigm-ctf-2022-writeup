# Just-in-time

## Explanation of the challenge

This challenge implements a [just-in-time](https://en.wikipedia.org/wiki/Just-in-time_compilation) compiler written in Solidity. The contract `JIT` has a function `invoke` that takes two argument, `_program` and `stdin`, of type `bytes`. The first one is the input proigram written with custom opcodes that we will described later, that will be translated to EVM opcodes during the compilation. After the compilation, the function deploys a contract with the bytecode obtained by the compilation, and makes a `delegatecall` to the deployed contract with `_stdin` as input data.

The objective of the challenge is to steal the 50 ethers that are given to the contract `JIT` at the begining.

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

The loops are running while the item at the memory address that is the last item on the stack is not null. If this condition is not met at a `[` character, it will directly jump to the matching `]` character. For example, the program `[-]` will decrement the item in the memory until it is null.

### Pseudo-opcodes

In addition to these opcodes, there are pseudo-opcodes. They do not provide more possibilities, but they optimize by a lot the execution. The available pseudo-codes are the following:
> `R` that is equivalent to the character `>` *x* times where *x* is the number represented by the two following bytes.  
> `L` that is equivalent to the character `<` *x* times where *x* is the number represented by the two following bytes.  
> `A` that is equivalent to the character `+` *x* times where *x* is the number represented by the two following bytes.  
> `S` that is equivalent to the character `-` *x* times where *x* is the number represented by the two following bytes.  
> `0` that resets the item at the memory address that is the last item on the stack to 0. It is equivalent to `[-]`.

For example, `A000c` (encoded `41000c`) is equivalent to `++++++++++++` (encoded `2b2b2b2b2b2b2b2b2b2b2b2b`). These pseudo-opcodes are used during the pre-processing, before the compilation, to optimize duplications of opcodes and `[-]` loops (replaced by `0##`). For example, `>>>>>>>` (encoded `3e3e3e3e3e3e3e`) is replaced by `R0007####` (encoded `52000723232323`). It is not clear if it is intentional, but we can use these pseudo-opcodes in the input program.

### Invalid opcodes

If an invalid opcode is given in the input program (not in the opcodes and pseudo-opcodes listed above), it will be added as it in the output EVM bytecode, but it will be preceded by the opcodes `dead` and succeded by the opcodes `beef`, that are only invalid EVM opcodes.

## Presentation of some unexpected behaviors of the compiler

The compiler presents some unexpected behaviors (and the author apologizes for this in the comments of the contract). We list here all the ones we found, but not all of them will be used in our solution.

### 1. Pseudo-opcodes don't escape the following characters

The four pseudo-opcodes `R`, `L`, `A` and `S` read during the compilation the two following bytes to determine the number of repetitions. But these two bytes are considered as normal input opcodes during the pre-processing, especially during the loop detection. So, if for example there is in the input programe the opcodes `A005b` (encoded `41005b`) to add 91 to the last elemtn on the stack, it will be interpreted as `A00[` (because `[` is encoded by `5b`) during the pre-processing. So, during the loop detection, it will consider that there is here the begining of a new loop. It can make the transaction revert (it can happen if all the square brackets are not matched), or worse, add unexpected loops in the code.

### 2. The optimization pass doesn't replace the correct number of opcodes

To optimize the duplications of characters, the optimization pass replaces them by pseudo-opcodes. To avoid reindexing the opcodes in the list, the difference of opcodes are replaced by `#` (the opcodes that does nothing). For example, `++++++++++++` is replaced by `A000c#########`. But, the number of opcodes to replace is miscomputed. Indeed, in a series of several identical opcodes, the opcodes `#` are ignored (because `+++###+++-` is equivalent `++++++`), but the number of ignored opcodes is not computed. So, `+++###+++-` wil be replaced by `+++A0006###-` instead of `A0006######-`. Note that here the final `-` is necessary because the compiler doesn't replace a repetition of opcodes if it is at the end of the input program (another unexpected behaviour but without any repercussion). Eventually, 9 will be added istead of 6. In the general case, it will execute more time that expective the action.

### 3. Invalid opcodes can badly influence the output code

In theory, the invalid input opcodes are not accessible by any means because they are surrounded by invalid EVM opcodes. Indeed, if the program counter should naturally arrive to the invalud input opcode, the transaction will revert because it is preceeded by invalid EVM opcodes. We also can't jump on them because it needs a `JUMPDEST` opcode, that is `5b`, the encoding of `[`, a valid input opcode. But, if we put a `PUSHN` opcode with $N > 2$, it will escape opcodes that are further. Indeed, the N bytes following a `PUSHN` are escaped, in the sense that they can't be executed as actual opcodes. So, any `PUSHN` with $N > 2$ in the input program can lead to unexpected behaviours.

### 4. There is no check that all the opened square brackets are closed

An input program with opened square brackets that are not closed is accepted and will go through the pre-processing without any problem. It can revert during the compilation, but not necessarly. Indeed, if an unmatched square bracket is opened at the index `i` in the input program, `loop[i]` won't be affected, so it will have a null value. Thus, a `BasicBlock` will be created with the field `dst2` set to 1 (that is`loop[i] + 1`). If there is no block that begins at the index 1, the compilation will revert at the line 293:

```solidity
uint dst = basicBlockAddrs[labels[i].dstBlock];
if (dst == 0) revert("invalid code");
```

But if there is a block that begins at the index 1, `basicBlockAddrs[1]` won't be null, and the loop begining at the unmatched `[` will jump to the same opcode as the first block if the condition to enter the loop is not met.

### 5. Not all the storage variables are cleaned after an execution

Almost all the storage variables are cleaned when they are no more used, in order to reset them for the next execution. But two variables are not reset: the mappings `loops` and `basicBlockAddrs` (because they are mapping, so it is impossible to reset them, the keyword `delete` doesn't work on mappings). So, these two mappings will keep their values of the end of the execution in a later execution. Since these two mappings are involved in [the previous unexpected behaviour](#4-there-is-no-check-that-all-the-opened-square-brackets-are-closed), we can combine them to create jumps to the destination of our choice.

## Building the solution

Since the contract makes a `delegatecall` to the deployed contract, the objective is just to make the function `invoke` deploy a contract that sends its money to someone. But here's a problem: there is no input opcode that permits to make a `call`, the common way to send money to someone. Even worse, we don't interact freely with the stack, that has almost all the time a depth of 2. The opcode `CALL` needs 7 elements on the stack, so it seems impossible to make a `call`. But there is another opcode that transfers money: the opcode `SELFDESTRUCT` (`ff`). The advantages of this opcode are that it requires only one element on the stack, and that it transfers all the money the contract has, there is no need to precise the amount. So, our objective will be to make the compiler put the byte `ff` in the EVM bytecode, and to make this opcode accessible in a execution.

But `ff` is not a valid input opcode, and there are only two ways to make the compiler write this opcode in the output EVM bytecode:
- Put it as it, it will be treated as an invalid opcode so surrounded by invalid opcodes, but it will be inaccessible.
- If the opcode is put in the two following bytes of a pseudo-opcode `R`, `L`, `A` or `S`. Indeed, these pseudo-opcodes generate a `PUSH4` opcode followed with the two bytes we put after the pseudo-opcode.

Since the first option seems to make the `ff` opcode inaccessible, we will explore the second option. For example, if in the input program there is `Aff00` (encoded `41ff00`), the compiler will add somewhere in the output EVM bytecode `63ff00` (`PUSH4 0xff00`). But here, the opcode `ff` is inside the scope of a `PUSH4`, so there is no way that it can be executed. We need to make this opcode executable. To do so, we can escape the `63` opcode (`PUSH4`) with another `PUSH` opcode placed before. We saw [before](#3-invalid-opcodes-can-badly-influence-the-output-code) how to do that: we can put a `PUSHN` opcode, with $N$ enough large, in the input program such that, even if it is surrouded by invalid opcodes, it can escape the `PUSH4` opcode before `ff00`. To determine the value of $N$, we need to know the exact bytecode created by the input program `Aff00`. We see in the code:

```solidity
} else if (op == "A") {
    code.push(OP_DUP1);
    code.push(OP_MLOAD);
    code.push(OP_PUSH2); code.push(uint8(program[j+1])); code.push(uint8(program[j+2]));
    code.push(OP_ADD);
    code.push(OP_DUP2);
    code.push(OP_MSTORE);
    j += 2;
```

So the output EVM bytecode created by the input `Aff00` is `805161ff00018152` (`JUMPDEST DUP1 MLOAD PUSH2 ff00 ADD DUP2 MSTORE`). So, we need a push that escapes the 3 opcodes before `ff` (`805161`), and the 2 invalid EVM opcodes that follow the invalid input opcode (`beef`). Thus, we need a `PUSH5` (`64`).

Now, if in the input program contains `64Aff00` (encoded `6441ff00`), it will create in the output EVM bytecode `dead64beef805161ff00018152` (`INVALID INVALID PUSH5 0xbeef805161 SELFDESTRUCT RETURN ADD DUP2 MSTORE`).

Knowing that we can make the compiler add jumps with the destination of our choice, as [explained above](#5-not-all-the-storage-variables-are-cleaned-after-an-execution), we now have to make a jump to the opcode `SELFDESTRUCT`. But we can jump only to a `JUMPDEST`. That is not a problem, because after the pseudo-opcode `A`, we can put the two bytes of our choice (we previously put `ff00`, but the `00` is arbitrary). So, we can replace `ff00` by `5bff` (`JUMPDEST SELFDESTRUCT`). Our input program will contain `64A5bff` (encoded `64415bff`). Il will produce the EVM bytecode `dead64beef8051615bff018152` (`INVALID INVALID PUSH5 0xbeef805161 JUMPDEST SELFDESTRUCT ADD DUP2 MSTORE`). We now have to create a false jump that will jump on the opcode `JUMPDEST`.

