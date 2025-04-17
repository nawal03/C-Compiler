%{
#include<bits/stdc++.h>
using namespace std;
#include "1805061_SymbolInfo.cpp"
#include "1805061_ScopeTable.cpp"
#include "1805061_SymbolTable.cpp"
#define YYSTYPE SymbolInfo*

int yyparse(void);
int yylex(void);
extern FILE *yyin;
extern int line_count;
extern int init_line_no;
extern int error_count;

SymbolTable *table;
SymbolTable *array_table,*var_table;
ofstream error;

struct function_struct{
	string name;
	vector<string> params;
	string return_type;
	bool defined=false;
};

map< string,function_struct > func_map;
function_struct cur_func;
string potential_func_name,potential_ret_type;
string cur_type_specifier;
bool func_starting_scope=false;
bool isFunc=false;

void yyrule(string rule){
	cout<<"Line "<<line_count<<": "<<rule<<endl<<endl;
}

void yypattern(string pattern){
	cout<<pattern<<endl<<endl;
}

void yyerror(string msg,bool init=false){

	int line_no=(init? init_line_no:line_count);

	error_count++;
    cout<<"Error at line "<<line_no<<": "<<msg<<endl<<endl;
    error<<"Error at line "<<line_no<<": "<<msg<<endl<<endl;
}

vector<string> split(string str, char token=','){
	vector<string> strings;
    istringstream f(str);
    string s;    
    while (getline(f, s, token)) {
        strings.push_back(s);
    }
	return strings;
}

void func_arg_check(vector<string>args, function_struct func){
	vector<string> params = func.params;
	if(args.size()!=params.size()){
		string msg="Total number of arguments mismatch with declaration in function "+func.name;
		yyerror(msg);
		return;
	}

	for(int i=0;i<args.size();i++){
		if(args[i]=="int" && params[i]=="float") continue;
		if(args[i]!="float" && args[i]!="int" && args[i]!="void") continue;
		if(params[i]!="float" && params[i]!="int" && params[i]!="void") continue;

		if(args[i]!=params[i]){
			string msg=to_string(i+1)+"th argument mismatch in function "+func.name;
			yyerror(msg);
			return;
		}
	}
}

%}


%token IF ELSE FOR WHILE ID LPAREN RPAREN SEMICOLON COMMA
%token LCURL RCURL INT FLOAT VOID LTHIRD CONST_INT RTHIRD 
%token PRINTLN RETURN ASSIGNOP LOGICOP RELOP ADDOP MULOP 
%token NOT CONST_FLOAT INCOP DECOP CHAR DOUBLE MAIN CONST_CHAR STRING


%type start program unit func_declaration func_definition parameter_list compound_statement var_declaration type_specifier
%type declaration_list statements statement expression_statement variable logic_expression rel_expression simple_expression
%type term unary_expression factor argument_list arguments expression

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

start : program
	{
		yyrule("start : program");
	}
	;

program : program unit 
	{
		string name = $1->getName()+"\n"+$2->getName();
		$$ = new SymbolInfo(name , "program");

		yyrule("program : program unit");
		yypattern(name);
	}
	| unit
	{
		string name = $1->getName();
		$$ = new SymbolInfo(name , "program");

		yyrule("program : unit");
		yypattern(name);
	}
	| error
	{
		string name = "";
		$$ = new SymbolInfo(name , "program");

		yyrule("program : error");
		yypattern(name);
	}
	| program error
	{
		string name = $1->getName();
		$$ = new SymbolInfo(name , "program");

		yyrule("program : program error");
		yypattern(name);
	}
	;
	
unit : var_declaration
	 {
		string name = $1->getName();
		$$ = new SymbolInfo(name , "unit");

		yyrule("unit : var_declaration");
		yypattern(name);
	 }
     | func_declaration
	 {
		string name = $1->getName();
		$$ = new SymbolInfo(name , "unit");

		yyrule("unit : func_declaration");
		yypattern(name);
	 }
     | func_definition
	 {
		string name = $1->getName();
		$$ = new SymbolInfo(name , "unit");

		yyrule("unit : func_definition");
		yypattern(name);
	 }
     ;
     
