# Sourcecode

This challenge wants us to implement a [quine](https://en.wikipedia.org/wiki/Quine_(computing)) in Solidity. A quine is a code that, when executed without parameter, returns itself. But the set of opcodes you can use is largely restricted. All the opcodes that are relative to the blockchain are unusable, so obviously we can't use the opcode `CODECOPY`, make any kind of `call`, or use the contract storage. Essentially, all we can do is manipulation of the stack and the memory. 

The major problem is that we will have to "create" the data we will return, and the only way to "create" data with our restricted set of opcodes is with a `PUSH` opcode. So, we would like to do something like `PUSH32 [our-bytecode] PUSH1 0x00 MSTORE PUSH1 0x20 PUSH1 0x00 RETURN` (if our bytecode has a size of 32 bytes). But this will increase our bytecode size because here `our-bytecode` is copied in the bytecode after the `PUSH32`. Then we cannot create the code with only `PUSH` opcodes.

However, in our restricted set of opcodes, we have all the `DUP` opcodes. They don't exactly "create" data, but they "duplicate" data. `DUP` is very convenient, because with only 1 byte in the bytecode (`80` for `DUP1`), we can duplicate 32 bytes of data (the size of an item on the stack). Thus, if we introduce repetitions in our bytecode, we can do the trick with only one `PUSH` and some `DUP` opcodes.

So, the bytecode or our contract will have a block of opcodes, that will be repeated. We need to determine how many time it will be repeated. Because we need to `PUSH` this block at least one time, and because what is after a `PUSH` is written in the bytecode of the contract, the content of the `PUSH` will be one block. But we need some opcodes before, in order to execute the `PUSH` at least, and some opcodes after, to execute the `DUP`s , and the `RETURN`. Thus, our block will be repeated 3 times. We now have to determine the content of the block.

```
[block 1]: push the next bytes
[block 2]: one-third of the bytecode pushed
[block 3]: duplicate and return the data
```

We need to find a block of opcodes that will do what is written above in function if it is the first, the second or the third block. To simplify things, let's say that our final bytecode will have a size of 96 bytes, so we can `PUSH` one-third of the bytecode with a `PUSH32`. Because the first block needs to push the next 32 bytes, our block needs to finish by a `PUSH32`. Also, because our block mustn't do the same thing if it is in first or third position, we need to add a condition: there will be a `JUMPI` in our block. The structure will then be the following:

```
if not if first block:
    write in memory 3 times what is on the stack
    return the 96 first bytes of the memory
else:
    push the next 32 bytes
```

So that is will be executed like that:
```
[block 1
    [condition handling]
    jump some opcodes after
    [...]
    JUMPDEST
    PUSH32
]
[block 2
    pushed data
]
[block 3
    [condition handling]
    do not jump
    write in memory 3 times what is on the stack
    return the 96 first bytes of the memory
    [...]
]
```

To know if we are in the first block or in the third one, we can use the opcode `PC`, that gives the program counter (it is the current line executed in the program). This opcode is in the restricted set of opcodes (if it wasn't,  we could have written in memory if already executed this part of the code or not, and it would have worked fine). With all these information, we can start writing our block in assembly:

```
PUSH1 0x02 // line of the opcode `PC` if we are in the first block
PC
EQ
PUSH1 [line of the penultimate opcode of the block]
JUMPI
DUP1 // if we arrive here, then we are in the third block
DUP1 // we duplicate 2 time what is on the stack
PUSH1 0x00  // --   
MSTORE      // 
PUSH1 0x20  // we store the bytecode in memory 
MSTORE      // between 0x00 and 0x60 in order to return it
PUSH1 0x40  // 
MSTORE      // --
PUSH1 0x60 // size of the bytecode
PUSH1 0x00 // offset of the bytecode in memory
RETURN
[...] // fill with as much opcodes as needed to fit a block of size 32 bytes (any opcode works, they will never be executed)
JUMPDEST // if we are here, then we are in the first block
PUSH32 // we will push the next 32 bytes, that are the block itself
```
 To make this code of size 32 bytes, we filled if with `dead0dead0dead`, and that gives us the following bytecode:

 ```
 60025814601e57808060005260205260405260606000f3dead0dead0dead5b7f
 ```

 That represents the following assembly code:

 ```
0000 60 PUSH1 0x02
0002 58 PC
0003 14 EQ
0004 60 PUSH1 0x1e
0006 57 JUMPI
0007 80 DUP1
0008 80 DUP1
0009 60 PUSH1 0x00
000b 52 MSTORE
000c 60 PUSH1 0x20
000e 52 MSTORE
000f 60 PUSH1 0x40
0011 52 MSTORE
0012 60 PUSH1 0x60
0014 60 PUSH1 0x00
0016 f3 RETURN
0017 de INVALID
0018 ad INVALID
0019 0d INVALID
001a ea INVALID
001b d0 INVALID
001c de INVALID
001d ad INVALID
001e 5b JUMPDEST
001f 7f PUSH32 0x00
 ```

 The bytecode of our contract will be 3 times the previous bytecode:

 ```
 60025814601e57808060005260205260405260606000f3dead0dead0dead5b7f60025814601e57808060005260205260405260606000f3dead0dead0dead5b7f60025814601e57808060005260205260405260606000f3dead0dead0dead5b7f
 ```

 It represents the following assembly code:

 ```
 0000 60 PUSH1 0x02
0002 58 PC
0003 14 EQ
0004 60 PUSH1 0x1e
0006 57 JUMPI
0007 80 DUP1
0008 80 DUP1
0009 60 PUSH1 0x00
000b 52 MSTORE
000c 60 PUSH1 0x20
000e 52 MSTORE
000f 60 PUSH1 0x40
0011 52 MSTORE
0012 60 PUSH1 0x60
0014 60 PUSH1 0x00
0016 f3 RETURN
0017 de INVALID
0018 ad INVALID
0019 0d INVALID
001a ea INVALID
001b d0 INVALID
001c de INVALID
001d ad INVALID
001e 5b JUMPDEST
001f 7f PUSH32 0x60025814601e57808060005260205260405260606000f3dead0dead0dead5b7f
0040 60 PUSH1 0x02
0042 58 PC
0043 14 EQ
0044 60 PUSH1 0x1e
0046 57 JUMPI
0047 80 DUP1
0048 80 DUP1
0049 60 PUSH1 0x00
004b 52 MSTORE
004c 60 PUSH1 0x20
004e 52 MSTORE
004f 60 PUSH1 0x40
0051 52 MSTORE
0052 60 PUSH1 0x60
0054 60 PUSH1 0x00
0056 f3 RETURN
0057 de INVALID
0058 ad INVALID
0059 0d INVALID
005a ea INVALID
005b d0 INVALID
005c de INVALID
005d ad INVALID
005e 5b JUMPDEST
005f 7f PUSH32 0x00
 ```

 We see at the line `001f` the `PUSH32` of one-third of our bytecode (the second block). We can now deploy the contract [Solution.sol](Solution.sol) that solves the challenge at the deployment.
