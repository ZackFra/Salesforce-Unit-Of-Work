/**
 *
 * @author Zackary Frazier
 * @since 12/13/2024
 * @description Represents a record enqueued to update sequentially
 */
public class DirtyRecord {
  public SObject record;
  public SObjectField field;
  public List<DirtyRecord> children = new List<DirtyRecord>();

  /**
   * @description Constructor for a dirty child record
   * @param record `SObject`
   * @param field `SObjectField`
   */
  public DirtyRecord(SObject record, SObjectField field) {
    this.record = record;
    this.field = field;
  }

  /**
   * @description Constructor for a dirty parent record
   * @param record `SObject`
   */
  public DirtyRecord(SObject record) {
    this.record = record;
  }
}