func_declaration : type_specifier ID LPAREN func_scope parameter_list RPAREN SEMICOLON
		{

			string name = $1->getName()+" "+$2->getName()+"("+$5->getName()+");";
			$$ = new SymbolInfo(name , "func_declaration");

			yyrule("func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");

			table->exitScope();
			var_table->exitScope();
			array_table->exitScope();

			cur_func.name=$2->getName();
			cur_func.return_type=$1->getName();
			cur_func.defined=false;

			func_starting_scope=false;

			if(!table->lookup($2->getName())->getIsArr() && !table->lookup($2->getName())->getIsVar()){
				func_map[cur_func.name]=cur_func;
			}

			yypattern(name);

		}
		| type_specifier ID LPAREN func_scope RPAREN SEMICOLON
		{
			string name = $1->getName()+" "+$2->getName()+"("+");";
			$$ = new SymbolInfo(name , "func_declaration");

			yyrule("func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON");

			table->exitScope();
			var_table->exitScope();
			array_table->exitScope();

			cur_func.name=$2->getName();
			cur_func.return_type=$1->getName();
			cur_func.defined=false;

			func_starting_scope=false;

			if(!table->lookup($2->getName())->getIsArr() && !table->lookup($2->getName())->getIsVar()){
				func_map[cur_func.name]=cur_func;
			}

			yypattern(name);
		}
		;
	 
func_definition : type_specifier ID LPAREN func_scope parameter_list RPAREN {if(!func_map.count($2->getName())){if(isFunc){cur_func.name=$2->getName();cur_func.return_type=$1->getName();cur_func.defined=true;func_map[cur_func.name]=cur_func;vector<string> args = split($5->getName());for(int i=0;i<args.size();i++){vector<string> strings = split(args[i],' ');if(strings.size()<=1){string msg = to_string(cur_func.params.size())+"th parameter's name not given in function definition of var";yyerror(msg);break;}}}}else{if(func_map[$2->getName()].defined){string msg = "Multiple definition of func "+$2->getName();yyerror(msg);}else{func_map[$2->getName()].defined=true;if(func_map[$2->getName()].return_type!=cur_func.return_type){string msg = "Return type mismatch with function declaration in function "+$2->getName();yyerror(msg);}func_arg_check(cur_func.params, func_map[$2->getName()]);vector<string> args = split($5->getName());for(int i=0;i<args.size();i++){vector<string> strings = split(args[i],' ');if(strings.size()<=1){string msg = to_string(cur_func.params.size())+"th parameter's name not given in function definition of var";yyerror(msg);break;}}}}} compound_statement
		{
			string name = $1->getName()+" "+$2->getName()+"("+$5->getName()+")"+$8->getName();
			$$ = new SymbolInfo(name , "func_definition");
		
			yyrule("func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement");
			yypattern(name);	
		}
		| type_specifier ID LPAREN func_scope RPAREN {if(!func_map.count($2->getName())){if(isFunc){cur_func.name=$2->getName();cur_func.return_type=$1->getName();cur_func.defined=true;func_map[cur_func.name]=cur_func;}}else{if(func_map[$2->getName()].defined){string msg = "Multiple definition of func "+$2->getName();yyerror(msg);}else{func_map[$2->getName()].defined=true;if(func_map[$2->getName()].return_type!=cur_func.return_type){string msg = "Return type mismatch with function declaration in function "+$2->getName();yyerror(msg);}func_arg_check(cur_func.params, func_map[$2->getName()]);}}} compound_statement
		{
			string name = $1->getName()+" "+$2->getName()+"("+")"+$7->getName();
			$$ = new SymbolInfo(name , "func_definition");
		
			yyrule("func_definition : type_specifier ID LPAREN RPAREN compound_statement");
			yypattern(name);

		}
 		;

