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
        
    }
    
    @IsTest
    static void ensureCleanUpdateIsSuccessful() {
        Account acct = new Account(
        	Name = 'Test Account'
        );
        
        insert acct;
        
        acct.AccountNumber = '12345';
        
        UnitOfWork uow = new UnitOfWork();
        
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
    }
    
    @IsTest
    static void ensureDirtyUpdateLayersDeepIsSuccessful() {
        UnitOfWork uow = new UnitOfWork();
        Account acct1 = new Account(Name = 'Test Account 1');
        Account acct2 = new Account(Name = 'Test Account 2');
        Account acct3 = new Account(Name = 'Test Account 3');
        Account acct4 = new Account(Name = 'Test Account 4');
        Account acct5 = new Account(Name = 'Test Account 5');
        
        Relationship rel = uow.registerDirty(acct1, acct2, Account.ParentId);
       	rel = uow.registerDirty(rel.childRecord, acct3, Account.ParentId);
        rel = uow.registerDirty(rel.childRecord, acct4, Account.ParentId);
        rel = uow.registerDirty(rel.childRecord, acct5, Account.ParentId);
        
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
        Assert.areEqual('Test Account 1', examine.Name);
        examine = examine.ChildAccounts[0];
        Assert.areEqual('Test Account 2', examine.Name);
        examine = examine.ChildAccounts[0];
        Assert.areEqual('Test Account 3', examine.Name);
        examine = examine.ChildAccounts[0];
        Assert.areEqual('Test Account 4', examine.Name);
        examine = examine.ChildAccounts[0];
        Assert.areEqual('Test Account 5', examine.Name);
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
        Assert.areEqual(3, dmlLimits);
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
        
        
    }
}