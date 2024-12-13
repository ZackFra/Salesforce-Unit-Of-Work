public interface IUnitOfWorkDML {
    List<Database.UpsertResult> onUpsert(List<SObject> records, Boolean allOrNone, AccessLevel access);
    List<Database.DeleteResult> onDelete(List<SObject> records, Boolean allOrNone, AccessLevel access);
    List<Database.UndeleteResult> onUndelete(List<SObject> records, Boolean allOrNone, AccessLevel access);
}