func_scope :
		   {
				if(!func_map.count(potential_func_name)){
					if(!table->insert(potential_func_name,"ID")){
						string msg= "Multiple declaration of "+potential_func_name;
						yyerror(msg);
						isFunc=false;
					}
					else{
						isFunc=true;
					}
				}
				func_starting_scope=true;
				table->enterScope();
				var_table->enterScope();
				array_table->enterScope();
				
				cur_func.name=potential_func_name;
				cur_func.return_type = potential_ret_type;
				cur_func.params.clear();
		   }			

parameter_list  : parameter_list COMMA type_specifier ID
		{
			string name = $1->getName()+","+$3->getName()+" "+$4->getName();
			$$ = new SymbolInfo(name , "parameter_list");
		
			yyrule("parameter_list : parameter_list COMMA type_specifier ID");

			cur_func.params.push_back($3->getName());

			if($3->getName()=="void"){
				string msg = "Parameter type cannot be void";
				yyerror(msg);
			}

			if(!table->insert($4->getName(),"ID")){
				string msg="Multiple declaration of "+ $4->getName() +" in parameter";
				yyerror(msg);
			}
			else{
				table->lookup($4->getName())->setIsVar();
				var_table->insert($4->getName(),$3->getName());
			}
			yypattern(name);
		}
		| parameter_list COMMA type_specifier
		{
			string name = $1->getName()+","+$3->getName();
			$$ = new SymbolInfo(name , "parameter_list");
		
			yyrule("parameter_list : parameter_list COMMA type_specifier");
			

			cur_func.params.push_back($3->getName());

			if($3->getName()=="void"){
				string msg = "Parameter type cannot be void";
				yyerror(msg);
			}
			yypattern(name);
		}
 		| type_specifier ID
		{
			string name = $1->getName()+" "+$2->getName();
			$$ = new SymbolInfo(name , "parameter_list");
		
			yyrule("parameter_list : type_specifier ID");

			cur_func.params.push_back($1->getName());

			if($1->getName()=="void"){
				string msg = "Parameter type cannot be void";
				yyerror(msg);
			}

			if(!table->insert($2->getName(),"ID")){
				string msg="Multiple declaration of "+ $2->getName() +" in parameter";
				yyerror(msg);
			}
			else{
				table->lookup($2->getName())->setIsVar();
				var_table->insert($2->getName(),$1->getName());
			}
			yypattern(name);
		}
		| type_specifier
		{
			string name = $1->getName();

			$$ = new SymbolInfo(name , "parameter_list");
		
			yyrule("parameter_list : type_specifier");

			cur_func.params.push_back($1->getName());

			if($1->getName()=="void"){
				string msg = "Parameter type cannot be void";
				yyerror(msg);
			}
			yypattern(name);
		}
		| error 
		{
			string name = "";

			$$ = new SymbolInfo(name , "parameter_list");
		
			yyrule("parameter_list : error");
			yypattern(name);
		}
		| parameter_list error
		{
			string name = $1->getName();

			$$ = new SymbolInfo(name , "parameter_list");
		
			yyrule("parameter_list : parameter_list error");
			yypattern(name);
		}
 		;
	
compound_statement : LCURL enter_scope statements RCURL
			{
				string name = "{\n" + $3->getName() + "\n}";
				$$ = new SymbolInfo(name , "compound_statement");
			
				yyrule("compound_statement : LCURL statements RCURL");
				yypattern(name);

				table->printAllScope();

				table->exitScope();
				var_table->exitScope();
				array_table->exitScope();

				
			}
 		    | LCURL enter_scope RCURL
			{
				string name = "{\n}";
				$$ = new SymbolInfo(name , "compound_statement");
			
				yyrule("compound_statement : LCURL RCURL");
				yypattern(name);

				table->printAllScope();

				table->exitScope();
				var_table->exitScope();
				array_table->exitScope();

				
			}
 		    ;

