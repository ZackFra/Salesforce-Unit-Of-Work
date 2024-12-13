/**
 * @description Interface for DML done in the unit of work 
 * @author Zackary Frazier
 * @since 12/13/2024
 */
public interface IUnitOfWorkDML {
    /**
     * @description handle upsert
     * @param records `List<SObject>`
     * @param allOrNone `Boolean`
     * @param access `AccessLevel`
     * @return  `List<Database.UpsertResult>`
     */
    List<Database.UpsertResult> onUpsert(List<SObject> records, Boolean allOrNone, AccessLevel access);
    /**
     * @description handle delete
     * @param records `List<SObject>`
     * @param allOrNone `Boolean`
     * @param access `AccessLevel`
     * @return  `List<Database.DeleteResult>`
     */
    List<Database.DeleteResult> onDelete(List<SObject> records, Boolean allOrNone, AccessLevel access);
    /**
     * @description handle undelete
     * @param records `List<SObject>`
     * @param allOrNone `Boolean`
     * @param access `AccessLevel`
     * @return  `List<Database.UndeleteResult>`
     */
    List<Database.UndeleteResult> onUndelete(List<SObject> records, Boolean allOrNone, AccessLevel access);
}