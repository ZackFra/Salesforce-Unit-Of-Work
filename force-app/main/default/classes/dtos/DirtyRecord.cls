/**
 *
 * @author Zackary Frazier
 * @since 12/13/2024
 * @description Represents a record enqueued to update sequentially
 */
public class DirtyRecord {
  public SObject record;
  public SObjectField relatedToField;
  public SObjectField externalIdField;
  public List<DirtyRecord> children = new List<DirtyRecord>();

  /**
   * @description Constructor for a dirty child record
   * @param record `SObject`
   * @param field `SObjectField`
   */
  public DirtyRecord(
    SObject record,
    SObjectField relatedToField,
    SObjectField externalIdField
  ) {
    this.record = record;
    this.relatedToField = relatedToField;
    this.externalIdField = externalIdField;
  }

  public DirtyRecord(SObject record, SObjectField relatedToField) {
    this(record, relatedToField, null);
  }

  /**
   * @description Constructor for a dirty parent record
   * @param record `SObject`
   */
  public DirtyRecord(SObject record) {
    this(record, null);
  }
}