enter_scope :
			{
				if(!func_starting_scope){
					table->enterScope();
					var_table->enterScope();
					array_table->enterScope();
				}
				func_starting_scope=false;
			}
 		    
var_declaration : type_specifier declaration_list SEMICOLON
		{
			string name = $1->getName() + " " + $2->getName() + ";";
			$$ = new SymbolInfo(name , "var_declaration");
		
			yyrule("var_declaration : type_specifier declaration_list SEMICOLON");

			if($1->getName()=="void")
			{
				yyerror("Variable type cannot be void");
			}
			yypattern(name);
		}
 		 ;
 		 
type_specifier	: INT
		{
			string name = "int";
			$$ = new SymbolInfo(name , "type_specifier");

			yyrule("type_specifier : INT");

			cur_type_specifier="int";

			potential_ret_type="int";

			yypattern(name);
		}
 		| FLOAT
		{
			string name = "float";
			$$ = new SymbolInfo(name , "type_specifier");

			yyrule("type_specifier : FLOAT");

			cur_type_specifier="float";

			potential_ret_type="float";

			yypattern(name);
		}
 		| VOID
		{
			string name = "void";
			$$ = new SymbolInfo(name , "type_specifier");

			yyrule("type_specifier : VOID");

			cur_type_specifier="void";

			potential_ret_type="void";

			yypattern(name);
	
		}
 		;
 		
declaration_list : declaration_list COMMA ID
		  {
				string name = $1->getName()+","+$3->getName();
				$$ = new SymbolInfo(name, "declaration_list");
				
				yyrule("declaration_list : declaration_list COMMA ID");
				

				if(!table->insert($3->getName() , "ID"))
				{
					string msg="Multiple Declaration of "+$3->getName();
					yyerror(msg);
				}
				else{
					table->lookup($3->getName())->setIsVar();
					var_table->insert($3->getName(), cur_type_specifier);
				}
				yypattern(name);
				
		  }
 		  | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
		  {
				string name = $1->getName()+","+$3->getName()+"["+$5->getName()+"]";
				$$ = new SymbolInfo(name, "declaration_list");
				
				yyrule("declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD");
				

				if(!table->insert($3->getName() , "ID"))
				{
					string msg="Multiple Declaration of "+$3->getName();
					yyerror(msg);
				}
				else{
					table->lookup($3->getName())->setIsArr();
					array_table->insert($3->getName() , cur_type_specifier);
				}
				yypattern(name);
		  }
 		  | ID
		  {
				string name = $1->getName();
				$$ = new SymbolInfo(name, "declaration_list");
				
				yyrule("declaration_list : ID");

				if(!table->insert($1->getName() , "ID"))
				{
					string msg="Multiple Declaration of "+$1->getName();
					yyerror(msg);
				}
				else{
					table->lookup($1->getName())->setIsVar();
					var_table->insert($1->getName(), cur_type_specifier);
				}
				yypattern(name);
		  }
 		  | ID LTHIRD CONST_INT RTHIRD
		  {
				string name = $1->getName()+"["+$3->getName()+"]";
				$$ = new SymbolInfo(name, "declaration_list");
				
				yyrule("declaration_list : ID LTHIRD CONST_INT RTHIRD");
				
				if(!table->insert($1->getName() , "ID"))
				{
					string msg="Multiple Declaration of "+$1->getName();
					yyerror(msg);
				}
				else{
					table->lookup($1->getName())->setIsArr();
					array_table->insert($1->getName() , cur_type_specifier);
				}
				yypattern(name);
		  }
		  | error 
			{
				string name = "";

				$$ = new SymbolInfo(name , "declaration_list");
			
				yyrule("declaration_list : error");
				yypattern(name);
			}
			| declaration_list error
			{
				string name = $1->getName();

				$$ = new SymbolInfo(name , "declaration_list");
			
				yyrule("declaration_list : declaration_list error");
				yypattern(name);
			}
 		  ;
 		  
