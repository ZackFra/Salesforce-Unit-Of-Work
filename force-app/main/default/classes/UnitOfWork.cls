/**
 * @description Unit of work implementation 
 * @author Zackary Frazier
 * @since 12/13/2024
 */
public without sharing virtual class UnitOfWork implements IUnitOfWork {
    List<SObject> cleanRecords = new List<SObject>();
    List<SObject> deletedRecords = new List<SObject>();
    List<SObject> undeletedRecords = new List<SObject>();
    
    List<DirtyRecord> dirtyRecords = new List<DirtyRecord>();
    Boolean allOrNone;
    AccessLevel access;

    IUnitOfWorkDML dml;
    SavePoint sp;

    /**
     * @description Test constructor, for stubbing the dml
     * @param allOrNone `Boolean`
     * @param access `AccessLevel`
     * @param dml `IUnitOfWorkDML`
     */
    public UnitOfWork(Boolean allOrNone, AccessLevel access, IUnitOfWorkDML dml) {
        this.sp = Database.setSavepoint();
        if(dml != null) {
            this.dml = dml;
        } else {
            this.dml = new UnitOfWorkDML();
        }
        this.allOrNone = allOrNone;
        this.access = access;
    }
    
    /**
     * @description Constructor all or none and access level
     * @param allOrNone `Boolean`
     * @param access `AccessLevel`
     */
    public UnitOfWork(Boolean allOrNone, AccessLevel access) {
        this(allOrNone, access, null);
    }
    
    /**
     * @description Base constructor
     */
    public UnitOfWork() {
        this(true, AccessLevel.USER_MODE, null);
    }
    
    /**
     * @description Register an inserted or updated record
     * @param record `SObject`
     */
    public void registerClean(SObject record) {
        this.cleanRecords.add(record);
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
     * @description Register a dirty update (insert / update dependent on a record that does not exist yet)
     * @param parentRecord `SObject`
     * @param childRecord `SObject`
     * @param field `SObjectField`
     * @return  `Relationship`
     */
    public Relationship registerDirty(SObject parentRecord, SObject childRecord, SObjectField field) {
        DirtyRecord dirtyParentRecord = new DirtyRecord(parentRecord);
        this.dirtyRecords.add(dirtyParentRecord);
        return registerDirty(dirtyParentRecord, childRecord, field);
    }
    
    /**
     * @description Register a dirty update, for an already registered parent recod
     * @param dirtyParentRecord `DirtyRecord`
     * @param childRecord `SObject`
     * @param field `SObjectField`
     * @return  `Relationship`
     */
    public Relationship registerDirty(DirtyRecord dirtyParentRecord, SObject childRecord, SObjectField field) {
        DirtyRecord dirtyChildRecord = new DirtyRecord(childRecord, field);
        dirtyParentRecord.children.add(dirtyChildRecord);
        Relationship parentChildRel = new Relationship(dirtyParentRecord, dirtyChildRecord);
        return parentChildRel;
    }
    
    /**
     * @description Commit clean and dirty records, rolling back if an error occurs
     * @return `WorkResults`
     * @throws Any errors
     */
    public virtual WorkResults commitWork() {
        try {
            WorkResults wr = new WorkResults();
            wr = commitClean(wr);
            wr = commitDirty(wr);
            return wr;
        } catch(Exception e) {
            Database.rollback(this.sp);
            throw e;
        }
    }
    
    private WorkResults commitClean(WorkResults wr) {
        if(!cleanRecords.isEmpty()) {
            wr.upsertResults.addAll(this.dml.onUpsert(cleanRecords, allOrNone, access));
            this.cleanRecords.clear();
        }
        if(!deletedRecords.isEmpty()) {
            wr.deleteResults.addall(this.dml.onDelete(deletedRecords, allOrNone, access));
            this.deletedRecords.clear();
        }
        if(!undeletedRecords.isEmpty()) {
            wr.undeleteResults.addAll(this.dml.onUndelete(undeletedRecords, allOrNone, access));
            this.undeletedRecords.clear();
        }
        return wr;
    }
    
    private WorkResults commitDirty(WorkResults wr) {
       if(this.dirtyRecords.isEmpty()) {
           return wr;
       }
       List<SObject> records = new List<SObject>();
       for(DirtyRecord dr : this.dirtyRecords) {
       	    records.add(dr.record);
       }
       wr.upsertResults.addAll(this.dml.onUpsert(records, allOrNone, access));
       List<DirtyRecord> childDirtyRecords = new List<DirtyRecord>();
       for(Integer i = 0; i < records.size(); i++) {
            DirtyRecord dirtyParentRecord = this.dirtyRecords[i];
            SObject record = records[i];
           	List<DirtyRecord> connectedChildRecords = connectDirtyChildRecords(dirtyParentRecord, record);
           	childDirtyRecords.addAll(connectedChildRecords);
        }
        this.dirtyRecords = childDirtyRecords;
        return commitDirty(wr);
    }
    
    private List<DirtyRecord> connectDirtyChildRecords(DirtyRecord dirtyParentRecord, SObject newRecord) {
        List<DirtyRecord> dirtyChildRecords = dirtyParentRecord.children;
        List<DirtyRecord> newDirtyParentRecords = new List<DirtyRecord>();
        for(DirtyRecord childRecord : dirtyChildRecords) {
            childRecord.record.put(childRecord.field, newRecord.Id);
            newDirtyParentRecords.add(childRecord);
        }
        return newDirtyParentRecords;
    }
}