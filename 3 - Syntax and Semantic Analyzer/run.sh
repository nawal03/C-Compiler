yacc -d -y 1805061_parser.y
g++ -w -c -o y.o y.tab.c
flex 1805061_lexer.l
g++ -w -c -o l.o lex.yy.c
g++ y.o l.o -lfl
./a.out input.txt
