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
#include "y.tab.h"
#define YYSTYPE SymbolInfo*


extern SymbolTable *table;
void yyerror(string, bool init=false);
extern YYSTYPE yylval;
extern string potential_func_name;

int init_line_no;
int line_count=1;
int error_count=0;
string lexeme;
string str_out;

ofstream tokenout;

SymbolTable symbolTable(7);



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
ADDOP [+-] 
MULOP [*/%]


%%

{NEWLINE} {line_count++;}

"if" {return IF;}
"else" {return ELSE;}
"for" {return FOR;}
"while" {return WHILE;}
"int" {return INT;}
"float" {return FLOAT;}
"double" {return DOUBLE;}
"char" {return CHAR;}
"return" {return RETURN;}
"void" {return VOID;}
"println"	{return PRINTLN;}

{ADDOP} { 
			SymbolInfo *s= new  SymbolInfo(yytext, "ADDOP");
			yylval= (YYSTYPE)s;
			return ADDOP;
		}



{MULOP}	{
			SymbolInfo *s= new  SymbolInfo(yytext, "MULOP");
			yylval = (YYSTYPE)s;
			return MULOP;
		}


"=" 	{return ASSIGNOP;}

">" |
"<" |
">=" |
"<=" |
"==" |
"!=" {
		SymbolInfo *s= new  SymbolInfo(yytext, "RELOP");
		yylval = (YYSTYPE)s;
		return RELOP;
	}

"&&"	|
"||"	{
			SymbolInfo *s= new  SymbolInfo(yytext, "LOGICOP");
			yylval = (YYSTYPE)s;
			return LOGICOP;
		}

"!"		{	return NOT; }


";" 	{return SEMICOLON;}
"," 	{return COMMA;}
"(" 	{return LPAREN;}
")" 	{return RPAREN;}
"{" 	{return LCURL;}
"}" 	{return RCURL;}
"[" 	{return LTHIRD;}
"]" 	{return RTHIRD;}
"++" 	{return INCOP;}
"--" 	{return DECOP;}


{ID}    {
            SymbolInfo *s= table->lookup(yytext);
			
			if(s==NULL)
			{					
				s=new SymbolInfo(yytext,"ID");
			}
			yylval = (YYSTYPE)s;

			potential_func_name=yytext;

			return ID;
        }
		
{INTEGER}	{
			SymbolInfo *s= new  SymbolInfo(yytext, "CONST_INT");
			yylval = (YYSTYPE)s;
			return CONST_INT;	
		}

{FLOAT}	{
			SymbolInfo *s= new  SymbolInfo(yytext, "CONST_FLOAT");
			yylval = (YYSTYPE)s;
			return CONST_FLOAT;
		}

{INVALIDSP} {
		string msg=(string)"Invalid prefix on ID or invalid suffix on Number "+yytext;
		yyerror(msg);
}

{TOOMANYDECIMAL} {
		string msg=(string)"Too many decimal points "+yytext;
		yyerror(msg);
}

{ILLFORMED}	{
		string msg=(string)"Ill formed number "+yytext;
		yyerror(msg);
}

'{SPECIALCHAR}' {
			SymbolInfo *s= new  SymbolInfo(str_out, "CONST_INT");
			yylval = (YYSTYPE)s;
			return CONST_CHAR;
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

		string msg=(string)"Unterminated character "+yytext;
		yyerror(msg);
}

"'" {
	BEGIN CHAR_STATE;
	lexeme=yytext;
	str_out="";
}

<CHAR_STATE>"\n"|"\r\n" {
	string msg="Unterminated character "+lexeme;
	yyerror(msg);
	line_count++;
	BEGIN INITIAL;
}

<CHAR_STATE><<EOF>> {
	string msg="Unterminated character "+lexeme;
	yyerror(msg);
	return 0;
}

<CHAR_STATE>"'" {
	lexeme+=yytext;
	BEGIN INITIAL;
	if(str_out.size()==1){
		SymbolInfo *s= new  SymbolInfo(str_out, "CONST_INT");
		yylval = (YYSTYPE)s;
		return CONST_CHAR;
	}
	else if(str_out.size()>1){
		string msg="Multi character constant error "+lexeme;
		yyerror(msg);
	}
	else{
		string msg="Empty character constant error "+lexeme;
		yyerror(msg);
	}
	
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
	string msg="Unterminated String "+lexeme;
	yyerror(msg,true);
	line_count++;
	BEGIN INITIAL;
}

<STRING_STATE>{SPECIALCHAR} {
	lexeme+=yytext;
	str_out+=getSpecialChar(yytext);
}

<STRING_STATE><<EOF>> {
	string msg="Unterminated String "+lexeme;
	yyerror(msg,true);
	return 0;
}
<STRING_STATE>"\"" {
	lexeme+=yytext;
	BEGIN INITIAL;
	SymbolInfo *s= new  SymbolInfo(str_out, "STRING");
	yylval = (YYSTYPE)s;
	return STRING;
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
	line_count++;
	BEGIN INITIAL;
}

<SINGLE_LINE_COMMENT_STATE><<EOF>> {
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
	BEGIN INITIAL;
}

<MULTI_LINE_COMMENT_STATE>"\n"|"\r\n" {
	line_count++;
	lexeme+=yytext;
}

<MULTI_LINE_COMMENT_STATE><<EOF>> {
	string msg=
	"Unterminated comment "+lexeme;
	yyerror(msg,true);
	return 0;
}

<MULTI_LINE_COMMENT_STATE>. {
	lexeme+=yytext;
}


{WHITESPACE}    {

                }


<<EOF>> {
	return 0;
}

. {
	string msg=(string)"Unrecognized character "+yytext;
	yyerror(msg);
}

%%