statements : statement
	   {
			string name = $1->getName();
			$$ = new SymbolInfo(name , "statements");
			
			yyrule("statements : statement");
			yypattern(name);
	   }
	   | statements statement
	   {
			string name = $1->getName()+"\n"+$2->getName();
			$$ = new SymbolInfo(name , "statements");
			
			yyrule("statements : statements statement");
			yypattern(name);
	   }
	   | error 
		{
			string name = "";

			$$ = new SymbolInfo(name , "statements");
		
			yyrule("statements : error");
			yypattern(name);
		}
		| statements error
		{
			string name = $1->getName();

			$$ = new SymbolInfo(name , "statements");
		
			yyrule("statements : statements error");
			yypattern(name);
		}
	   ;
	   
statement : var_declaration
	  {
			string name = $1->getName();
			$$ = new SymbolInfo(name , "statement");
			
			yyrule("statement : var_declaration");
			yypattern(name);
	  }
	  | expression_statement
	  {
			string name = $1->getName();
			$$ = new SymbolInfo(name , "statement");
			
			yyrule("statement : expression_statement");
			yypattern(name);
	  }
	  | compound_statement
	  {
			string name = $1->getName();
			$$ = new SymbolInfo(name , "statement");
			
			yyrule("statement : compound_statement");
			yypattern(name);
	  }
	  | FOR LPAREN expression_statement expression_statement expression RPAREN statement
	  {
			string name = "for ("+$3->getName()+$4->getName()+$5->getName()+")"+$7->getName();
			$$ = new SymbolInfo(name , "statement");
			
			yyrule("statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement");
			yypattern(name);
	  }
	  | IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
	  {
			string name = "if ("+$3->getName()+")"+$5->getName();
			$$ = new SymbolInfo(name , "statement");
			
			yyrule("statement : IF LPAREN expression RPAREN statement");

			if($3->getType()=="void"){
				string msg="Void expression used inside if";
				yyerror(msg);
			}
			yypattern(name);
	  }
	  | IF LPAREN expression RPAREN statement ELSE statement
	  {
			string name = "if ("+$3->getName()+")"+$5->getName()+"\nelse "+$7->getName();
			$$ = new SymbolInfo(name , "statement");
			
			yyrule("statement : IF LPAREN expression RPAREN statement ELSE statement");

			if($3->getType()=="void"){
				string msg="Void expression used inside if";
				yyerror(msg);
			}
			yypattern(name);
	  }
	  | WHILE LPAREN expression RPAREN statement
	  {
			string name = "while ("+$3->getName()+")"+$5->getName();
			$$ = new SymbolInfo(name , "statement");
			
			yyrule("statement : WHILE LPAREN expression RPAREN statement");

			if($3->getType()=="void"){
				string msg="Void expression used inside while";
				yyerror(msg);
			}
			yypattern(name);
	  }
	  | PRINTLN LPAREN ID RPAREN SEMICOLON
	  {
			string name = "println("+$3->getName()+");";
			$$ = new SymbolInfo(name , "statement");
			
			yyrule("statement : PRINTLN LPAREN ID RPAREN SEMICOLON");

			if(table->lookup($3->getName())==NULL){
				string msg="Undeclared variable "+$3->getName();
				yyerror(msg);
			}
			yypattern(name);
	  }
	  | RETURN expression SEMICOLON
	  {
			string name = "return "+$2->getName()+";";
			$$ = new SymbolInfo(name , "statement");
			
			yyrule("statement : RETURN expression SEMICOLON");

			if(cur_func.return_type=="void"){
				string msg="Return type mismatch with function declaration in function "+cur_func.name;
				yyerror(msg);
			}
			else if(cur_func.return_type=="int" && $2->getType()=="float"){
				string msg="Return type mismatch with function declaration in function "+cur_func.name;
				yyerror(msg);
			}

			yypattern(name);
	  }
	  ;
	  
