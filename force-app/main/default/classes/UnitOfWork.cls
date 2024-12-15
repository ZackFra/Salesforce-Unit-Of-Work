/**
 * @description Unit of work implementation 
 * @author Zackary Frazier
 * @since 12/13/2024
 */
public without sharing virtual class UnitOfWork implements IUnitOfWork {
    List<SObject> deletedRecords = new List<SObject>();
    List<SObject> undeletedRecords = new List<SObject>();

    Map<SObject, DirtyRecord> dirtyRecordByRecord = new Map<SObject, DirtyRecord>();
    List<DirtyRecord> dirtyRecords = new List<DirtyRecord>();
    Boolean allOrNone;
    AccessLevel access;

    protected IUnitOfWorkDML dml;
    SavePoint sp;

    /**
     * @description Test constructor, for stubbing the dml
     * @param allOrNone `Boolean`
     * @param access `AccessLevel`
     * @param dml `IUnitOfWorkDML`
     */
    @TestVisible
    protected UnitOfWork(Boolean allOrNone, AccessLevel access, IUnitOfWorkDML dml) {
        this.sp = Database.setSavepoint();
        this.dml = dml;
        this.allOrNone = allOrNone;
        this.access = access;
    }
    
    /**
     * @description Constructor all or none and access level
     * @param allOrNone `Boolean`
     * @param access `AccessLevel`
     */
    public UnitOfWork(Boolean allOrNone, AccessLevel access) {
        this(allOrNone, access, new UnitOfWorkDML());
    }
    
    /**
     * @description Base constructor
     */
    public UnitOfWork() {
        this(true, AccessLevel.USER_MODE, new UnitOfWorkDML());
    }
    
    /**
     * @description Register an inserted or updated record
     * @param record `SObject`
     */
    public void registerClean(SObject record) {
        DirtyRecord cleanRecord = new DirtyRecord(record);
        this.dirtyRecordByRecord.put(record, cleanRecord);
        this.dirtyRecords.add(cleanRecord);
    }
    
    /**
     * @description Register a deleted recod
     * @param record `SObject`
     */
    public void registerDelete(SObject record) {
        this.deletedRecords.add(record);
    }
    
    /**
     * @description Register an undeleted recod
     * @param record `SObject`
     */
    public void registerUndelete(SObject record) {
        this.undeletedRecords.add(record);
    }
    
    /**
     * @description Register a dirty upsert (insert / update dependent on a record that does not exist yet)
     * @param parentRecord `SObject`
     * @param childRecord `SObject`
     * @param field `SObjectField`
     * @return  `Relationship`
     */
    public void registerDirty(SObject parentRecord, SObject childRecord, SObjectField field) {
        DirtyRecord dirtyParentRecord = this.dirtyRecordByRecord.get(parentRecord);
        if(dirtyParentRecord == null) {
            dirtyParentRecord = new DirtyRecord(parentRecord);
            this.dirtyRecords.add(dirtyParentRecord);
            this.dirtyRecordByRecord.put(parentRecord, dirtyParentRecord);
        }
        DirtyRecord dirtyChildRecord = new DirtyRecord(childRecord, field);
        dirtyParentRecord.children.add(dirtyChildRecord);
        this.dirtyRecordByRecord.put(childRecord, dirtyChildRecord);
    }
    
    /**
     * @description Commit clean and dirty records, rolling back if an error occurs
     * @return `WorkResults`
     * @throws Any errors
     */
    public WorkResults commitWork() {
        try {
            WorkResults wr = new WorkResults();
            wr = commitUpserts(wr);
            wr = commitDeletesAndUndeletes(wr);
            return wr;
        } catch(Exception e) {
            Database.rollback(this.sp);
            throw e;
        }
    }

    /**
     * @description Reset the savepoint to the current state
     */
    public void resetSavepoint() {
        Database.releaseSavepoint(this.sp);
        this.sp = Database.setSavepoint();
    }
    
    private WorkResults commitDeletesAndUndeletes(WorkResults wr) {
        if(!deletedRecords.isEmpty()) {
            List<Database.DeleteResult> deleteResults = this.dml.onDelete(deletedRecords, allOrNone, access);
            wr.deleteResults.addall(deleteResults);
            this.deletedRecords.clear();
        }
        if(!undeletedRecords.isEmpty()) {
            List<Database.UndeleteResult> undeleteResults = this.dml.onUndelete(undeletedRecords, allOrNone, access);
            wr.undeleteResults.addAll(undeleteResults);
            this.undeletedRecords.clear();
        }
        return wr;
    }
    
    private WorkResults commitUpserts(WorkResults wr) {
        if(this.dirtyRecords.isEmpty()) {
            this.dirtyRecordByRecord.clear();
            return wr;
        }

        List<SObject> upsertableRecords = new List<SObject>();
        for(DirtyRecord dirtyRecord : this.dirtyRecords) {
            upsertableRecords.add(dirtyRecord.record);
        }

        List<Database.UpsertResult> upsertResults = this.dml.onUpsert(upsertableRecords, allOrNone, access);
        wr.upsertResults.addAll(upsertResults);
        List<DirtyRecord> childDirtyRecords = new List<DirtyRecord>();

        for(DirtyRecord dirtyParentRecord : this.dirtyRecords) {
           	List<DirtyRecord> connectedChildRecords = connectDirtyChildRecords(dirtyParentRecord);
           	childDirtyRecords.addAll(connectedChildRecords);
        }

        this.dirtyRecords = childDirtyRecords;
        return commitUpserts(wr);
    }
    
    private List<DirtyRecord> connectDirtyChildRecords(DirtyRecord dirtyParentRecord) {
        SObject newRecord = dirtyParentRecord.record;
        List<DirtyRecord> dirtyChildRecords = dirtyParentRecord.children;
        List<DirtyRecord> newDirtyParentRecords = new List<DirtyRecord>();
        for(DirtyRecord childRecord : dirtyChildRecords) {
            childRecord.record.put(childRecord.field, newRecord.Id);
            newDirtyParentRecords.add(childRecord);
        }
        return newDirtyParentRecords;
    }
}