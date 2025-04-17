%option noyywrap

%x CHAR_STATE
%x STRING_STATE
%x SINGLE_LINE_COMMENT_STATE
%x MULTI_LINE_COMMENT_STATE

%{

#include<bits/stdc++.h>
using namespace std;

#include "1805061_SymbolInfo.cpp"
#include "1805061_ScopeTable.cpp"
#include "1805061_SymbolTable.cpp"

int init_line_no;
int line_count=1;
int error_count=0;
string lexeme;
string str_out;

ofstream tokenout;

SymbolTable symbolTable(7);


string toUpper(string yytext){

	string s;
	for(int i=0;i<yytext.size();i++){
		s+=yytext[i]-'a'+'A';
	}
	return s;

}

void printEOF(){
	symbolTable.printAllScope();
	cout<<"Total lines: "<<line_count<<endl<<"Total errors: "<<error_count;
}

char getSpecialChar(string str_out){
	if(str_out[0]=='\'') {
		str_out.pop_back();
		reverse(str_out.begin(),str_out.end());
		str_out.pop_back();
		reverse(str_out.begin(),str_out.end());
	}
	if(str_out[1]=='n'){
		return'\n';
	}
	else if(str_out[1]=='t'){
		return'\t';
	}
	else if(str_out[1]=='\\'){
		return'\\';
	}
	else if(str_out[1]=='\''){
		return'\'';
	}
	else if(str_out[1]=='a'){
		return'\a';
	}
	else if(str_out[1]=='f'){
		return'\f';
	}
	else if(str_out[1]=='r'){
		return'\r';
	}
	else if(str_out[1]=='b'){
		return'\b';
	}
	else if(str_out[1]=='v'){
		return'\v';
	}
	else if(str_out[1]=='0'){
		return'\0';
	}
	return 0;
}

%}



WHITESPACE [ \t\f\r\v]+ 
LETTER [a-zA-Z]
DIGIT [0-9]
NEWLINE \n
KEYWORD if|else|for|while|do|break|int|char|float|double|void|return|switch|case|return|continue
ID ({LETTER}|_)({LETTER}|{DIGIT}|_)*
INTEGER {DIGIT}+
DECIMAL {INTEGER}?(\.){INTEGER}+
FLOAT ({INTEGER}|{DECIMAL})([Ee][+-]?{INTEGER})?
INVALIDSP {FLOAT}{ID}
TOOMANYDECIMAL {DECIMAL}((\.){FLOAT})+
ILLFORMED {FLOAT}{FLOAT}+
SPECIALCHAR \\n|\\t|\\\\|\\'|\\a|\\f|\\r|\\b|\\v|\\0	


%%

{NEWLINE} {line_count++;}

{KEYWORD}	{
				tokenout<<"<"<<toUpper(yytext)<<"> ";
				cout<<"Line no "<<line_count<<": TOKEN <"<<toUpper(yytext)<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
			}

"+"		|

"-"		{
			tokenout<<"<ADDOP, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"ADDOP"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
			
		}

"*"		|

"/"     |

"%"		{
			tokenout<<"<MULOP, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"MULOP"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
		}

"++"	|

"--"	{
			tokenout<<"<INCOP, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"INCOP"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
		}

"<"		|

"<="    |

">"		|

">="    |

"=="    |

"!="    {
			tokenout<<"<RELOP, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"RELOP"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
		}

"="		{
			tokenout<<"<ASSIGNOP, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"ASSIGNOP"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
		}

"&&"	|

"||"	{
			tokenout<<"<LOGICOP, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"LOGICOP"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
		}

"!"		{
			tokenout<<"<NOT, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"NOT"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
		}

"("		{
			tokenout<<"<LPAREN, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"LPAREN"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
		}

")"		{
			tokenout<<"<RPAREN, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"RPAREN"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
		}

"{"		{
			tokenout<<"<LCURL, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"LCURL"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
            symbolTable.enterScope();
		}

"}"		{
			tokenout<<"<RCURL, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"RCURL"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
            symbolTable.exitScope();
		}

