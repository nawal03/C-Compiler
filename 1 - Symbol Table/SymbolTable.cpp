class SymbolTable{
    int totalBucket;
    stack< ScopeTable* > stk;
    ScopeTable* currentScope;

public:
    SymbolTable(int totalBucket){
        this->totalBucket = totalBucket;
        currentScope = nullptr;
        stk.push(new ScopeTable(totalBucket));
        currentScope = stk.top();
    }

    void enterScope(){
        ScopeTable* newScope = new ScopeTable(totalBucket, currentScope);
        stk.push(newScope);
        currentScope = newScope;
    }

    void exitScope(){
        if(currentScope == nullptr) return;
        ScopeTable* curr = stk.top();
        stk.pop();
        delete curr;
        if(stk.empty()) currentScope = nullptr;
        else currentScope = stk.top();
    }

    bool insert(string name, string type){
        if(currentScope == nullptr){
            this->enterScope();
        }
        return currentScope->insert(name,type);
    }

    bool erase(string name){
        if(currentScope == nullptr) return false;
        return currentScope->erase(name);
    }

    bool lookup(string name){
        if(currentScope == nullptr) return false;
        ScopeTable* current = currentScope;

        while(current != nullptr){
            if(current->lookup(name)) return true;
            current = current->getParentScope();
        }

        return false;
    }

    void printCurrentScope(){
        if(currentScope == nullptr) return;

        currentScope->print();
    }

    void printAllScope(){
        stack< ScopeTable* > tmp;

        while(!stk.empty()){
            stk.top()->print();
            tmp.push(stk.top());
            stk.pop();
        }

        while(!tmp.empty()){
            stk.push(tmp.top());
            tmp.pop();
        }
    }

    string getCurrentScopeId(){
        if(currentScope == nullptr) return "";
        return currentScope->getId();
    }

    tuple<string, int, int> getAddress(string name){
        if(currentScope == nullptr) return make_tuple("",-1,-1);
        ScopeTable* current = currentScope;

        while(current != nullptr){
            if(current->lookup(name)){
                return make_tuple(current->getId(),current->getHashVal(name),current->getChainPosition(name));
            }
            current = current->getParentScope();
        }
        return make_tuple("",-1,-1);
    }

    ~SymbolTable(){
        while(!stk.empty()){
            ScopeTable* st = stk.top();
            stk.pop();
            delete st;
        }
    }
};

