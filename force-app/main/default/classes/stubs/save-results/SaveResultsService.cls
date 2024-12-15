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
    public List<Database.UpsertResult> upsertResults(List<SObject> records, Boolean success) {
        List<Database.UpsertResult> results = new List<Database.UpsertResult>();
        for(SObject record : records) {
            SObjectType sot = record.getSObjectType();
            DatabaseUpsertResult mockedResult = new DatabaseUpsertResult(sot, record.Id, success);
            Database.UpsertResult result = (Database.UpsertResult) JSON.deserialize(JSON.serialize(mockedResult), Database.UpsertResult.class);
            record.Id = result.getId();
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
    public List<Database.DeleteResult> deleteResults(List<SObject> records, Boolean success) {
        List<Database.DeleteResult> results = new List<Database.DeleteResult>();
        for(SObject record : records) {
            DatabaseDeleteResult mockedResult = new DatabaseDeleteResult(record.Id, success);
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
    public List<Database.UndeleteResult> undeleteResults(List<SObject> records, Boolean success) {
        List<Database.UndeleteResult> results = new List<Database.UndeleteResult>();
        for(SObject record : records) {
            DatabaseUndeleteResult mockedResult = new DatabaseUndeleteResult(record.Id, success);
            Database.UndeleteResult result = (Database.UndeleteResult) JSON.deserialize(JSON.serialize(mockedResult), Database.UndeleteResult.class);
            results.add(result);
        }
        return results;
    }

    private class DatabaseUndeleteResult {
        public Id id;
        public Boolean success;
        public List<DatabaseError> errors;

        /**
         * @description Constructor for DatabaseUndeleteResult
         * @param recordId `Id`
         */
        public DatabaseUndeleteResult(Id recordId, Boolean success) {
            if(recordId == null) {
                throw new IllegalArgumentException('Record must have an Id');
            }
            this.id = recordId;
            this.success = success;
            if(success) {
                onSuccess();
            } else {
                onFailure();
            }
        }

        private void onSuccess() {
            this.errors = null;
        }

        private void onFailure() {
            this.errors = new List<DatabaseError> {
                new DatabaseError('An error occurred', 'DUPLICATE_VALUE')
            };
        }
    }

    private class DatabaseDeleteResult {
        public Id id;
        public Boolean success;
        public List<DatabaseError> errors;

        /**
         * @description Constructor for DatabaseDeleteResult
         * @param recordId `Id`
         */
        public DatabaseDeleteResult(Id recordId, Boolean success) {
            if(recordId == null) {
                throw new IllegalArgumentException('Record must have an Id');
            }

            this.id = recordId;
            this.success = success;
            if(success) {
                onSuccess();
            } else {
                onFailure();
            }
        }

        private void onSuccess() {
            this.errors = null;           
        }

        private void onFailure() {
            this.errors = new List<DatabaseError> {
                new DatabaseError('An error occurred', 'DUPLICATE_VALUE')
            };
        }
    }

    private class DatabaseUpsertResult {
        public Id id;
        public Boolean success;
        public Boolean created;
        public List<DatabaseError> errors;

        /**
         * @description Constructor for DatabaseUpsertResult
         * @param recordId `Id`
         */
        public DatabaseUpsertResult(SObjectType sot, Id recordId, Boolean success) {
            this.id = recordId;
            this.success = success;
            if(!this.success) {
                onFailure();
            } else {
                onSuccess(sot);
            }
        }

        private void onFailure() {
            this.created = false;
            this.errors = new List<DatabaseError> {
                new DatabaseError('An error occurred', 'DUPLICATE_VALUE')
            };
        }

        private void onSuccess(SObjectType sot) {
            Boolean created = (this.id == null);
            this.created = created;
            this.errors = null;
            if(created) {
                this.id = fflib_IdGenerator.generate(sot);
            }
        }
    }

    private class DatabaseError {
        public String message;
        public String statusCode;

        /**
         * @description Constructor for DatabaseError
         * @param message `String`
         * @param statusCode `String`
         */
        public DatabaseError(String message, String statusCode) {
            this.message = message;
            this.statusCode = statusCode;
        }
    }
}