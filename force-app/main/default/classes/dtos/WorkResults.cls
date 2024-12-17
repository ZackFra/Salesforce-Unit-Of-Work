/**
 * @description Wrapper for the results of committing work
 * @author Zackary Frazier
 * @since 12/13/2024
 */
public with sharing class WorkResults {
  public List<Database.UpsertResult> upsertResults = new List<Database.UpsertResult>();
  public List<Database.DeleteResult> deleteResults = new List<Database.DeleteResult>();
  public List<Database.UndeleteResult> undeleteResults = new List<Database.UndeleteResult>();
}
