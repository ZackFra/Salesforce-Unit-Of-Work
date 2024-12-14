@IsTest
public with sharing class StubbedUnitOfWorkDML implements IUnitOfWorkDML {
    SaveResultsService saveResultsSvc = new SaveResultsService();
    Boolean isSuccess = true;

    /**
     * @description Designates that a call to any method should throw a DmlException
     */
    public void shouldFail() {
        this.isSuccess = false;
    }

    /**
     * @description Returns either an empty list or throws an exception
     * @param records `List<SObject>`
     * @param allOrNone `Boolean`
     * @param access `AccessLevel`
     * @return  `List<Database.UpsertResult>`
     * @exception DmlException
     */
    public List<Database.UpsertResult> onUpsert(List<SObject> records, Boolean allOrNone, AccessLevel access) {
        if(!this.isSuccess) {
            throw new DmlException('Set to failed');
        }
        return saveResultsSvc.upsertResults(records);
    }

    /**
     * @description Returns either an empty list or throws a DmlException
     * @param records `List<SObject>`
     * @param allOrNone `Boolean`
     * @param access `AccessLevel`
     * @return  `List<Database.DeleteResult>`
     * @exception DmlException
     */
    public List<Database.DeleteResult> onDelete(List<SObject> records, Boolean allOrNone, AccessLevel access) {
        if(!this.isSuccess) {
            throw new DmlException('Set to failed');
        }
        return saveResultsSvc.deleteResults(records);
    }

    /**
     * @description Returns either an empty list or throws a DmlException
     * @param records `List<SObject>`
     * @param allOrNone `Boolean`
     * @param access `AccessLevel`
     * @return  `List<Database.UndeleteResult>`
     * @exception DmlException
     */
    public List<Database.UndeleteResult> onUndelete(List<SObject> records, Boolean allOrNone, AccessLevel access) {
        if(!this.isSuccess) {
            throw new DmlException('Set to failed');
        }
        return saveResultsSvc.undeleteResults(records);
    }
}