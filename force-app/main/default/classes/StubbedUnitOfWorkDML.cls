@IsTest
public with sharing class StubbedUnitOfWorkDML implements IUnitOfWorkDML {
    Boolean isSuccess = true;

    public void shouldFail() {
        this.isSuccess = false;
    }

    public List<Database.UpsertResult> onUpsert(List<SObject> records, Boolean allOrNone, AccessLevel access) {
        if(!this.isSuccess) {
            throw new DmlException('Set to failed');
        }
        return new List<Database.UpsertResult>();
    }

    public List<Database.DeleteResult> onDelete(List<SObject> records, Boolean allOrNone, AccessLevel access) {
        if(!this.isSuccess) {
            throw new DmlException('Set to failed');
        }
        return new List<Database.DeleteResult>();
    }

    public List<Database.UndeleteResult> onUndelete(List<SObject> records, Boolean allOrNone, AccessLevel access) {
        if(!this.isSuccess) {
            throw new DmlException('Set to failed');
        }
        return new List<Database.UndeleteResult>();
    }
}