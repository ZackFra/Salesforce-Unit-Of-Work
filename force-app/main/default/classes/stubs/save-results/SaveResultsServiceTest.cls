/**
 * @description Test class for the SaveResultsService
 *              NOTE: Undeletes are inconsistent with other methods
 *              For other save results, the errors are returned as an empty list on success, but for undeletes
 *              the errors are "null" on success.
 * @author Zackary Frazier
 * @since 12/15/2024
 */
@isTest
private class SaveResultsServiceTest {
  @isTest
  static void ensureUpsertResultsAreReturnedOnFakeInsert() {
    SaveResultsService saveResultsSvc = new SaveResultsService();
    Account acct = new Account(Name = 'Test Account');
    List<Account> accounts = new List<Account>{ acct };
    Test.startTest();
    List<Database.UpsertResult> results = saveResultsSvc.upsertResults(
      accounts,
      true
    );
    Test.stopTest();

    Assert.areEqual(1, results.size(), 'Should have one result');
    Database.UpsertResult result = results[0];
    Assert.areEqual(acct.Id, result.getId(), 'Should have the same Id');
    Assert.isTrue(result.isSuccess(), 'Should be successful');
    Assert.isTrue(result.getErrors().isEmpty(), 'Should not have errors');
  }

  @isTest
  static void ensureUpsertResultsAreReturnedOnFakeUpdate() {
    SaveResultsService saveResultsSvc = new SaveResultsService();
    Account acct = new Account(
      Id = fflib_IDGenerator.generate(Account.getSObjectType()),
      Name = 'Test Account'
    );
    List<Account> accounts = new List<Account>{ acct };
    Test.startTest();
    List<Database.UpsertResult> results = saveResultsSvc.upsertResults(
      accounts,
      true
    );
    Test.stopTest();

    Assert.areEqual(1, results.size(), 'Should have one result');
    Database.UpsertResult result = results[0];
    Assert.areEqual(acct.Id, result.getId(), 'Should have the same Id');
    Assert.isTrue(result.isSuccess(), 'Should be successful');
    Assert.isTrue(result.getErrors().isEmpty(), 'Should not have errors');
  }

  @isTest
  static void ensureErrorIsReturnedOnFailure() {
    SaveResultsService saveResultsSvc = new SaveResultsService();
    Account acct = new Account(Name = 'Test Account');
    List<Account> accounts = new List<Account>{ acct };
    Test.startTest();
    List<Database.UpsertResult> results = saveResultsSvc.upsertResults(
      accounts,
      false
    );
    Test.stopTest();

    Assert.areEqual(1, results.size(), 'Should have one result');
    Database.UpsertResult result = results[0];
    Assert.areEqual(null, result.getId(), 'Should not have an Id');
    Assert.isFalse(result.isSuccess(), 'Should not be successful');
    Assert.isFalse(result.getErrors().isEmpty(), 'Should have errors');
  }

  @isTest
  static void ensureSuccessOnDelete() {
    Account acct = new Account(
      Id = fflib_IDGenerator.generate(Account.getSObjectType()),
      Name = 'Test Account'
    );
    SaveResultsService saveResultsSvc = new SaveResultsService();
    List<Account> accounts = new List<Account>{ acct };

    Test.startTest();
    List<Database.DeleteResult> results = saveResultsSvc.deleteResults(
      accounts,
      true
    );
    Test.stopTest();

    Assert.areEqual(1, results.size(), 'Should have one result');
    Database.DeleteResult result = results[0];
    Assert.isTrue(result.isSuccess(), 'Should be successful');
    Assert.isTrue(result.getErrors().isEmpty(), 'Should not have errors');
  }

  @isTest
  static void ensureFailuresWorkOnDelete() {
    Account acct = new Account(
      Id = fflib_IDGenerator.generate(Account.getSObjectType()),
      Name = 'Test Account'
    );
    SaveResultsService saveResultsSvc = new SaveResultsService();
    List<Account> accounts = new List<Account>{ acct };

    Test.startTest();
    List<Database.DeleteResult> results = saveResultsSvc.deleteResults(
      accounts,
      false
    );
    Test.stopTest();

    Assert.areEqual(1, results.size(), 'Should have one result');
    Database.DeleteResult result = results[0];
    Assert.isFalse(result.isSuccess(), 'Should not be successful');
    Assert.isFalse(result.getErrors().isEmpty(), 'Should have errors');
  }

  @isTest
  static void ensureSuccessWorksOnUndelete() {
    Account acct = new Account(
      Id = fflib_IDGenerator.generate(Account.getSObjectType()),
      Name = 'Test Account'
    );
    SaveResultsService saveResultsSvc = new SaveResultsService();
    List<Account> accounts = new List<Account>{ acct };

    Test.startTest();
    List<Database.UndeleteResult> results = saveResultsSvc.undeleteResults(
      accounts,
      true
    );
    Test.stopTest();

    Assert.areEqual(1, results.size(), 'Should have one result');
    Database.UndeleteResult result = results[0];
    Assert.isTrue(result.isSuccess(), 'Should be successful');
    Assert.isNull(result.getErrors(), 'Should not have errors');
  }

  @isTest
  static void ensureFailureWorksOnUndelete() {
    Account acct = new Account(
      Id = fflib_IDGenerator.generate(Account.getSObjectType()),
      Name = 'Test Account'
    );
    SaveResultsService saveResultsSvc = new SaveResultsService();
    List<Account> accounts = new List<Account>{ acct };

    Test.startTest();
    List<Database.UndeleteResult> results = saveResultsSvc.undeleteResults(
      accounts,
      false
    );
    Test.stopTest();

    Assert.areEqual(1, results.size(), 'Should have one result');
    Database.UndeleteResult result = results[0];
    Assert.isFalse(result.isSuccess(), 'Should not be successful');
    Assert.isFalse(result.getErrors().isEmpty(), 'Should have errors');
  }

  @isTest
  static void ensureIllegalArgumentsAreAccountedFor() {
    SaveResultsService saveResultsSvc = new SaveResultsService();
    Test.startTest();
    try {
      saveResultsSvc.deleteResults(new List<Account>{ new Account() }, true);
      Assert.fail('Should have thrown an exception');
    } catch (IllegalArgumentException e) {
      // Expected
    }

    try {
      saveResultsSvc.undeleteResults(new List<Account>{ new Account() }, true);
      Assert.fail('Should have thrown an exception');
    } catch (IllegalArgumentException e) {
      // Expected
    }
    Test.stopTest();
  }
}