"["		{
			tokenout<<"<LTHIRD, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"LTHIRD"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
		}

"]"		{
			tokenout<<"<RTHIRD, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"RTHIRD"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
		}

","		{
			tokenout<<"<COMMA, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"COMMA"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
		}

";"		{
			tokenout<<"<SEMICOLON, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"SEMICOLON"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
		}

{ID}    {
            
            tokenout<<"<ID, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"ID"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
            symbolTable.insert(yytext, "ID");
            symbolTable.printAllScope();
        }
		
{INTEGER}	{
			tokenout<<"<CONST_INT, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"CONST_INT"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
            symbolTable.insert(yytext, "CONST_INT");
			symbolTable.printAllScope();	
		}

{FLOAT}	{
			tokenout<<"<CONST_FLOAT, "<<yytext<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"CONST_FLOAT"<<"> Lexeme "<<yytext<<" found"<<endl<<endl;
            symbolTable.insert(yytext, "CONST_FLOAT");
			symbolTable.printAllScope();
		}

{INVALIDSP} {
		error_count++;
		cout<<"Error at line no "<<line_count<<": Invalid prefix on ID or invalid suffix on Number "<<yytext<<endl<<endl;
}

{TOOMANYDECIMAL} {
		error_count++;
		cout<<"Error at line no "<<line_count<<": Too many decimal points "<<yytext<<endl<<endl;
}
{ILLFORMED}	{
		error_count++;
		cout<<"Error at line no "<<line_count<<": Ill formed number "<<yytext<<endl<<endl;
}

'{SPECIALCHAR}' {
			str_out="";
			str_out+=getSpecialChar(yytext);
			tokenout<<"<CONST_CHAR, "<<str_out<<"> ";
			cout<<"Line no "<<line_count<<": TOKEN <"<<"CONST_CHAR"<<"> Lexeme "<<yytext<<" found --> <CONST_CHAR, "<<str_out<<">"<<endl<<endl;
            symbolTable.insert(yytext, "CONST_CHAR");
			symbolTable.printAllScope();
}

"'\\n"		| 
"'\\t"		| 
"'\\'"		|
"'\\\\"		|
"'\\a"		| 
"'\\f"		| 
"'\\r"		| 
"'\\b"		| 
"'\\v" 		| 
"'\\0"	{

			error_count++;
			cout<<"Error at line no "<<line_count<<": Unterminated character "<<yytext<<endl<<endl;
}

"'" {
	BEGIN CHAR_STATE;
	lexeme=yytext;
	str_out="";
}

<CHAR_STATE>"\n"|"\r\n" {
	error_count++;
	cout<<"Error at line no "<<line_count<<": Unterminated character "<<lexeme<<endl<<endl;
	line_count++;
	BEGIN INITIAL;
}

<CHAR_STATE><<EOF>> {
	error_count++;
	cout<<"Error at line no "<<line_count<<": Unterminated character "<<lexeme<<endl<<endl;
	printEOF();
	return 0;
}

<CHAR_STATE>"'" {
	lexeme+=yytext;

	if(str_out.size()==1){
		tokenout<<"<CONST_CHAR, "<<str_out<<"> ";
		cout<<"Line no "<<line_count<<": TOKEN <"<<"CONST_CHAR"<<"> Lexeme "<<lexeme<<" found --> <CONST_CHAR, "<<str_out<<">"<<endl<<endl;
        symbolTable.insert(lexeme, "CONST_CHAR");
		symbolTable.printAllScope();
	}
	else if(str_out.size()>1){
		error_count++;
		cout<<"Error at line no "<<line_count<<": Multi character constant error "<<lexeme<<endl<<endl;
	}
	else{
		error_count++;
		cout<<"Error at line no "<<line_count<<": Empty character constant error "<<lexeme<<endl<<endl;
	}
	BEGIN INITIAL;
}

<CHAR_STATE>. {
	lexeme+=yytext;
	str_out+=yytext;
}

"\"" {
	BEGIN STRING_STATE;
	init_line_no = line_count;
	lexeme=yytext;
	str_out="";
}