expression_statement 	: SEMICOLON
			{
				string name = ";";
				$$ = new SymbolInfo(name , "expression_statement");
				
				yyrule("expression_statement : SEMICOLON");
				yypattern(name);
			}		
			| expression SEMICOLON
			{
				string name = $1->getName()+";";
				$$ = new SymbolInfo(name , "expression_statement");
				
				yyrule("expression_statement : expression SEMICOLON");
				yypattern(name);
			} 
			;
	  
variable : ID
	 {
		
		string name = $1->getName();
		$$ = new SymbolInfo(name , "variable");
		
		yyrule("variable : ID");

		if(table->lookup($1->getName())==NULL){
			string msg="Undeclared variable "+$1->getName();
			yyerror(msg);
		}
		else if(table->lookup($1->getName())->getIsArr()){
			string msg="Type mismatch, "+$1->getName()+" is an array";
			yyerror(msg);
		}
		else if(table->lookup($1->getName())->getIsVar()){
			$$->setType(var_table->lookup($1->getName())->getType());
		}
		else{
			string msg = "Invalid operation for function "+$1->getName();
			yyerror(msg);
		}
		yypattern(name);

	 }		
	 | ID LTHIRD expression RTHIRD
	 {
		string name = $1->getName()+"["+$3->getName()+"]";
		$$ = new SymbolInfo(name , "variable");
		
		yyrule("variable : ID LTHIRD expression RTHIRD");

		if(table->lookup($1->getName())==NULL){
			string msg="Undeclared variable "+$1->getName();
			yyerror(msg);
		}
		else if(table->lookup($1->getName())->getIsVar()){
			string msg="Type mismatch, "+$1->getName()+" is not an array";
			yyerror(msg);
		}
		else if(table->lookup($1->getName())->getIsArr()){
			$$->setType(array_table->lookup($1->getName())->getType());
		}
		else{
			string msg = "Invalid operation for function "+$1->getName();
			yyerror(msg);
		}

		if($3->getType()!="int"){
			string msg="Expression inside third brackets not an integer";
			yyerror(msg);
		}
		
		yypattern(name);
	 }
	 ;

expression : logic_expression
	   {
			string name = $1->getName();
			$$ = new SymbolInfo(name , $1->getType());
			
			yyrule("expression : logic_expression");
			yypattern(name);
	   }	
	   | variable ASSIGNOP logic_expression
	   {
			string name = $1->getName()+"="+$3->getName();
			$$ = new SymbolInfo(name , $1->getType());
			
			yyrule("expression : variable ASSIGNOP logic_expression");

			if($3->getType()=="void"){
				string msg="Void function used in expression";
				yyerror(msg);
			}
			
			if($1->getType()=="int" && $3->getType()=="float"){
				string msg="Type mismatch";
				yyerror(msg);
			}
			yypattern(name);
	   }	
	   ;
			
logic_expression : rel_expression 
		 {
			string name = $1->getName();
			$$ = new SymbolInfo(name , $1->getType());
			
			yyrule("logic_expression : rel_expression");
			yypattern(name);
		 }	
		 | rel_expression LOGICOP rel_expression
		 {
			string name = $1->getName()+$2->getName()+$3->getName();
			$$ = new SymbolInfo(name , "int");
			
			yyrule("logic_expression : rel_expression LOGICOP rel_expression");

			if($1->getType()=="void" || $3->getType()=="void"){
				string msg="Void function used in expression";
				yyerror(msg);
			}

			yypattern(name);
		 }
		 ;
			
