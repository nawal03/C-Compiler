%{
#include<bits/stdc++.h>
#include <cstdio>
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
SymbolTable *eval_table;
ofstream error;
ofstream asmcode;
ofstream optimized_asmcode;

void yycode(string code){
	asmcode<<code<<endl;
}

void yyerror(string msg,bool init=false){

	int line_no=(init? init_line_no:line_count);

	error_count++;
    error<<"Error at line "<<line_no<<": "<<msg<<endl<<endl;

	asmcode.close();
	asmcode.open("code.asm");
	exit(0);
}


struct function_struct{
	string name;
	vector<string> params;
	string return_type;
	bool defined=false;
	string func_name;
};

class GenerteNames{
	string prefix;
	int now;

    public:
	GenerteNames(string s)
	{
		prefix = s;
		now = 0;
	}
	string getName()
	{
		string x = to_string(now);
		string ret = prefix + x;
		now++;
		return ret;
	}
};

class StackPointer{
	int sp;
	vector<SymbolInfo*>v;
	vector<string> scope;

	public:
	map<string,bool>dont_remove;
	StackPointer()
	{
		sp = 0;
	}
	void push(SymbolInfo* var){
		sp+=1;
		v.push_back(var);
		scope.push_back(table->getCurrentScopeId());
		yycode("PUSH AX");
	}

	void pop(){
		while(!scope.empty() && scope.back()==table->getCurrentScopeId()){
			sp-=1;
			v.pop_back();
			scope.pop_back();
			yycode("POP AX");
		}
	}

	int get(SymbolInfo* var)
	{
		int ret = 0;
		for(int i=(int)v.size()-1;i>=0;i--)
		{
			if(v[i]==var)
			{
				ret = i;
				break;
			}
		}

		return (sp-ret-1)*2;
	}

	void dummy_push(){
		sp+=1;
		v.push_back(new SymbolInfo("Dummy",""));
	}
	void dummy_pop(){
		sp-=1;
		v.pop_back();
	}

};

class DSU{
	map<string,string> parent;

	public:
	void make_set(string v) {
		if(parent.count(v)) return;
		parent[v] = v;
	}

	string find_set(string v) {
		if (v == parent[v])
			return v;
		return parent[v] = find_set(parent[v]);
	}

	void union_sets(string a, string b) {
		a = find_set(a);
		b = find_set(b);
		if (a != b)
			parent[b] = a;
	}

};


vector<string> extract(string s,int t=0){
	vector<string>ret;
	string now = "";
	for(int i=0;i<s.size();i++)
	{
		if(!t){
			if(s[i]=='\t' || s[i]=='\n' || s[i]==' ' || s[i]==',')
			{
				if(now.size())
					ret.push_back(now);
				now = "";
			}
			else{
				now += s[i];
			}
		}
		else{
			if(s[i]==' ')
			{
				if(now.size())
					ret.push_back(now);
				now = "";
			}
			else{
				now += s[i];
			}
		}
		
	}
	if(now.size())
		ret.push_back(now);
	return ret;

}

map< string,function_struct > func_map;
function_struct cur_func;
string potential_func_name,potential_ret_type;
string cur_type_specifier;
bool func_starting_scope=false;
bool isFunc=false;
GenerteNames labels("LABEL"); 
GenerteNames temps("T");
GenerteNames vars("VAR");
GenerteNames funcs("FUNC");
string data_segment;
stack<string> lbl_stack;
vector<string> params;
map<string,int> used_t;
StackPointer stp;
DSU dsu;
bool has_main=0;

void code_println(){
	yycode("PRINTLN PROC");
	yycode(";PRINTS THE NUMBER STORED IN AX");
	yycode("CMP AX,0");
	yycode("JGE HERE");
	yycode(";NEGATIVE NUMBER");
	yycode("PUSH AX");
	yycode("MOV AH, 2");
	yycode("MOV DL, '-'");
	yycode("INT 21H");
	yycode("POP AX");
	yycode("NEG AX");
	yycode("HERE:");
	yycode("XOR CX,CX");
	yycode("MOV BX , 10");
	yycode("LOOP_:");
	yycode("CMP AX,0");
	yycode("JE END_LOOP");
	yycode("XOR DX,DX");
	yycode("DIV BX");
	yycode("PUSH DX");
	yycode("INC CX");
	yycode("JMP LOOP_");
	yycode("END_LOOP:");
	yycode("CMP CX,0");
	yycode("JNE PRINTER");
	yycode("MOV AH, 2");
	yycode("MOV DL, '0'");
	yycode("INT 21H");
	yycode("JMP ENDER");
	yycode("PRINTER:");
	yycode("MOV AH,2");
	yycode("POP DX");
	yycode("OR DL,30H");
	yycode("INT 21H");
	yycode("LOOP PRINTER");
	yycode("ENDER:");
	yycode(";PRINT NEW LINE");
	yycode("MOV AH, 2");
	yycode("MOV DL , LF");
	yycode("INT 21H");
	yycode("MOV DL , CR");
	yycode("INT 21H");
	yycode("RET\nPRINTLN ENDP\n");
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
		error<<args.size()<<' '<<params.size()<<endl;
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

string merge_label(string line){
	if(line.substr(0,5)=="LABEL"){
		line.pop_back();
		if(dsu.find_set(line)==line) return line+":";
		else return "";
	}

	vector<string> strings = extract(line,1);
	string ret;
	for(int i=0;i<strings.size();i++){
		if(strings[i].substr(0,5)=="LABEL") strings[i]=dsu.find_set(strings[i]);
		ret+=strings[i]+" ";
	}
	return ret;
	
}

void optimization(){
	ifstream in("code.asm");
	ofstream out("temp.asm");

	string line;
	while(getline(in,line)){
		if(line[0]==';') continue;
		out<<line<<endl;
	}

	in.close();
	out.close();
	in.open("temp.asm");
	out.open("optimized_code.asm");

	while(getline(in,line)){
		if(line.empty() || line[0]==';') continue;
		out<<line<<endl;
	}

	in.close();
	out.close();
	remove("temp.asm");
}

void optimization2(){
	ifstream in("optimized_code.asm");
	ofstream out("temp.asm");

	string line1;
	string line2;
	getline(in,line1);
	while(getline(in,line2)){
		stringstream ss1(line1);
		stringstream ss2(line2);
		string s1,s2;
		ss1>>s1;
		ss2>>s2;

		if(s1=="MOV" && s2=="MOV"){
			string s11,s12,s21,s22;
			ss1>>s11;
			ss1>>s12;
			ss2>>s21;
			ss2>>s22;

			s11.pop_back();
			s21.pop_back();
			
			if(s11==s22 && s12==s21){
				getline(in,line1);
			}
			else{
				out<<line1<<endl;
				line1=line2;
			}
		}
		else{
			out<<line1<<endl;
			line1=line2;
		}
	}
	out<<line1<<endl;

	in.close();
	out.close();
	in.open("temp.asm");
	out.open("optimized_code.asm");
	string line;
	while(getline(in,line)){
		if(line.empty() || line[0]==';') continue;
		out<<line<<endl;
	}

	in.close();
	out.close();
	remove("temp.asm");
}

void optimization3(){
	ifstream in("optimized_code.asm");
	ofstream out("temp.asm");

	string word,word_prev;
	int start=0;
	while(in>>word){
		if(word==".CODE"){
			start=1;
			continue;
		}
		if(start==0){
			continue;
		}

		if(word.back()==',') word.pop_back();

		if(word[0]=='T'){
			used_t[word]=1;
		}

		if(word.substr(0,5)=="LABEL"){
			if(word.back()==':'){
				word.pop_back();
				dsu.make_set(word);
				word+=":";

			}
		}

		if(word.substr(0,5)=="LABEL" && word_prev.substr(0,5)=="LABEL"){
			if(word.back()==':' && word_prev.back()==':'){
				word.pop_back();
				word_prev.pop_back();
				dsu.union_sets(word,word_prev);
				word+=":";
				word_prev+=":";
			}
			
		}
		
		word_prev=word;
	}

	in.close();

	in.open("optimized_code.asm");

	string line;

	while(getline(in,line)){
		stringstream ss(line);
		string s;
		ss>>s;
		if(s[0]=='T'){
			if(used_t.count(s)) out<<line<<endl;
		}
		else{
			out<<line<<endl;
		}

	}

	in.close();

	out.close();
	in.open("temp.asm");
	out.open("optimized_code.asm");

	while(getline(in,line)){
		line = merge_label(line);
		if(line.size()>0) out<<line<<endl;
	}

	in.close();
	out.close();
	remove("temp.asm");
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
		if(!has_main){
			yyerror("main function not found");
		}
		
		ifstream in("code.asm");
		string line;
		ofstream out("temp.asm");
		while(getline(in,line)){
			if(line==".CODE"){
				out<<data_segment<<endl;
			}
			out<<line<<endl;
		}
		in.close();
		out.close();
		asmcode.close();
		asmcode.open("code.asm");
		in.open("temp.asm");
		while(getline(in,line)){
			asmcode<<line<<endl;
		}
		remove("temp.asm");

		//removing comments and new lines
		optimization();
		//removing unnecessary code blocks
		optimization2();
		//removing unnecessary temp vars and labels
		optimization3();
	}
	;

program : program unit 
	{
		string name = $1->getName()+"\n"+$2->getName();
		$$ = new SymbolInfo(name , "program");
	}
	| unit
	{
		string name = $1->getName();
		$$ = new SymbolInfo(name , "program");
	}
	| error
	{
		string name = "";
		$$ = new SymbolInfo(name , "program");
	}
	| program error
	{
		string name = $1->getName();
		$$ = new SymbolInfo(name , "program");
	}
	;
	
unit : var_declaration
	 {
		string name = $1->getName();
		$$ = new SymbolInfo(name , "unit");
	 }
     | func_declaration
	 {
		string name = $1->getName();
		$$ = new SymbolInfo(name , "unit");
	 }
     | func_definition
	 {
		string name = $1->getName();
		$$ = new SymbolInfo(name , "unit");
	 }
     ;
     
func_declaration : type_specifier ID LPAREN func_scope parameter_list RPAREN SEMICOLON
		{

			string name = $1->getName()+" "+$2->getName()+"("+$5->getName()+");";
			$$ = new SymbolInfo(name , "func_declaration");

			stp.pop();
			table->exitScope();
			var_table->exitScope();
			array_table->exitScope();

			cur_func.name=$2->getName();
			cur_func.return_type=$1->getName();
			cur_func.defined=false;
			cur_func.func_name = funcs.getName();

			func_starting_scope=false;

			if(!table->lookup($2->getName())->getIsArr() && !table->lookup($2->getName())->getIsVar()){
				func_map[cur_func.name]=cur_func;
			}

		}
		| type_specifier ID LPAREN func_scope RPAREN SEMICOLON
		{
			string name = $1->getName()+" "+$2->getName()+"("+");";
			$$ = new SymbolInfo(name , "func_declaration");

			stp.pop();
			table->exitScope();
			var_table->exitScope();
			array_table->exitScope();

			cur_func.name=$2->getName();
			cur_func.return_type=$1->getName();
			cur_func.defined=false;
			cur_func.func_name = funcs.getName();

			func_starting_scope=false;

			if(!table->lookup($2->getName())->getIsArr() && !table->lookup($2->getName())->getIsVar()){
				func_map[cur_func.name]=cur_func;
			}
		}
		;
	 
func_definition : type_specifier ID LPAREN func_scope parameter_list RPAREN 
		{
			if(!func_map.count($2->getName())){
				if(isFunc){
					cur_func.name=$2->getName();
					cur_func.return_type=$1->getName();
					cur_func.defined=true;
					cur_func.func_name = funcs.getName();
					func_map[cur_func.name]=cur_func;
					vector<string> args = split($5->getName());
					for(int i=0;i<args.size();i++){
						vector<string> strings = split(args[i],' ');
						if(strings.size()<=1){
							string msg = to_string(cur_func.params.size())+"th parameter's name not given in function definition of var";
							yyerror(msg);break;
						}
					}
				}
			}
			else{
				if(func_map[$2->getName()].defined){
					string msg = "Multiple definition of func "+$2->getName();
					yyerror(msg);
				}
				else{
					func_map[$2->getName()].defined=true;
					if(func_map[$2->getName()].return_type!=cur_func.return_type){
						string msg = "Return type mismatch with function declaration in function "+$2->getName();
						yyerror(msg);
					}
					func_arg_check(cur_func.params, func_map[$2->getName()]);
					vector<string> args = split($5->getName());
					for(int i=0;i<args.size();i++){
						vector<string> strings = split(args[i],' ');
						if(strings.size()<=1){
							string msg = to_string(cur_func.params.size())+"th parameter's name not given in function definition of var";
							yyerror(msg);
							break;
						}
					}
				}
			}

			if(func_map.count($2->getName())){
				if($2->getName()=="main"){
					has_main=1;
					func_map[$2->getName()].func_name = "MAIN";
					yycode("MAIN PROC\n;DATA SEGMENT INITIALIZATION\nMOV AX, @DATA\nMOV DS, AX\n");
				}
				else{
					yycode(func_map[$2->getName()].func_name+" PROC");
				}
			}

			for(int i=(int)params.size()-1;i>=0;i--){
				yycode("MOV BP, SP\n");
				yycode("MOV AX, BP["+to_string((params.size()-i)*2)+"]");
				string tempName = vars.getName();
				data_segment+= tempName+"\tDW\t?\n";
				eval_table->insert(params[i],"");
				eval_table->lookup(params[i])->setTempName(tempName);
				yycode("MOV "+tempName+", AX\n");
			}

		} compound_statement
		{
			string name = $1->getName()+" "+$2->getName()+"("+$5->getName()+")"+$8->getName();
			$$ = new SymbolInfo(name , "func_definition");

			if($2->getName()=="main"){
				yycode(";DOS EXIT\nMOV AH, 4CH\nINT 21H");
			}
			else yycode("RET");

			yycode(func_map[$2->getName()].func_name+" ENDP\n");
			if($2->getName()=="main"){
				yycode("END MAIN\n");
			}
		}
		| type_specifier ID LPAREN func_scope RPAREN 
		{
			if(!func_map.count($2->getName())){
				if(isFunc){
					cur_func.name=$2->getName();
					cur_func.return_type=$1->getName();
					cur_func.defined=true;
					cur_func.func_name = funcs.getName();
					func_map[cur_func.name]=cur_func;
				}
			}
			else{
				if(func_map[$2->getName()].defined){
					string msg = "Multiple definition of func "+$2->getName();yyerror(msg);
				}
				else{
					func_map[$2->getName()].defined=true;
					if(func_map[$2->getName()].return_type!=cur_func.return_type){
						string msg = "Return type mismatch with function declaration in function "+$2->getName();yyerror(msg);
					}
					func_arg_check(cur_func.params, func_map[$2->getName()]);
				}
			}

			if(func_map.count($2->getName())){
				if($2->getName()=="main"){
					has_main=1;
					func_map[$2->getName()].func_name = "MAIN";
					yycode("MAIN PROC\n;DATA SEGMENT INITIALIZATION\nMOV AX, @DATA\nMOV DS, AX\n");
				}
				else{
					yycode(func_map[$2->getName()].func_name+" PROC \n\n");
				}
			}


		} compound_statement
		{
			string name = $1->getName()+" "+$2->getName()+"("+")"+$7->getName();
			$$ = new SymbolInfo(name , "func_definition");
			
			if($2->getName()=="main"){
				yycode(";DOS EXIT\nMOV AH, 4CH\nINT 21H");
			}
			else yycode("RET");

			yycode(func_map[$2->getName()].func_name+" ENDP\n");
			if($2->getName()=="main"){
				yycode("END MAIN\n");
			}
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
				eval_table->enterScope();
				
				cur_func.name=potential_func_name;
				cur_func.return_type = potential_ret_type;
				cur_func.params.clear();
		   }			

parameter_list  : parameter_list COMMA type_specifier ID
		{
			string name = $1->getName()+","+$3->getName()+" "+$4->getName();
			$$ = new SymbolInfo(name , "parameter_list");

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

			params.push_back($4->getName());
		}
		| parameter_list COMMA type_specifier
		{
			string name = $1->getName()+","+$3->getName();
			$$ = new SymbolInfo(name , "parameter_list");

			cur_func.params.push_back($3->getName());

			if($3->getName()=="void"){
				string msg = "Parameter type cannot be void";
				yyerror(msg);
			}
			
		}
 		| type_specifier ID
		{
			string name = $1->getName()+" "+$2->getName();
			$$ = new SymbolInfo(name , "parameter_list");
		
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
			params.clear();
			params.push_back($2->getName());
			
		}
		| type_specifier
		{
			string name = $1->getName();

			$$ = new SymbolInfo(name , "parameter_list");
	
			cur_func.params.push_back($1->getName());

			if($1->getName()=="void"){
				string msg = "Parameter type cannot be void";
				yyerror(msg);
			}
		
		}
		| error 
		{
			string name = "";

			$$ = new SymbolInfo(name , "parameter_list");
		}
		| parameter_list error
		{
			string name = $1->getName();

			$$ = new SymbolInfo(name , "parameter_list");
		}
 		;
	
compound_statement : LCURL enter_scope statements RCURL
			{
				string name = "{\n" + $3->getName() + "\n}";
				$$ = new SymbolInfo(name , "compound_statement");

				stp.pop();
				table->exitScope();
				var_table->exitScope();
				array_table->exitScope();
				eval_table->exitScope();

				
			}
 		    | LCURL enter_scope RCURL
			{
				string name = "{\n}";
				$$ = new SymbolInfo(name , "compound_statement");

				stp.pop();
				table->exitScope();
				var_table->exitScope();
				array_table->exitScope();
				eval_table->exitScope();
				
			}
 		    ;

enter_scope :
			{
				if(!func_starting_scope){
					table->enterScope();
					var_table->enterScope();
					array_table->enterScope();
					eval_table->enterScope();
				}
				func_starting_scope=false;
			}
 		    
var_declaration : type_specifier declaration_list SEMICOLON
		{
			string name = $1->getName() + " " + $2->getName() + ";";
			$$ = new SymbolInfo(name , "var_declaration");
			
			if($1->getName()=="void")
			{
				yyerror("Variable type cannot be void");
			}
		}
 		;
 		 
type_specifier	: INT
		{
			string name = "int";
			$$ = new SymbolInfo(name , "type_specifier");
			cur_type_specifier="int";
			potential_ret_type="int";

		}
 		| FLOAT
		{
			string name = "float";
			$$ = new SymbolInfo(name , "type_specifier");
			cur_type_specifier="float";
			potential_ret_type="float";

		}
 		| VOID
		{
			string name = "void";
			$$ = new SymbolInfo(name , "type_specifier");
			cur_type_specifier="void";
			potential_ret_type="void";
		}
 		;
 		
declaration_list : declaration_list COMMA ID
		  {
				string name = $1->getName()+","+$3->getName();
				$$ = new SymbolInfo(name, "declaration_list");

				if(!table->insert($3->getName() , "ID"))
				{
					string msg="Multiple Declaration of "+$3->getName();
					yyerror(msg);
				}
				else{
					table->lookup($3->getName())->setIsVar();
					var_table->insert($3->getName(), cur_type_specifier);
				}
				
				if(table->getCurrentScopeId()=="1"){
					string tempName = vars.getName();
					data_segment+=tempName+"\tDW\t?\n";
					eval_table->insert($3->getName(),"");
					eval_table->lookup($3->getName())->setTempName(tempName);
				}
				else{
					string tempName = temps.getName();
					data_segment+=tempName+"\tDW\t?\n";
					eval_table->insert($3->getName(),"");
					eval_table->lookup($3->getName())->setTempName(tempName);
					stp.push(eval_table->lookup($3->getName()));

				}
				
		  }
 		  | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
		  {
				string name = $1->getName()+","+$3->getName()+"["+$5->getName()+"]";
				$$ = new SymbolInfo(name, "declaration_list");

				if(!table->insert($3->getName() , "ID"))
				{
					string msg="Multiple Declaration of "+$3->getName();
					yyerror(msg);
				}
				else{
					table->lookup($3->getName())->setIsArr();
					array_table->insert($3->getName() , cur_type_specifier);
				}
				
				string tempName = vars.getName();
				eval_table->insert($3->getName(),"");
				eval_table->lookup($3->getName())->setTempName(tempName);
				data_segment+=tempName+" DW "+$5->getName()+ " DUP(?)\n";
		  }
 		  | ID
		  {
				string name = $1->getName();
				$$ = new SymbolInfo(name, "declaration_list");

				if(!table->insert($1->getName() , "ID"))
				{
					string msg="Multiple Declaration of "+$1->getName();
					yyerror(msg);
				}
				else{
					table->lookup($1->getName())->setIsVar();
					var_table->insert($1->getName(), cur_type_specifier);
				}

				if(table->getCurrentScopeId()=="1"){
					string tempName = vars.getName();
					data_segment+=tempName+"\tDW\t?\n";
					eval_table->insert($1->getName(),"");
					eval_table->lookup($1->getName())->setTempName(tempName);
				}
				else{
					string tempName = temps.getName();
					data_segment+=tempName+"\tDW\t?\n";
					eval_table->insert($1->getName(),"");
					eval_table->lookup($1->getName())->setTempName(tempName);
					stp.push(eval_table->lookup($1->getName()));
				}

		  }
 		  | ID LTHIRD CONST_INT RTHIRD
		  {
				string name = $1->getName()+"["+$3->getName()+"]";
				$$ = new SymbolInfo(name, "declaration_list");
		
				if(!table->insert($1->getName() , "ID"))
				{
					string msg="Multiple Declaration of "+$1->getName();
					yyerror(msg);
				}
				else{
					table->lookup($1->getName())->setIsArr();
					array_table->insert($1->getName() , cur_type_specifier);
				}
				string tempName = vars.getName();
				eval_table->insert($1->getName(),"");
				eval_table->lookup($1->getName())->setTempName(tempName);
				data_segment+=tempName+" DW "+$3->getName()+ " DUP(?)\n";
				
		  }
		  | error 
			{
				string name = "";
				$$ = new SymbolInfo(name , "declaration_list");

			}
			| declaration_list error
			{
				string name = $1->getName();
				$$ = new SymbolInfo(name , "declaration_list");
			}
 		  ;
 		  
statements : statement
	   {
			string name = $1->getName();
			$$ = new SymbolInfo(name , "statements");
	   }
	   | statements statement
	   {
			string name = $1->getName()+"\n"+$2->getName();
			$$ = new SymbolInfo(name , "statements");
	   }
	   | error 
		{
			string name = "";
			$$ = new SymbolInfo(name , "statements");
		}
		| statements error
		{
			string name = $1->getName();
			$$ = new SymbolInfo(name , "statements");
		}
	   ;
	   
statement : var_declaration
	  {
			string name = $1->getName();
			$$ = new SymbolInfo(name , "statement");
	  }
	  | expression_statement
	  {
			string name = $1->getName();
			$$ = new SymbolInfo(name , "statement");
	  }
	  | compound_statement
	  {
			string name = $1->getName();
			$$ = new SymbolInfo(name , "statement");
	  }
	  | FOR LPAREN expression_statement
	  {
			yycode(";for statement");

			string label = labels.getName();
			lbl_stack.push(label);
			yycode(label+":");

	  } expression_statement
	  {
		string exp = $5->getName();
		exp.pop_back();

		string label = lbl_stack.top();
		lbl_stack.pop();
		string label1 = labels.getName();
		string label2 = labels.getName();
		
		
		if(exp!=""){
			string tempName1 = eval_table->lookup(exp)->getTempName();
			yycode("MOV AX, "+tempName1);
			
			yycode("CMP AX, 0");
			yycode("JE "+label2);
			yycode("JMP "+label1);
		}
		else{
			yycode("JMP "+label1);
		}

		string label3 = labels.getName();
		yycode(label3+":");

		lbl_stack.push(label2);
		lbl_stack.push(label3);
		lbl_stack.push(label1);
		lbl_stack.push(label);

	  } expression
	  {
			string label = lbl_stack.top();
			lbl_stack.pop();

			yycode("JMP "+label);
			string label1 = lbl_stack.top();
			lbl_stack.pop();
		
			yycode(label1+":\n");

			

	  } RPAREN statement
	  {
			string name = "for ("+$3->getName()+$5->getName()+$7->getName()+")"+$10->getName();
			$$ = new SymbolInfo(name , "statement");
			
			string label3 = lbl_stack.top();
			lbl_stack.pop();
			yycode("JMP "+label3);
			string label2 = lbl_stack.top();
			lbl_stack.pop();
			yycode(label2+":\n");
			
	  }
	  |if_statement statement %prec LOWER_THAN_ELSE
	  {
			string name = $1->getName()+$2->getName();
			$$ = new SymbolInfo(name , "statement");

			string label = lbl_stack.top();
			lbl_stack.pop();

			yycode(label+":\n");
			
	  }
	  |if_statement statement ELSE 
	  {
			string label = labels.getName();
			yycode("JMP "+label);
			string label2 = lbl_stack.top();
			lbl_stack.pop();
			yycode(label2+":\n");
			lbl_stack.push(label);

	  } statement
	  {
			string name = $1->getName()+$2->getName()+"\nelse "+$5->getName();
			$$ = new SymbolInfo("" , "statement");

			string label = lbl_stack.top();
			lbl_stack.pop();
			yycode(label+":\n");
			
			
	  }
	  | WHILE 
	  {
			string label1 = labels.getName(); 
			yycode(";while statement");
			yycode(label1+":\n");
			lbl_stack.push(label1);

	  } LPAREN expression RPAREN 
	  {
			string label2 = labels.getName();

			string tempName1 = eval_table->lookup($4->getName())->getTempName();
			yycode("MOV AX, "+tempName1);
			yycode("CMP AX, 0");
			yycode("JE "+label2);
			
			lbl_stack.push(label2);

	  }statement
	  {
			string name = "while ("+$4->getName()+")"+$7->getName();
			$$ = new SymbolInfo(name , "statement");
			if($3->getType()=="void"){
				string msg="Void expression used inside while";
				yyerror(msg);
			}

			string label2 = lbl_stack.top();
			lbl_stack.pop();
			string label1 = lbl_stack.top();
			lbl_stack.pop();

			yycode("JMP "+label1);
			yycode(label2+":");
			
	  }
	  | PRINTLN LPAREN ID RPAREN SEMICOLON
	  {
			string name = "println("+$3->getName()+");";
			$$ = new SymbolInfo(name , "statement");
			
			if(table->lookup($3->getName())==NULL){
				string msg="Undeclared variable "+$3->getName();
				yyerror(msg);
			}

			yycode(";"+name);
			string tempName1 = eval_table->lookup($3->getName())->getTempName();
			if(tempName1[0]=='T'){
				int idx = stp.get(eval_table->lookup($3->getName()));
				yycode("MOV BP, SP");
				yycode("MOV AX, BP["+to_string(idx)+"]");
			}
			else{
				yycode("MOV AX, "+tempName1);
			}
			yycode("CALL PRINTLN");
	  }
	  | RETURN expression SEMICOLON
	  {
			string name = "return "+$2->getName()+";";
			$$ = new SymbolInfo(name , "statement");
			if(cur_func.return_type=="void"){
				string msg="Return type mismatch with function declaration in function "+cur_func.name;
				yyerror(msg);
			}
			else if(cur_func.return_type=="int" && $2->getType()=="float"){
				string msg="Return type mismatch with function declaration in function "+cur_func.name;
				yyerror(msg);
			}

			yycode(";"+name);

			if(cur_func.name == "main"){
				yycode(";DOS EXIT\nMOV AH, 4CH\nINT 21H");
			}

			string tempName1 = eval_table->lookup($2->getName())->getTempName();
			stp.pop();
			yycode("MOV AX, "+tempName1);
			yycode("POP DX");
			yycode("PUSH AX");
			yycode("PUSH DX");
			yycode("RET\n");
	  }
	  ;

if_statement : IF LPAREN expression RPAREN
				{
					string name = "if ("+$3->getName()+")";
					$$ = new SymbolInfo(name , "if_statement");

					if($3->getType()=="void"){
						string msg="Void expression used inside if";
						yyerror(msg);
					}

					string tempName1 = eval_table->lookup($3->getName())->getTempName();
					string label1 = labels.getName();

					yycode("; if statement");

					yycode("MOV AX, "+tempName1);
					yycode("CMP AX, 0");
					yycode("JE "+label1);
				
					lbl_stack.push(label1);
				}
	  
expression_statement 	: SEMICOLON
			{
				string name = ";";
				$$ = new SymbolInfo(name , "expression_statement");
			}		
			| expression SEMICOLON
			{
				string name = $1->getName()+";";
				$$ = new SymbolInfo(name , "expression_statement");
			}
			;
	  
variable : ID
	 {
		string name = $1->getName();
		$$ = new SymbolInfo(name , "variable");

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

		yycode(";"+name);

		if(eval_table->lookup($1->getName())->getTempName()[0]=='T'){
			string tempName = eval_table->lookup($1->getName())->getTempName();
			int idx = stp.get(eval_table->lookup($1->getName()));
			yycode("MOV BP, SP");
			yycode("MOV AX, BP["+to_string(idx)+"]");
			yycode("MOV "+tempName+", AX");
		}
	 }		
	 | ID LTHIRD expression RTHIRD
	 {
		string name = $1->getName()+"["+$3->getName()+"]";
		$$ = new SymbolInfo(name , "variable");
		
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

		yycode(";"+name);

		string arrname = eval_table->lookup($1->getName())->getTempName();
		string tempName1 = eval_table->lookup($3->getName())->getTempName();
		yycode("MOV BX, "+tempName1);
		yycode("ADD BX, BX");
		yycode("MOV AX, "+arrname+"[BX]");

		string tempName = temps.getName();
		data_segment+= tempName+"\tDW\t?\n";
		eval_table->insert(name,"");
		eval_table->lookup(name)->setTempName(tempName);
		yycode("MOV "+tempName+", AX\n");
	 }
	 ;

expression : logic_expression
	   {
			string name = $1->getName();
			$$ = new SymbolInfo(name , $1->getType());
	   }	
	   | variable ASSIGNOP logic_expression
	   {
			string name = $1->getName()+"="+$3->getName();
			$$ = new SymbolInfo(name , $1->getType());
			
			if($3->getType()=="void"){
				string msg="Void function used in expression";
				yyerror(msg);
			}
			
			if($1->getType()=="int" && $3->getType()=="float"){
				string msg="Type mismatch";
				yyerror(msg);
			}
			
			yycode(";"+name);

			if($1->getName().back()!=']'){
				
				string tempName1 = eval_table->lookup($1->getName())->getTempName();
				string tempName2 = eval_table->lookup($3->getName())->getTempName();

				if(tempName1[0]=='T'){
					int idx = stp.get(eval_table->lookup($1->getName()));
					yycode("MOV AX, "+tempName2);
					yycode("MOV BP, SP");
					yycode("MOV BP["+to_string(idx)+"], AX");

					string tempName = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
					if(!eval_table->lookup(name)) data_segment+= tempName+"\tDW\t?\n";
					eval_table->insert(name,"");
					eval_table->lookup(name)->setTempName(tempName);
					yycode("MOV "+tempName+", AX\n");
				}
				else{
					yycode("MOV AX, "+tempName2);
					yycode("MOV "+tempName1+", AX");

					string tempName = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
					if(!eval_table->lookup(name)) data_segment+= tempName+"\tDW\t?\n";
					eval_table->insert(name,"");
					eval_table->lookup(name)->setTempName(tempName);
					yycode("MOV "+tempName+", AX\n");
				}
			}
			else{
				vector<string> s = split($1->getName(),'[');
				string arrname = eval_table->lookup(s[0])->getTempName();
				string expression = s[1];
				expression.pop_back();

				string tempName1 = eval_table->lookup(expression)->getTempName();
				string tempName2 = eval_table->lookup($3->getName())->getTempName();

				yycode("MOV BX, "+tempName1);
				yycode("MOV AX, "+tempName2);
				yycode("ADD BX, BX");
				yycode("MOV "+arrname+"[BX], AX");

				string tempName = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
				if(!eval_table->lookup(name)) data_segment+= tempName+"\tDW\t?\n";
				eval_table->insert(name,"");
				eval_table->lookup(name)->setTempName(tempName);
				yycode("MOV "+tempName+", AX\n");
			}

	   }	
	   ;
			
logic_expression : rel_expression 
		 {
			string name = $1->getName();
			$$ = new SymbolInfo(name , $1->getType());
		 }	
		 | rel_expression LOGICOP 
		 {
			yycode("; short circuit logical operation");
			string tempName1 = eval_table->lookup($1->getName())->getTempName();
			yycode("MOV AX, "+tempName1);

			string label1 = labels.getName();

			if($2->getName()=="||"){
				yycode("CMP AX, 0");
				yycode("JNE "+label1);
			}
			else {
				yycode("CMP AX, 0");
				yycode("JE "+label1);
			}

			lbl_stack.push(label1);


			
		 }rel_expression
		 {
			string name = $1->getName()+$2->getName()+$4->getName();
			$$ = new SymbolInfo(name , "int");
			
			if($1->getType()=="void" || $4->getType()=="void"){
				string msg="Void function used in expression";
				yyerror(msg);
			}

			string tempName2 = eval_table->lookup($4->getName())->getTempName();

			yycode("MOV BX, "+tempName2);

			string label1 = lbl_stack.top();
			lbl_stack.pop();
			string label2 = labels.getName();
		
			if($2->getName()=="||"){
				yycode("CMP BX, 0");
				yycode("JNE "+label1);
				yycode("MOV AX, 0");
				yycode("JMP "+label2);
				yycode(label1+":");
				yycode("MOV AX, 1");
				yycode(label2+":");
			

				string tempName = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
				if(!eval_table->lookup(name)) data_segment+= tempName+"\tDW\t?\n";
				eval_table->insert(name,"");
				eval_table->lookup(name)->setTempName(tempName);
				yycode("MOV "+tempName+", AX\n");

			}
			else{
				yycode("CMP BX, 0");
				yycode("JE "+label1);
				yycode("MOV AX, 1");
				yycode("JMP "+label2);
				yycode(label1+":");
				yycode("MOV AX, 0");
				yycode(label2+":");


				string tempName = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
				if(!eval_table->lookup(name)) data_segment+= tempName+"\tDW\t?\n";
				eval_table->insert(name,"");
				eval_table->lookup(name)->setTempName(tempName);
				yycode("MOV "+tempName+", AX\n");
			}
		 }
		 ;
			
rel_expression	: simple_expression
		{
			string name = $1->getName();
			$$ = new SymbolInfo(name , $1->getType());
		}
		| simple_expression RELOP simple_expression
		{
			string name = $1->getName()+$2->getName()+$3->getName();
			$$ = new SymbolInfo(name , "int");
			
			if($1->getType()=="void" || $3->getType()=="void"){
				string msg="Void function used in expression";
				yyerror(msg);
			}

			yycode(";"+name);

			string tempName1 = eval_table->lookup($1->getName())->getTempName();
			string tempName2 = eval_table->lookup($3->getName())->getTempName();

			yycode("MOV AX, "+tempName1);
			yycode("MOV BX, "+tempName2);
			
			string label1 = labels.getName();
			string label2 = labels.getName();

			yycode("CMP AX, BX");

			if($2->getName()=="=="){
				yycode("JNE "+label1);
			}
			else if($2->getName()=="!="){
				yycode("JE "+label1);
			}
			else if($2->getName()==">="){
				yycode("JL "+label1);
			}
			else if($2->getName()=="<="){
				yycode("JG "+label1);
			}
			else if($2->getName()==">"){
				yycode("JLE "+label1);
			}
			else if($2->getName()=="<"){
				yycode("JGE "+label1);
			}

			yycode("MOV AX, 1");
			yycode("JMP "+label2);
			yycode(label1+":");
			yycode("MOV AX, 0");
			yycode(label2+":");

			string tempName = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
			if(!eval_table->lookup(name)) data_segment+= tempName+"\tDW\t?\n";
			eval_table->insert(name,"");
			eval_table->lookup(name)->setTempName(tempName);
			yycode("MOV "+tempName+", AX\n");

		}
		;
				
simple_expression : term
		  {
			string name = $1->getName();
			$$ = new SymbolInfo(name , $1->getType());
		  }
		  | simple_expression ADDOP term 
		  {
			string name = $1->getName()+$2->getName()+$3->getName();
			$$ = new SymbolInfo(name , "simple_expression");
			
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

			yycode(";"+name);

			string tempName1 = eval_table->lookup($1->getName())->getTempName();
			string tempName2 = eval_table->lookup($3->getName())->getTempName();

			yycode("MOV AX, "+tempName1);

			if($2->getName()=="+"){
				if($3->getName()=="0"){

				}
				else if($3->getName()=="1"){
					yycode("INC AX");
				}
				else{
					yycode("MOV BX, "+tempName2);
					yycode("ADD AX, BX");
				}
				
				string tempName = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
				if(!eval_table->lookup(name)) data_segment+= tempName+"\tDW\t?\n";
				eval_table->insert(name,"");
				eval_table->lookup(name)->setTempName(tempName);
				yycode("MOV "+tempName+", AX\n");

			}
			else{
				if($3->getName()=="0"){

				}
				else if($3->getName()=="1"){
					yycode("DEC AX");
				}
				else{
					yycode("MOV BX, "+tempName2);
					yycode("SUB AX, BX");
				}
				
				string tempName = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
				if(!eval_table->lookup(name)) data_segment+= tempName+"\tDW\t?\n";
				eval_table->insert(name,"");
				eval_table->lookup(name)->setTempName(tempName);
				yycode("MOV "+tempName+", AX\n");
			}

		  }
		  ;
					
term :	unary_expression
	 {
			string name = $1->getName();
			$$ = new SymbolInfo(name , $1->getType());
	 }
     |  term MULOP unary_expression
	 {
			string name = $1->getName()+$2->getName()+$3->getName();
			$$ = new SymbolInfo(name , "term");
			
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

			yycode(";"+name);

			yycode("MOV AX,0");
			yycode("MOV BX,0");
			yycode("MOV CX,0");
			yycode("MOV DX,0");


			string tempName1 = eval_table->lookup($1->getName())->getTempName();
			string tempName2 = eval_table->lookup($3->getName())->getTempName();

			yycode("MOV AX, "+tempName1);
			
			if($2->getName()=="*"){
				if($3->getName()=="1"){

				}
				else if($3->getName()=="2"){
					yycode("SHL AX, 1");
				}
				else{
					yycode("MOV BX, "+tempName2);
					yycode("MUL BX");
				}

				string tempName = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
				if(!eval_table->lookup(name)) data_segment+= tempName+"\tDW\t?\n";
				eval_table->insert(name,"");
				eval_table->lookup(name)->setTempName(tempName);
				yycode("MOV "+tempName+", AX\n");


			}
			else if($2->getName()=="/"){
				if($3->getName()=="1"){

				}
				else if($3->getName()=="2"){
					yycode("SHR AX, 1");
				}
				else{
					yycode("MOV BX, "+tempName2);
					yycode("DIV BX");
				}
			
				string tempName = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
				if(!eval_table->lookup(name)) data_segment+= tempName+"\tDW\t?\n";
				eval_table->insert(name,"");
				eval_table->lookup(name)->setTempName(tempName);
				yycode("MOV "+tempName+", AX\n");

			}
			else{
				yycode("MOV BX, "+tempName2);
				yycode("DIV BX");
			
				string tempName = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
				if(!eval_table->lookup(name)) data_segment+= tempName+"\tDW\t?\n";
				eval_table->insert(name,"");
				eval_table->lookup(name)->setTempName(tempName);
				yycode("MOV "+tempName+", DX\n");

			}
	 }
     ;

unary_expression : ADDOP unary_expression
		 {
			string name = $1->getName()+$2->getName();
			$$ = new SymbolInfo(name , $2->getType());
			
			if($2->getType()=="void"){
				string msg="Void function used in expression ";
				yyerror(msg);
			}
			
			string tempName = eval_table->lookup($2->getName())->getTempName();
			yycode(";"+name);
			yycode("MOV AX, "+tempName);

			if($1->getName()=="-"){
				yycode("NEG AX");
			}
			
			string tempName1 = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
		    if(!eval_table->lookup(name)) data_segment+= tempName1+"\tDW\t?\n";
			eval_table->insert(name,"");
			eval_table->lookup(name)->setTempName(tempName1);
			yycode("MOV "+tempName1+", AX\n");

		 }
		 | NOT unary_expression 
		 {
			string name = "!"+$2->getName();
			$$ = new SymbolInfo(name , "int");
		
			if($2->getType()=="void"){
				string msg="Void function used in expression ";
				yyerror(msg);
			}

			yycode(";"+name);

			string label1= labels.getName();
			string label2= labels.getName();

			string tempName = eval_table->lookup($2->getName())->getTempName();
			yycode(";"+name);
			yycode("MOV AX, "+tempName);

			yycode("CMP AX, 0");
			yycode("JE "+label1);
			yycode("MOV AX, 0");
			yycode("JMP "+label2);
			yycode(label1+":");
			yycode("MOV AX, 1");
			yycode(label2+":");
			
			string tempName1 = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
		    if(!eval_table->lookup(name)) data_segment+= tempName1+"\tDW\t?\n";
			eval_table->insert(name,"");
			eval_table->lookup(name)->setTempName(tempName1);
			yycode("MOV "+tempName1+", AX\n");

		 }
		 | factor 
		 {
			string name = $1->getName();
			$$ = new SymbolInfo(name , $1->getType());
		 }
		 ;
	
factor	: variable
	{
		string name = $1->getName();
		$$ = new SymbolInfo(name , $1->getType());
	}
	| ID LPAREN argument_list RPAREN
	{
		string name = $1->getName()+"("+$3->getName()+")";
		$$ = new SymbolInfo(name , "factor");

		if(table->lookup($1->getName())!=NULL && !table->lookup($1->getName())->getIsVar() && !table->lookup($1->getName())->getIsArr()){
			$$->setType(func_map[$1->getName()].return_type);
			vector<string> args = split($3->getType());
			func_arg_check(args,func_map[$1->getName()]);
		}
		else{
			string msg="Undeclared function "+$1->getName();
			yyerror(msg);
		}
		
		yycode(";"+name);

		string code = "CALL "+func_map[$1->getName()].func_name+"\n";
		yycode(code);

		if(func_map[$1->getName()].return_type!="void"){
			yycode("POP DX");
			
			string tempName = temps.getName();
			data_segment+= tempName+"\tDW\t?\n";
			eval_table->insert(name,"");
			eval_table->lookup(name)->setTempName(tempName);
			
			yycode("MOV "+tempName+", DX\n");
		}

		int arg_cnt = func_map[$1->getName()].params.size();
		for(int i=0;i<arg_cnt;i++){
			yycode("POP DX");
			stp.dummy_pop();
		}
	}
	| LPAREN expression RPAREN
	{
		string name = "("+$2->getName()+")";
		$$ = new SymbolInfo(name , $2->getType());
		
		yycode(";"+name);
		
		string tempName = eval_table->lookup($2->getName())->getTempName();
		eval_table->insert(name,"");
		eval_table->lookup(name)->setTempName(tempName);
	}
	| CONST_INT 
	{
		string name = $1->getName();
		$$ = new SymbolInfo(name , "int");

		yycode(";"+name);
		string tempName = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
		if(!eval_table->lookup(name)) data_segment+= tempName+"\tDW\t?\n";
		eval_table->insert(name,"");
		eval_table->lookup(name)->setTempName(tempName);
		
		yycode("MOV AX, "+$1->getName());
		yycode("MOV "+tempName+", AX\n");
		
	}
	| CONST_FLOAT
	{
		string name = $1->getName();
		$$ = new SymbolInfo(name , "float");

		yycode(";"+name);
		string tempName = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
		if(!eval_table->lookup(name)) data_segment+= tempName+"\tDW\t?\n";
		eval_table->insert(name,"");
		eval_table->lookup(name)->setTempName(tempName);
		
		yycode("MOV AX, "+$1->getName());
		yycode("MOV "+tempName+", AX\n");
		
	}
	| variable INCOP
	{
		string name = $1->getName()+"++";
		$$ = new SymbolInfo(name , $1->getType());

		yycode(";"+name);
		if($1->getName().back()!=']'){
			
			string tempName = eval_table->lookup($1->getName())->getTempName();

			yycode("MOV AX, "+tempName);

			string tempName2 = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
			if(!eval_table->lookup(name)) data_segment+= tempName2+"\tDW\t?\n";

			eval_table->insert(name,"");
			eval_table->lookup(name)->setTempName(tempName2);

			yycode("MOV "+tempName2+", AX");
			yycode("INC AX");
			if(tempName[0]=='T'){
				int idx = stp.get(eval_table->lookup($1->getName()));
				yycode("MOV BP, SP");
				yycode("MOV BP["+to_string(idx)+"], AX");
			}
			else{
				yycode("MOV "+tempName+", AX\n");
			}
			
		}
		else{
			vector<string> s = split($1->getName(),'[');
			string arrname = eval_table->lookup(s[0])->getTempName();
			string expression = s[1];
			expression.pop_back();

			string tempName = eval_table->lookup(expression)->getTempName();
			yycode("MOV BX, "+tempName);
			yycode("ADD BX, BX");
			
			yycode("MOV AX, "+arrname+"[BX]");

			string tempName3 = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
			if(!eval_table->lookup(name)) data_segment+= tempName3+"\tDW\t?\n";

			eval_table->insert(name,"");
			eval_table->lookup(name)->setTempName(tempName3);

			yycode("MOV "+tempName3+", AX");
			yycode("INC AX");
			yycode("MOV "+arrname+"[BX]"+", AX\n");
		}
	}
	| variable DECOP
	{
		string name = $1->getName()+"--";
		$$ = new SymbolInfo(name , $1->getType());

		yycode(";"+name);
		if($1->getName().back()!=']'){
			
			string tempName = eval_table->lookup($1->getName())->getTempName();

			yycode("MOV AX, "+tempName);

			string tempName2 = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
			if(!eval_table->lookup(name)) data_segment+= tempName2+"\tDW\t?\n";

			eval_table->insert(name,"");
			eval_table->lookup(name)->setTempName(tempName2);

			yycode("MOV "+tempName2+", AX");
			yycode("DEC AX");
			if(tempName[0]=='T'){
				int idx = stp.get(eval_table->lookup($1->getName()));
				yycode("MOV BP, SP");
				yycode("MOV BP["+to_string(idx)+"], AX");
			}
			else{
				yycode("MOV "+tempName+", AX\n");
			}
		}
		else{
			vector<string> s = split($1->getName(),'[');
			string arrname = eval_table->lookup(s[0])->getTempName();
			string expression = s[1];
			expression.pop_back();

			string tempName = eval_table->lookup(expression)->getTempName();
			yycode("MOV BX, "+tempName);
			yycode("ADD BX, BX");
			
			yycode("MOV AX, "+arrname+"[BX]");

			string tempName3 = (eval_table->lookup(name)? eval_table->lookup(name)->getTempName():temps.getName());
			if(!eval_table->lookup(name)) data_segment+= tempName3+"\tDW\t?\n";

			eval_table->insert(name,"");
			eval_table->lookup(name)->setTempName(tempName3);

			yycode("MOV "+tempName3+", AX");
			yycode("DEC AX");
			yycode("MOV "+arrname+"[BX]"+", AX\n");
		}
	}
	;
	
argument_list : arguments
			  {
					string name = $1->getName();
					$$ = new SymbolInfo(name, $1->getType());
			  }
			  |
			  {
					string name = "";
					$$ = new SymbolInfo(name, "");
			  }
			  ;
	
arguments : arguments COMMA logic_expression
		  {
			string name = $1->getName()+","+$3->getName();
			$$ = new SymbolInfo(name , $1->getType()+","+$3->getType());

			string tempName = eval_table->lookup($3->getName())->getTempName();
			yycode("MOV AX, "+tempName);
			yycode("PUSH AX\n");
			stp.dummy_push();
		  }
	      | logic_expression
		  {
			string name = $1->getName();
			$$ = new SymbolInfo(name , $1->getType());

			string tempName = eval_table->lookup($1->getName())->getTempName();
			yycode("MOV AX, "+tempName);
			yycode("PUSH AX\n");
			stp.dummy_push();
		  }
		  | error 
			{
				string name = "";

				$$ = new SymbolInfo(name , "arguments");
			}
			| arguments error
			{
				string name = $1->getName();

				$$ = new SymbolInfo(name , "arguments");

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
	asmcode.open("code.asm");
	optimized_asmcode.open("optimized_code.asm");
	
	table = new SymbolTable(30);
	array_table = new SymbolTable(30);
	var_table = new SymbolTable(30);
	eval_table = new SymbolTable(30);

	yycode(".MODEL SMALL\n\n.STACK 100H\n\n.DATA\nCR EQU 0DH\nLF EQU 0AH\n\n.CODE\n");
	code_println();

	yyparse();
	
	error.close();
	asmcode.close();
	optimized_asmcode.close();
	fclose(yyin);

}
