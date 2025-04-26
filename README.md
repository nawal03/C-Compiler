# C Compiler for a Subset of the C Language

This project is a custom C compiler built for a simplified subset of the C programming language. It performs all major stages of compilation including lexical analysis, syntax parsing, semantic analysis, symbol table management, and intermediate code generation targeting Intel 8086 assembly.

## ✨ Features

- **Lexical Analysis**: Implemented using **Flex** to tokenize C source code
- **Syntax & Semantic Analysis**: Implemented using **Bison** with grammar rules and semantic checks
- **Symbol Table**: Developed in **C++**, handles variable declarations, types, and scopes
- **Intermediate Code Generation**: Produces optimized **Intel 8086 assembly** instructions on the fly as output