rel_expression	: simple_expression
		{
			string name = $1->getName();
			$$ = new SymbolInfo(name , $1->getType());
			
			yyrule("rel_expression : simple_expression");
			yypattern(name);
		}
		| simple_expression RELOP simple_expression
		{
			string name = $1->getName()+$2->getName()+$3->getName();
			$$ = new SymbolInfo(name , "int");
			
			yyrule("rel_expression : simple_expression RELOP simple_expression");
			
			if($1->getType()=="void" || $3->getType()=="void"){
				string msg="Void function used in expression";
				yyerror(msg);
			}

			yypattern(name);
		}
		;
				
simple_expression : term
		  {
			string name = $1->getName();
			$$ = new SymbolInfo(name , $1->getType());
			
			yyrule("simple_expression : term");
			yypattern(name);
		  }
		  | simple_expression ADDOP term 
		  {
			string name = $1->getName()+$2->getName()+$3->getName();
			$$ = new SymbolInfo(name , "simple_expression");
			
			yyrule("simple_expression : simple_expression ADDOP term");
			
			if($1->getType()=="void" || $3->getType()=="void"){
				string msg="Void function used in expression";
				yyerror(msg);
			}
			else if($1->getType()=="int" && $3->getType()=="int"){
				$$->setType("int");
			}
			else if($1->getType()=="float" && $3->getType()=="int"){
				$$->setType("float");
			}
			else if($1->getType()=="int" && $3->getType()=="float"){
				$$->setType("float");
			}

			yypattern(name);
		  }
		  ;
					
term :	unary_expression
	 {
			string name = $1->getName();
			$$ = new SymbolInfo(name , $1->getType());
			
			yyrule("term : unary_expression");
			yypattern(name);
	 }
     |  term MULOP unary_expression
	 {
			string name = $1->getName()+$2->getName()+$3->getName();
			$$ = new SymbolInfo(name , "term");
			
			yyrule("term : term MULOP unary_expression");
			
			if($1->getType()=="void" || $3->getType()=="void"){
				string msg="Void function used in expression";
				yyerror(msg);
			}
			else if($1->getType()=="int" && $3->getType()=="int"){
				$$->setType("int");
			}
			else if($1->getType()=="float" && $3->getType()=="int"){
				$$->setType("float");
			}
			else if($1->getType()=="int" && $3->getType()=="float"){
				$$->setType("float");
			}

			bool isZero=1;

			for(auto ch: $3->getName()){
				if(ch!='-' && ch!='0' && ch!='.') isZero=0;
			}

			if($2->getName()=="/"){
				if(isZero){
					string msg="Division by zero";
					yyerror(msg);
					$$->setType("term");
				}
			}
			else if($2->getName()=="%"){
				if($$->getType()=="float"){
					string msg="Non-integer operand on modulus operator";
					yyerror(msg);
					$$->setType("term");
				}
				if(isZero){
					string msg="Modulus by Zero";
					yyerror(msg);
					$$->setType("term");
				}
			}

			yypattern(name);

	 }
     ;

unary_expression : ADDOP unary_expression
		 {
			string name = $1->getName()+$2->getName();
			$$ = new SymbolInfo(name , $2->getType());
			
			yyrule("unary_expression : ADDOP unary_expression");
			
			if($2->getType()=="void"){
				string msg="Void function used in expression ";
				yyerror(msg);
			}

			yypattern(name);

		 }
		 | NOT unary_expression 
		 {
			string name = "!"+$2->getName();
			$$ = new SymbolInfo(name , "int");
			
			yyrule("unary_expression : NOT unary_expression");
	
			if($2->getType()=="void"){
				string msg="Void function used in expression ";
				yyerror(msg);
			}

			yypattern(name);

		 }
		 | factor 
		 {
			string name = $1->getName();
			$$ = new SymbolInfo(name , $1->getType());
			
			yyrule("unary_expression : factor");
			yypattern(name);
		 }
		 ;
	
