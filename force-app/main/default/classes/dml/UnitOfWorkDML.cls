/**
 * @description UnitOfWorkDML class, handles DML for the UnitOfWork 
 * @author Zackary Frazier
 * @since 12/13/2024
 */
public without sharing class UnitOfWorkDML implements IUnitOfWorkDML {
    /**
     * @description Handles upserts
     * @param records `List<SObject>`
     * @param allOrNone `Boolean`
     * @param access `AccessLevel`
     * @return  `List<Database.UpsertResult>`
     */
    public List<Database.UpsertResult> onUpsert(List<SObject> records, Boolean allOrNone, AccessLevel access) {
        records.sort();
        return Database.upsert(records, allOrNone, access);
    }
    
    /**
     * @description Handles delete
     * @param records `List<SObject>`
     * @param allOrNone `Boolean`
     * @param access `AccessLevel`
     * @return  `List<Database.DeleteResult>`
     */
    public List<Database.DeleteResult> onDelete(List<SObject> records, Boolean allOrNone, AccessLevel access) {
        records.sort();
        return Database.delete(records, allOrNone, access);
    }

    /**
     * @description Handles undelete
     * @param records `List<SObject>`
     * @param allOrNone `Boolean`
     * @param access `AccessLevel`
     * @return  `List<Database.UndeleteResult>`
     */
    public List<Database.UndeleteResult> onUndelete(List<SObject> records, Boolean allOrNone, AccessLevel access) {
        records.sort();
        return Database.undelete(records, allOrNone, access);
    }
}