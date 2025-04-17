#include<bits/stdc++.h>
using namespace std;

#include "1805061_SymbolInfo.cpp"
#include "1805061_ScopeTable.cpp"
#include "1805061_SymbolTable.cpp"


int main(){
    freopen("input.txt","r",stdin);
    freopen("out.txt","w",stdout);

    int totalBucket;
    cin>>totalBucket;

    SymbolTable symbolTable(totalBucket);

    string command;

    while(cin>>command){
        if(command == "I"){
            string name, type;
            cin>>name>>type;

            cout<<command<<" "<<name<<" "<<type<<endl;

            if(!symbolTable.insert(name,type)){
               cout<<"<"<<name<<","<<type<<"> already exists in current ScopeTable"<<endl;
            }
            else{
                tuple<string, int, int> address = symbolTable.getAddress(name);
                cout<<"Inserted in ScopeTable# "<<get<0>(address)<<" at position "<<
                    get<1>(address)<<", "<< get<2>(address)<<endl;
            }
            cout<<endl;
        }
        else if(command == "L"){
            string name;
            cin>>name;

            cout<<command<<" "<<name<<endl;

            if(!symbolTable.lookup(name)){
                cout<<"Not Found"<<endl;
            }
            else{
                tuple<string, int, int> address = symbolTable.getAddress(name);
                cout<<"Found in ScopeTable# "<<get<0>(address)<<" at position "<<
                    get<1>(address)<<", "<< get<2>(address)<<endl;
            }
            cout<<endl;
        }
        else if(command == "D"){
            string name;
            cin>>name;

            cout<<command<<" "<<name<<endl;

            tuple<string, int, int> address = symbolTable.getAddress(name);
            if(!symbolTable.lookup(name)){
                cout<<"Not Found"<<endl;
            }
            else{
                cout<<"Found in ScopeTable# "<<get<0>(address)<<" at position "<<
                    get<1>(address)<<", "<< get<2>(address)<<endl;
            }

            if(!symbolTable.erase(name)){
                cout<<name<<" not found"<<endl;
            }
            else{
                cout<<"Deleted Entry "<<get<1>(address)<<", "<<get<2>(address)<<" from current ScopeTable"<<endl;
            }

            cout<<endl;
        }
        else if(command == "P"){
            string op;
            cin>>op;

            cout<<command<<" "<<op<<endl;

            if(op == "A"){
                symbolTable.printAllScope();
            }
            else if(op == "C"){
                symbolTable.printCurrentScope();
            }
            cout<<endl;
        }
        else if(command == "S"){
            cout<<command<<endl;

            symbolTable.enterScope();
            cout<<"New ScopeTable with id "<<symbolTable.getCurrentScopeId()<<" created"<<endl;
            cout<<endl;
        }
        else if(command == "E"){
            cout<<command<<endl;
            if(symbolTable.getCurrentScopeId() == ""){
                cout<<"NO CURRENT SCOPE"<<endl<<endl;
                continue;
            }
            cout<<"ScopeTable with id "<<symbolTable.getCurrentScopeId()<<" removed"<<endl;
            symbolTable.exitScope();
            cout<<endl;
        }
    }
}