factor	: variable
	{
		string name = $1->getName();
		$$ = new SymbolInfo(name , $1->getType());


		
		yyrule("factor : variable");
		yypattern(name);
	}
	| ID LPAREN argument_list RPAREN
	{
		string name = $1->getName()+"("+$3->getName()+")";
		$$ = new SymbolInfo(name , "factor");
		
		yyrule("factor : ID LPAREN argument_list RPAREN");

		if(table->lookup($1->getName())!=NULL && !table->lookup($1->getName())->getIsVar() && !table->lookup($1->getName())->getIsArr()){
			$$->setType(func_map[$1->getName()].return_type);
			vector<string> args = split($3->getType());
			func_arg_check(args,func_map[$1->getName()]);
		}
		else{
			string msg="Undeclared function "+$1->getName();
			yyerror(msg);
		}
		yypattern(name);
	}
	| LPAREN expression RPAREN
	{
		string name = "("+$2->getName()+")";
		$$ = new SymbolInfo(name , $2->getType());
		
		yyrule("factor : LPAREN expression RPAREN");
		yypattern(name);
	}
	| CONST_INT 
	{
		string name = $1->getName();
		$$ = new SymbolInfo(name , "int");
		
		yyrule("factor : CONST_INT");
		yypattern(name);
	}
	| CONST_FLOAT
	{
		string name = $1->getName();
		$$ = new SymbolInfo(name , "float");
		
		yyrule("factor : CONST_FLOAT");
		yypattern(name);
	}
	| variable INCOP
	{
		string name = $1->getName()+"++";
		$$ = new SymbolInfo(name , $1->getType());

		yyrule("factor : variable INCOP");
		yypattern(name);
	}
	| variable DECOP
	{
		string name = $1->getName()+"--";
		$$ = new SymbolInfo(name , $1->getType());
		
		yyrule("factor : variable DECOP");
		yypattern(name);
	}
	;
	
argument_list : arguments
			  {
					string name = $1->getName();
					$$ = new SymbolInfo(name, $1->getType());

					yyrule("argument_list : arguments");
					yypattern(name);
			  }
			  |
			  {
					string name = "";
					$$ = new SymbolInfo(name, "argument_list");

					yyrule("argument_list : ");
					yypattern(name);
			  }
			  ;
	
arguments : arguments COMMA logic_expression
		  {
			string name = $1->getName()+","+$3->getName();
			$$ = new SymbolInfo(name , $1->getType()+","+$3->getType());
		
			yyrule("arguments : arguments COMMA logic_expression");
			yypattern(name);
		  }
	      | logic_expression
		  {
			string name = $1->getName();
			$$ = new SymbolInfo(name , $1->getType());
		
			yyrule("arguments : logic_expression");
			yypattern(name);
		  }
		  | error 
			{
				string name = "";

				$$ = new SymbolInfo(name , "arguments");
			
				yyrule("arguments : error");
				yypattern(name);
			}
			| arguments error
			{
				string name = $1->getName();

				$$ = new SymbolInfo(name , "arguments");
			
				yyrule("arguments : arguments error");
				yypattern(name);
			}
	      ;
 
%%
int main(int argc,char *argv[])
{
	if(argc != 2)
	{
		cout << "Please provide a file name" << endl;
		return 0;
	}
	FILE *fin = fopen(argv[1],"r");
	if(fin == NULL)
	{
		cout << "Can't open file" << endl;
		return 0;
	}
	yyin = fin;
	freopen("log.txt", "w", stdout);
	error.open("error.txt", ios::out);
	
	
	table = new SymbolTable(30);
	array_table = new SymbolTable(30);
	var_table = new SymbolTable(30);
	yyparse();
	
	
	table->printAllScope();
	
	cout << "Total Lines: " << line_count << endl;
	cout << "Total Errors: " << error_count << endl << endl;
	
	
	error.close();
	fclose(yyin);

}
