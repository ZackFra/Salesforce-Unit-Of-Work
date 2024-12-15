@IsTest
private class UnitOfWorkTest {
	@IsTest
    static void ensureCleanInsertIsSuccessful() {
        Account acct = new Account(
        	Name = 'Test Account'
        );
        UnitOfWork uow = new UnitOfWork();
        
        uow.registerClean(acct);
        
        Test.startTest();
        uow.commitWork();
        Test.stopTest();

        Integer numberOfAccounts = [
            SELECT COUNT()
            FROM Account
            WHERE Name = 'Test Account'
        ];

        Assert.areEqual(1, numberOfAccounts, 'Expected account to be created');
        
    }
    
    @IsTest
    static void ensureCleanUpdateIsSuccessful() {
        Account acct = new Account(
        	Name = 'Test Account'
        );
        
        insert acct;
        
        acct.AccountNumber = '12345';
        
        UnitOfWork uow = new UnitOfWork(false, AccessLevel.USER_MODE);
        
        Test.startTest();
        uow.commitWork();
        Test.stopTest();
        
        Integer numberOfAccounts = [
            SELECT COUNT()
            FROM Account
        ];
        
        Assert.areEqual(1, numberOfAccounts, 'Expected only one account');
    }
    
    @IsTest
    static void ensureDirtyUpdateIsSuccessful() {
        Account acct = new Account(Name = 'Test Account');
        Contact con = new Contact(FirstName = 'Simon', LastName = 'Bolivar', Email = 'sbolivar@colombia.com');
        UnitOfWork uow = new UnitOfWork();
        uow.registerDirty(acct, con, Contact.AccountId);
        Test.startTest();
        uow.commitWork();
        Test.stopTest();

        Contact updatedContact = [SELECT AccountId FROM Contact];
        Assert.isNotNull(updatedContact.AccountId, 'Expected AccountId to be set');
    }
    
    @IsTest
    static void ensureDirtyUpdateLayersDeepIsSuccessful() {
        UnitOfWork uow = new UnitOfWork();
        Account acct1 = new Account(Name = 'Test Account 1');
        Account acct2 = new Account(Name = 'Test Account 2');
        Account acct3 = new Account(Name = 'Test Account 3');
        Account acct4 = new Account(Name = 'Test Account 4');
        Account acct5 = new Account(Name = 'Test Account 5');
        
        uow.registerDirty(acct1, acct2, Account.ParentId);
       	uow.registerDirty(acct2, acct3, Account.ParentId);
        uow.registerDirty(acct3, acct4, Account.ParentId);
        uow.registerDirty(acct4, acct5, Account.ParentId);
        
        Test.startTest();
        uow.commitWork();
        Test.stopTest();
        Account acct = [
            SELECT Name, (
            	SELECT Name, (
                	SELECT Name, (
                    	SELECT Name, (
                        	SELECT Name
                            FROM ChildAccounts
                        ) FROM ChildAccounts
                    ) FROM ChildAccounts
                ) FROM ChildAccounts
            )
            FROM Account
            WHERE Name = 'Test Account 1'
        ];
        
        Account examine = acct;
        Assert.areEqual('Test Account 1', examine.Name, 'Expected name to match');
        examine = examine.ChildAccounts[0];
        Assert.areEqual('Test Account 2', examine.Name, 'Expected name to match');
        examine = examine.ChildAccounts[0];
        Assert.areEqual('Test Account 3', examine.Name, 'Expected name to match');
        examine = examine.ChildAccounts[0];
        Assert.areEqual('Test Account 4', examine.Name, 'Expected name to match');
        examine = examine.ChildAccounts[0];
        Assert.areEqual('Test Account 5', examine.Name, 'Expected name to match');
    }
    
    @IsTest
    static void ensureCorrectNumberOfDmlFires() {
        Account acct01 = new Account(Name='Test Account 01');
        Account acct11 = new Account(Name='Test Account 11');
        Account acct21 = new Account(Name='Test Account 21');
        
        Account acct02 = new Account(Name='Test Account 02');
        Account acct12 = new Account(Name='Test Account 12');
        Account acct22 = new Account (Name='Test Account 22');
        
        UnitOfWork uow = new UnitOfWork();
        uow.registerDirty(acct01, acct02, Account.ParentId);
        uow.registerDirty(acct11, acct12, Account.ParentId);
        uow.registerDirty(acct21, acct22, Account.ParentId);
        
        Test.startTest();
        uow.commitWork();
        Integer dmlLimits = Limits.getDmlStatements();
        Test.stopTest();
        Assert.areEqual(2, dmlLimits, 'Expected only one DML statements');
    }
    
    @IsTest
    static void ensureAllCleanRegistryMethodsSucceed() {
        UnitOfWork uow = new UnitOfWork();
        Account acct1 = new Account(Name = 'Test Account 1');
        insert acct1;
        delete acct1;
        uow.registerUndelete(acct1);
        Account acct2 = new Account(Name = 'Test Account 2');
        insert acct2;
        uow.registerDelete(acct2);
        Account acct3 = new Account(Name = 'Test Account 3');
        uow.registerClean(acct3);
        
        Test.startTest();
        uow.commitWork();
        Test.stopTest();
        
        Integer numberOfAccounts = [
            SELECT COUNT()
            FROM Account
        ];
        Assert.areEqual(2, numberOfAccounts, 'Expected two accounts');
        
    }

    @IsTest
    static void ensureHalfwayErrorTriggersFullRollback() {
        UnitOfWork uow = new UnitOfWork();

        Account acct = new Account(Name = 'Test Account 1');
        uow.registerClean(acct);
        uow.commitWork();

        acct.Name = 'Test Account 2';
        Account acct2 = acct.clone(true);
        acct2.Name = 'Test Account 3';

        uow.registerClean(acct);
        uow.registerClean(acct2);

        Boolean isExceptionThrown = false;
        // cannot use Test.startTest and Test.stopTest,
        // it'll reset the savepoint here
        try {
            uow.commitWork();
        } catch(Exception e) {
            isExceptionThrown = true;
        }

        Assert.isTrue(isExceptionThrown, 'Expected exception to be thrown');

        Integer numberOfAccounts = [
            SELECT COUNT()
            FROM Account
        ];

        Assert.areEqual(0, numberOfAccounts, 'Expected full rollback');
    }
}