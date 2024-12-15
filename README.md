# Unit Of Work

Implemented as a standalone unit of work, based on the Apex Common Library's implementation. A unit of work is a utility to encapsulate DML operations to ensure CRUD operations are atomic, and are executed as efficiently as possible.

# Apex Classes

## UnitOfWork
This Apex class allows you to encapsulate CRUD operations. It can be passed down to multiple methods from a controller or trigger handler, and register all operations, to be executed later. Upon instantiation, a savepoint is created, which is used to rollback the DML operations if any errors occur.

Ex.

```

// savepoint created here on instantiation
IUnitOfWork uow = new UnitOfWork();

// parent account
Account acct1 = new Account(Name = 'Account 1');

// child accounts
Account acct2 = new Account(Name = 'Account 2');
Account acct3 = new Account(Name = 'Account 3');
Account acct4 = new Account(Name = 'Account 4');

// register dirty, allows these to be inserted in the correct order
uow.registerDirty(acct1, acct2, Account.ParentId);
uow.registerDirty(acct1, acct3, Account.ParentId);
uow.registerDirty(acct1, acct4, Account.ParentId);

// commit step, rolls back on failure
uow.commitWork();
```

### Methods

#### void registerClean(SObject record)
Cleanly register a record for upsert.

#### void registerDelete(SObject record)
Cleanly register a record for deletion.

#### void registerUndelete(SObject record)
Cleanly register a record for undeletion.

#### void registerDirty(SObject parentRecord, SObject childRecord, SObjectField field)
Register records such that the parent record will be upserted first, then the child record, connected to the parent record via the id field passed in. 

You can use the same parent record multiple times, this unit of work will remember which records have already been registered. Further, you can use a registered child record as a new parent record. 

The parent record may be a record that was previously registered via registerClean however it is not required to call registerClean to register the parent. It will be registered by registerDirty if it has not yet been registered.

#### WorkResults commitWork()
Commits all registered upserts, deletes, and undeletes to the database. Will rollback to the last savepoint on exception. Will re-throw the exception post-rollback. In an ideal world, this savepoint the one created when the UoW was created, but I understand that there are strange scenarios.

Can be called multiple times. Upon commit, all enqueued records will be cleared so the next commit can be done cleanly.

#### void resetSavepoint()
Release the previously created savepoint and create a new one at the current point in execution.

## WorkResults
Wrapper for the results of a commit. Has three properties
* List\<Database.UpsertResult\> upsertResults
* List\<Database.DeleteResult\> deleteResults
* List\<Database.UndeleteResult\> undeleteResults

# Extending and Stubbing

There is two interfaces and two stub classes that support extending this: 
## IUnitOfWork
Interface for the unit of work.

## IUnitOfWorkDML
Interface to encapsulate DML operations performed by the UnitOfWork.

## StubbedUnitOfWork
Allows for unit testing. Replaces the DML operations performed in the UnitOfWork with stubbed DML interactions that return lists of appropate save results. 

* Calling the `shouldFail()` method will cause this to respond negatively.
  * If allOrNone is set to true, throws a fake DML exception.
  * If allOrNone is set to false, returns appropriate failed save results.
* Otherwise has all the same methods as the UnitOfWork class

## StubbedUnitOfWorkDML
Used to stub DML interactions. Produces approprate save results for the commitWork method based on whether the DML operation is meant to be a success or failure, and also on upsert, sets created based on whether the upserted record has an id or not.

NOTE: though it does support allOrNone being true or false, when allOrNone is false and success is false, it asumes the entire transaction failed and all save results are treated as failures when produced.

# Notes

When testing, if you create the UnitOfWork before calling `Test.startTest()`, it will cause issues with the savepoint in the case of rollbacks. To avoid this issue, ensure that the UnitOfWork is instantiated after calling `Test.startTest()` and before calling `Test.stopTest()`.