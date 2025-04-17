class SymbolInfo{
    string name;
    string type;
    SymbolInfo* next;

public:
    SymbolInfo(){
        this->next = nullptr;
    }

    SymbolInfo(string name, string type){
        this->name = name;
        this->type = type;
        this->next = nullptr;
    }

    SymbolInfo* getNext(){
        return next;
    }

    int getChainPosition(string name){
        int position = -1, ret = -1;
        SymbolInfo* current = this;

        while(current->next != nullptr){
            current = current->next;
            position++;
            if(name == current->name){
                ret = position;
                break;
            }
        }

        return ret;
    }

    void insert(string name, string type){
        SymbolInfo* symbolInfo = new SymbolInfo(name,type);
        SymbolInfo* current = this;

        while(current->next != nullptr){
            current = current->next;
        }

        current->next = symbolInfo;
    }

    bool lookup(string name){
        SymbolInfo* current = this;

        while(current->next != nullptr){
            current = current->next;
            if(current->name == name) return true;
        }

        return false;
    }

    void erase(string name){
        SymbolInfo* current = this;
        SymbolInfo* prev;
        while(current->next != nullptr){
            prev = current;
            current = current->next;
            if(current->name == name){
                prev->next = current->next;
                current->next = nullptr;
                delete current;
                break;
            }
        }
    }

    void print(){
        SymbolInfo* current = this;

        while(current->next != nullptr){
            current = current->next;
            cout<<" < "<<current->name<<" : "<<current->type<<" >";
        }
    }

    ~SymbolInfo(){
        SymbolInfo* current = next;
        while(current!= nullptr){
            SymbolInfo* prev = current;
            current = current->next;
            prev->next = nullptr;
            delete prev;
        }
    }
};
