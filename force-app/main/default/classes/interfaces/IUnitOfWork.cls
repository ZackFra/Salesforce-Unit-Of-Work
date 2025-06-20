/**
 * @description UnitOfWork interface
 * @author Zackary Frazier
 * @since 12/13/2024
 */
@namespaceAccessible
public interface IUnitOfWork {
  /**
   * @description Registers a record to be inserted or updated
   * @param record `SObject`
   */
  void registerClean(SObject record);
  /**
   * @description Register clean with external id field
   * @param record `SObject`
   * @param externalIdField `SObjectField`
   */
  void registerClean(SObject record, SObjectField externalIdField);
  /**
   * @description Registers a record to be deleted
   * @param record `SObject`
   */
  void registerDelete(SObject record);
  /**
   * @description Registers a record to be undeleted
   * @param record `SObject`
   */
  void registerUndelete(SObject record);
  /**
   * @description Registers a record to be inserted or updated
   * @param parentRecord `SObject`
   * @param childRecord `SObject`
   * @param field `SObjectField`
   * @return  `Relationship`
   */
  void registerDirty(
    SObject parentRecord,
    SObject childRecord,
    SObjectField field
  );
  /**
   * @description Commits all work to the database, returns the results
   * @return  `WorkResults`
   */
  WorkResults commitWork();
  /**
   * @description Reset the savepoint
   */
  void resetSavepoint();
}
