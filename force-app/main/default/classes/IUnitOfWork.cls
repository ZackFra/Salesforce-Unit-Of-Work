public interface IUnitOfWork {
    void registerClean(SObject record);
    void registerDelete(SObject record);
    void registerUndelete(SObject record);
    Relationship registerDirty(SObject parentRecord, SObject childRecord, SObjectField field);
    Relationship registerDirty(DirtyRecord parentRecord, SObject childRecord, SObjectField field);
    void commitWork();
}