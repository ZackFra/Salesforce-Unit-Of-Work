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
  protected UnitOfWork(
    Boolean allOrNone,
    AccessLevel access,
    IUnitOfWorkDML dml
  ) {
    this.sp = Database.setSavepoint();
    this.dml = dml;
    this.allOrNone = allOrNone;
    this.access = access;
  }

  /**
   * @description Constructor all or none
   * @param allOrNone `Boolean`
   */
  public UnitOfWork(Boolean allOrNone) {
    this(allOrNone, AccessLevel.USER_MODE, new UnitOfWorkDML());
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
  public virtual void registerClean(SObject record) {
    if (record == null) {
      throw new IllegalArgumentException('Record must not be null');
    }
    DirtyRecord cleanRecord = new DirtyRecord(record);
    this.dirtyRecordByRecord.put(record, cleanRecord);
    this.dirtyRecords.add(cleanRecord);
  }

  /**
   * @description Register clean, with an external id field
   * @param record `SObject`
   * @param externalIdField `SObjectField`
   * @exception IllegalArgumentException
   */
  public virtual void registerClean(
    SObject record,
    SObjectField externalIdField
  ) {
    if (record == null) {
      throw new IllegalArgumentException('Record must not be null');
    }
    if (externalIdField == null) {
      throw new IllegalArgumentException('External Id Field must not be null');
    }
    DirtyRecord cleanRecord = new DirtyRecord(record, null, externalIdField);
    this.dirtyRecordByRecord.put(record, cleanRecord);
    this.dirtyRecords.add(cleanRecord);
  }

  /**
   * @description Register a deleted recod
   * @param record `SObject`
   */
  public virtual void registerDelete(SObject record) {
    if (record == null) {
      throw new IllegalArgumentException('Record must not be null');
    } else if (record.Id == null) {
      throw new IllegalArgumentException('Record must have an Id');
    }
    this.deletedRecords.add(record);
  }

  /**
   * @description Register an undeleted recod
   * @param record `SObject`
   */
  public virtual void registerUndelete(SObject record) {
    if (record == null) {
      throw new IllegalArgumentException('Record must not be null');
    } else if (record.Id == null) {
      throw new IllegalArgumentException('Record must have an Id');
    }
    this.undeletedRecords.add(record);
  }

  /**
   * @description Register a dirty upsert (insert / update dependent on a record that does not exist yet)
   * @param parentRecord `SObject`
   * @param childRecord `SObject`
   * @param field `SObjectField`
   * @return  `Relationship`
   */
  public virtual void registerDirty(
    SObject parentRecord,
    SObject childRecord,
    SObjectField field
  ) {
    if (parentRecord == null || childRecord == null || field == null) {
      throw new IllegalArgumentException(
        'Parent record, child record, and field must not be null'
      );
    }

    DirtyRecord dirtyParentRecord = getDirtyParentRecord(parentRecord);
    DirtyRecord dirtyChildRecord = getAndValidateDirtyChildRecord(
      childRecord,
      field
    );

    dirtyParentRecord.children.add(dirtyChildRecord);
    this.dirtyRecordByRecord.put(childRecord, dirtyChildRecord);
  }

  /**
   * @description Commit clean and dirty records, rolling back if an error occurs
   * @return `WorkResults`
   * @throws Any errors
   */
  public virtual WorkResults commitWork() {
    try {
      WorkResults wr = new WorkResults();
      wr = commitUpserts(wr);
      wr = commitDeletesAndUndeletes(wr);
      return wr;
    } catch (Exception e) {
      Database.rollback(this.sp);
      throw e;
    }
  }

  /**
   * @description Reset the savepoint to the current state
   */
  public virtual void resetSavepoint() {
    Database.releaseSavepoint(this.sp);
    this.sp = Database.setSavepoint();
  }

  private WorkResults commitDeletesAndUndeletes(WorkResults wr) {
    if (!deletedRecords.isEmpty()) {
      List<Database.DeleteResult> deleteResults = this.dml.onDelete(
        deletedRecords,
        allOrNone,
        access
      );
      wr.deleteResults.addall(deleteResults);
      this.deletedRecords.clear();
    }
    if (!undeletedRecords.isEmpty()) {
      List<Database.UndeleteResult> undeleteResults = this.dml.onUndelete(
        undeletedRecords,
        allOrNone,
        access
      );
      wr.undeleteResults.addAll(undeleteResults);
      this.undeletedRecords.clear();
    }
    return wr;
  }

  private WorkResults commitUpserts(WorkResults wr) {
    if (this.dirtyRecords.isEmpty()) {
      this.dirtyRecordByRecord.clear();
      return wr;
    }

    TupleMap upsertableRecordsByTuple = new TupleMap();
    for (DirtyRecord dirtyRecord : this.dirtyRecords) {
      upsertableRecordsByTuple = groupRecordByTuple(
        dirtyRecord,
        upsertableRecordsByTuple
      );
    }

    List<Database.UpsertResult> upsertResults = new List<Database.UpsertResult>();
    for (Tuple externalIdKey : upsertableRecordsByTuple.keySet()) {
      upsertResults.addAll(
        upsertRecordsByTuple(externalIdKey, upsertableRecordsByTuple)
      );
    }
    this.dirtyRecords = getNextBatch(upsertResults);
    wr.upsertResults.addAll(upsertResults);

    return commitUpserts(wr);
  }

  private List<Database.UpsertResult> upsertRecordsByTuple(
    Tuple externalIdKey,
    TupleMap upsertableRecordsByTuple
  ) {
    List<SObject> groupedRecords = (List<SObject>) upsertableRecordsByTuple.get(
      externalIdKey
    );
    if (externalIdKey == null) {
      return this.dml.onUpsert(groupedRecords, this.allOrNone, this.access);
    } else {
      SObjectField externalIdField = (SObjectField) externalIdKey.item2;
      return this.dml.onUpsert(
        groupedRecords,
        externalIdField,
        this.allOrNone,
        this.access
      );
    }
  }

  private TupleMap groupRecordByTuple(
    DirtyRecord dirtyRecord,
    TupleMap upsertableRecordsByTuple
  ) {
    Tuple externalIdKey = buildTuple(dirtyRecord);
    if (upsertableRecordsByTuple.containsKey(externalIdKey)) {
      List<SObject> groupedRecords = (List<SObject>) upsertableRecordsByTuple.get(
        externalIdKey
      );
      groupedRecords.add(dirtyRecord.record);
    } else {
      upsertableRecordsByTuple.put(
        externalIdKey,
        new List<SObject>{ dirtyRecord.record }
      );
    }
    return upsertableRecordsByTuple;
  }

  private Tuple buildTuple(DirtyRecord dirtyRecord) {
    Tuple externalIdKey = null;
    if (dirtyRecord.externalIdField != null) {
      externalIdKey = new Tuple(
        dirtyRecord.record.getSObjectType(),
        dirtyRecord.externalIdField
      );
    }
    return externalIdKey;
  }

  private List<DirtyRecord> getNextBatch(
    List<Database.UpsertResult> upsertResults
  ) {
    List<DirtyRecord> childDirtyRecords = new List<DirtyRecord>();

    for (Integer i = 0; i < this.dirtyRecords.size(); i++) {
      DirtyRecord dirtyParentRecord = this.dirtyRecords[i];
      if (!upsertResults[i].isSuccess()) {
        continue;
      }
      List<DirtyRecord> connectedChildRecords = connectDirtyChildRecords(
        dirtyParentRecord
      );
      childDirtyRecords.addAll(connectedChildRecords);
    }
    return childDirtyRecords;
  }

  private List<DirtyRecord> connectDirtyChildRecords(
    DirtyRecord dirtyParentRecord
  ) {
    SObject newRecord = dirtyParentRecord.record;
    List<DirtyRecord> dirtyChildRecords = dirtyParentRecord.children;
    List<DirtyRecord> newDirtyParentRecords = new List<DirtyRecord>();
    for (DirtyRecord childRecord : dirtyChildRecords) {
      childRecord.record.put(childRecord.relatedToField, newRecord.Id);
      newDirtyParentRecords.add(childRecord);
    }
    return newDirtyParentRecords;
  }

  private DirtyRecord getAndValidateDirtyChildRecord(
    SObject childRecord,
    SObjectField field
  ) {
    DirtyRecord dirtyChildRecord = this.dirtyRecordByRecord.get(childRecord);
    if (isRegisteredToParentRecord(dirtyChildRecord)) {
      throw new IllegalArgumentException(
        'Child record is already registered to a parent record'
      );
    }

    if (dirtyChildRecord == null) {
      dirtyChildRecord = new DirtyRecord(childRecord, field);
      this.dirtyRecordByRecord.put(childRecord, dirtyChildRecord);
    } else {
      dirtyChildRecord.relatedToField = field;
      this.dirtyRecords.remove(this.dirtyRecords.indexOf(dirtyChildRecord));
    }
    return dirtyChildRecord;
  }

  private Boolean isRegisteredToParentRecord(DirtyRecord dirtyChildRecord) {
    return (dirtyChildRecord != null &&
    dirtyChildRecord.relatedToField != null);
  }

  private DirtyRecord getDirtyParentRecord(SObject parentRecord) {
    DirtyRecord dirtyParentRecord = this.dirtyRecordByRecord.get(parentRecord);
    if (dirtyParentRecord == null) {
      dirtyParentRecord = new DirtyRecord(parentRecord);
      this.dirtyRecords.add(dirtyParentRecord);
      this.dirtyRecordByRecord.put(parentRecord, dirtyParentRecord);
    }
    return dirtyParentRecord;
  }
}