<STRING_STATE>"\\\"" {
	lexeme+=yytext;
	str_out+="\"";
}

<STRING_STATE>"\\\n"|"\\\r\n" {
	line_count++;
	lexeme+=yytext;
}

<STRING_STATE>"\n"|"\r\n" {
	error_count++;
	cout<<"Error at line no "<<init_line_no<<": Unterminated String "<<lexeme<<endl<<endl;
	line_count++;
	BEGIN INITIAL;
}

<STRING_STATE>{SPECIALCHAR} {
	lexeme+=yytext;
	str_out+=getSpecialChar(yytext);
}

<STRING_STATE><<EOF>> {
	error_count++;
	cout<<"Error at line no "<<init_line_no<<": Unterminated String "<<lexeme<<endl<<endl;
	printEOF();
	return 0;
}
<STRING_STATE>"\"" {
	lexeme+=yytext;
	tokenout<<"<STRING, "<<str_out<<"> ";
	cout<<"Line no "<<init_line_no<<": TOKEN <"<<"STRING"<<"> Lexeme "<<lexeme<<" found --> <STRING, "<<str_out<<">"<<endl<<endl;
	BEGIN INITIAL;
}

<STRING_STATE>. {
	lexeme+=yytext;
	str_out+=yytext;
}


"//" {
	BEGIN SINGLE_LINE_COMMENT_STATE;
	init_line_no = line_count;
	lexeme=yytext;
}

<SINGLE_LINE_COMMENT_STATE>"\\\n"|"\\\r\n" {
	line_count++;
	lexeme+=yytext;
}

<SINGLE_LINE_COMMENT_STATE>"\n"|"\r\n" {
	cout<<"Line no "<<init_line_no<<": TOKEN <"<<"COMMENT"<<"> Lexeme "<<lexeme<<" found"<<endl<<endl;
	line_count++;
	BEGIN INITIAL;
}

<SINGLE_LINE_COMMENT_STATE><<EOF>> {
	cout<<"Line no "<<init_line_no<<": TOKEN <"<<"COMMENT"<<"> Lexeme "<<lexeme<<" found"<<endl<<endl;
	printEOF();
	return 0;
}

<SINGLE_LINE_COMMENT_STATE>. {
	lexeme+=yytext;
}

"/*" {
	BEGIN MULTI_LINE_COMMENT_STATE;
	init_line_no = line_count;
	lexeme=yytext;
}

<MULTI_LINE_COMMENT_STATE>"*/" {
	lexeme+=yytext;
	cout<<"Line no "<<init_line_no<<": TOKEN <"<<"COMMENT"<<"> Lexeme "<<lexeme<<" found"<<endl<<endl;
	BEGIN INITIAL;
}

<MULTI_LINE_COMMENT_STATE>"\n"|"\r\n" {
	line_count++;
	lexeme+=yytext;
}

<MULTI_LINE_COMMENT_STATE><<EOF>> {
	error_count++;
	cout<<"Error at line no "<<init_line_no<<": Unterminated comment "<<lexeme<<endl<<endl;
	printEOF();
	return 0;
}

<MULTI_LINE_COMMENT_STATE>. {
	lexeme+=yytext;
}


{WHITESPACE}    {

                }


<<EOF>> {
	printEOF();
	return 0;
}

. {
	error_count++;
	cout<<"Error at line no "<<line_count<<": Unrecognized character "<<yytext<<endl<<endl;
}

%%

int main(int argc,char *argv[]){
	
	if(argc!=2){
		printf("Please provide input file name and try again\n");
		return 0;
	}
	
	FILE *fin=fopen(argv[1], "r");
	if(fin==NULL){
		cout<<"Cannot open specified file"<<endl<<endl;
		return 0;
	}
	
	tokenout.open("token.txt");
	freopen("log.txt","w",stdout);

	yyin= fin;
	yylex();
	fclose(yyin);
	
	tokenout.close();
	return 0;
}

/*
flex -o 1805061.c 1805061.l
g++ 1805061.c -lfl -o 1805061.out
./1805061.out sample_input1.txt
*/