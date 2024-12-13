public class UnitOfWork implements IUnitOfWork {
    List<SObject> cleanRecords = new List<SObject>();
    List<SObject> deletedRecords = new List<SObject>();
    List<SObject> undeletedRecords = new List<SObject>();
    
    List<DirtyRecord> dirtyRecords = new List<DirtyRecord>();
    Boolean allOrNone;
    AccessLevel access;
    
    public UnitOfWork(Boolean allOrNone, AccessLevel access) {
        this.allOrNone = allOrNone;
        this.access = access;
    }
    
    public UnitOfWork() {
        this(true, AccessLevel.USER_MODE);
    }
    
    public void registerClean(SObject record) {
        this.cleanRecords.add(record);
    }
    
    public void registerDelete(SObject record) {
        this.deletedRecords.add(record);
    }
    
    public void registerUndelete(SObject record) {
        this.undeletedRecords.add(record);
    }
    
    public Relationship registerDirty(SObject parentRecord, SObject childRecord, SObjectField field) {
        DirtyRecord dirtyParentRecord = new DirtyRecord(parentRecord);
        this.dirtyRecords.add(dirtyParentRecord);
        return registerDirty(dirtyParentRecord, childRecord, field);
    }
    
    public Relationship registerDirty(DirtyRecord dirtyParentRecord, SObject childRecord, SObjectField field) {
        DirtyRecord dirtyChildRecord = new DirtyRecord(childRecord, field);
        dirtyParentRecord.children.add(dirtyChildRecord);
        Relationship parentChildRel = new Relationship(dirtyParentRecord, dirtyChildRecord);
        return parentChildRel;
    }
    
    public void commitWork() {
        System.SavePoint sp = Database.setSavePoint();
        try {
            commitClean();
            commitDirty();
        } catch(Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }
    
    private void commitClean() {
        if(!cleanRecords.isEmpty()) {
            this.cleanRecords.sort();
            Database.upsert(cleanRecords, allOrNone, access);
            this.cleanRecords.clear();
        }
        if(!deletedRecords.isEmpty()) {
            this.deletedRecords.sort();
            Database.delete(deletedRecords, allOrNone, access);
            this.deletedRecords.clear();
        }
        if(!undeletedRecords.isEmpty()) {
            this.undeletedRecords.sort();
            Database.undelete(undeletedRecords, allOrNone, access);
            this.undeletedRecords.clear();
        }
    }
    
    private void commitDirty() {
       if(this.dirtyRecords.isEmpty()) {
           return;
       }
       List<SObject> records = new List<SObject>();
       for(DirtyRecord dr : this.dirtyRecords) {
       	    records.add(dr.record);
       }
       records.sort();
       Database.upsert(records, allOrNone, access);
       List<DirtyRecord> childDirtyRecords = new List<DirtyRecord>();
       for(Integer i = 0; i < records.size(); i++) {
            DirtyRecord dirtyParentRecord = this.dirtyRecords[i];
            SObject record = records[i];
           	List<DirtyRecord> connectedChildRecords = connectDirtyChildRecords(dirtyParentRecord, record);
           	childDirtyRecords.addAll(connectedChildRecords);
        }
        this.dirtyRecords = childDirtyRecords;
        commitDirty();
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