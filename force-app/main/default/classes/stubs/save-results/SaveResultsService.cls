/**
 * @description This class is responsible for generating mock success results for DML operations 
 * @author Zackary Frazier
 * @since 12/13/2024
 */
@IsTest
public with sharing class SaveResultsService {

    /**
     * @description Generate mock success results for upsert operations
     * @param records `List<SObject>`
     * @return  `List<Database.UpsertResult>`
     */
    public List<Database.UpsertResult> upsertResults(List<SObject> records) {
        List<Database.UpsertResult> results = new List<Database.UpsertResult>();
        for(SObject record : records) {
            DatabaseUpsertResult mockedResult;
            if(record.Id != null) {
                mockedResult = new DatabaseUpsertResult(record.Id);
            } else {
                Id fakeId = fflib_IdGenerator.generate(record.getSObjectType());
                record.Id = fakeId;
                mockedResult = new DatabaseUpsertResult(fakeId, true);
            }

            Database.UpsertResult result = (Database.UpsertResult) JSON.deserialize(JSON.serialize(mockedResult), Database.UpsertResult.class);
            results.add(result);
        }
        return results;
    }

    /**
     * @description Generate mock success results for delete operations
     * @param records `List<SObject>`
     * @return  `List<Database.DeleteResult>`
     * @exception 
     */
    public List<Database.DeleteResult> deleteResults(List<SObject> records) {
        List<Database.DeleteResult> results = new List<Database.DeleteResult>();
        for(SObject record : records) {
            if(record.Id == null) {
                throw new IllegalArgumentException('Record must have an Id');
            }
            DatabaseDeleteResult mockedResult = new DatabaseDeleteResult(record.Id);
            Database.DeleteResult result = (Database.DeleteResult) JSON.deserialize(JSON.serialize(mockedResult), Database.DeleteResult.class);
            results.add(result);
        }
        return results;
    }

    /**
     * @description Generate mock success results for undelete operations
     * @param records `List<SObject>`
     * @return  `List<Database.UndeleteResult>`
     * @exception 
     */
    public List<Database.UndeleteResult> undeleteResults(List<SObject> records) {
        List<Database.UndeleteResult> results = new List<Database.UndeleteResult>();
        for(SObject record : records) {
            if(record.Id == null) {
                throw new IllegalArgumentException('Record must have an Id');
            }
            DatabaseUndeleteResult mockedResult = new DatabaseUndeleteResult(record.Id);
            Database.UndeleteResult result = (Database.UndeleteResult) JSON.deserialize(JSON.serialize(mockedResult), Database.UndeleteResult.class);
            results.add(result);
        }
        return results;
    }

    private class DatabaseUndeleteResult {
        public Id id;
        public Boolean success;
        public List<Database.Error> errors;

        /**
         * @description Constructor for DatabaseUndeleteResult
         * @param recordId `Id`
         */
        public DatabaseUndeleteResult(Id recordId) {
            this.id = recordId;
            this.success = true;
            this.errors = new List<Database.Error>();
        }
    }

    private class DatabaseDeleteResult {
        public Id id;
        public Boolean success;
        public List<Database.Error> errors;

        /**
         * @description Constructor for DatabaseDeleteResult
         * @param recordId `Id`
         */
        public DatabaseDeleteResult(Id recordId) {
            this.id = recordId;
            this.success = true;
            this.errors = new List<Database.Error>();
        }
    }

    private class DatabaseUpsertResult {
        public Id id;
        public Boolean success;
        public Boolean created;
        public List<Database.Error> errors;

        /**
         * @description Constructor for DatabaseUpsertResult
         * @param recordId `Id`
         */
        public DatabaseUpsertResult(Id recordId) {
            this.id = recordId;
            this.success = true;
            this.created = false;
            this.errors = new List<Database.Error>();
        }

        /**
         * @description Constructor  DatabaseUpsertResult 
         * @param sot `SObjectType`
         */
        public DatabaseUpsertResult(Id recordId, Boolean created) {
            this(recordId);
            this.created = created;
        }
    }
}