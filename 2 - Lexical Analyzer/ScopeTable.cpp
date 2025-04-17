class ScopeTable{
    SymbolInfo** hashTable;
    int totalBucket;
    ScopeTable* parentScope;
    int childCount;
    int id;

    unsigned long sdbmhash(string str){
        unsigned long hash = 0;

        for(unsigned long c:str)
            hash = c + (hash << 6) + (hash << 16) - hash;

        return hash;
    }

public:
    ScopeTable(int totalBucket,ScopeTable* parentScope=nullptr){
        this->totalBucket = totalBucket;
        this->hashTable = new SymbolInfo*[totalBucket];

        for(int i = 0; i < totalBucket; i++){
            hashTable[i] = new SymbolInfo();
        }

        this->parentScope = parentScope;
        if(parentScope!=nullptr){
            parentScope->childCount++;
            this->id= parentScope->childCount;
        }
        else{
            this->id=1;
        }
        this->childCount=0;
    }

    ScopeTable* getParentScope(){
        return parentScope;
    }

    string getId(){
        string str = "";
        if(this->parentScope == nullptr) return str+=('0'+this->id);

        str = parentScope->getId();
        if(str.size()>0)  str+='.';
        str+=('0'+this->id);
        return str;
    }

    int getHashVal(string name){
        return sdbmhash(name)%totalBucket;
    }

    int getChainPosition(string name){
        int hashVal = getHashVal(name);

        return hashTable[hashVal]->getChainPosition(name);
    }

    bool lookup(string name){
        int hashVal = getHashVal(name);

        if(hashTable[hashVal]->lookup(name)) return true;

        return false;
    }

    bool insert(string name,string type){
        if(lookup(name)) return false;

        int hashVal = getHashVal(name);
        hashTable[hashVal]->insert(name,type);

        return true;
    }

    bool erase(string name){
        if(!lookup(name)) return false;

        int hashVal = getHashVal(name);
        hashTable[hashVal]->erase(name);

        return true;
    }

    void print(){
        cout<<"ScopeTable # "<<this->getId()<<endl;
        for(int i = 0; i < totalBucket; i++){
            if(hashTable[i]->getNext() != nullptr) cout<<i<<" --> ";
            hashTable[i]->print();
            if(hashTable[i]->getNext() != nullptr) cout<<endl;
        }
        cout<<endl;
    }

    ~ScopeTable(){
        for(int i = 0; i < totalBucket; i++){
            delete hashTable[i];
        }
        delete [] hashTable;
    }
};
