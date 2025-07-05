/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class UnitOfWorkManagerTest {

    private class TestUnitOfWork extends UnitOfWork {
        public Boolean committed = false;

        public TestUnitOfWork(Boolean allOrNone, AccessLevel accessLevel) {
            super(allOrNone, accessLevel);
        }

        public override WorkResults commitWork() {
            WorkResults wr = new WorkResults();
            this.committed = true;
            return wr;
        }
    }

    @testSetup
    static void setupMockUoWRegistry() {
        // Bypass actual registry by inserting directly with test unit of works
        UnitOfWorkManager.Config cfg1 = new UnitOfWorkManager.Config(true, AccessLevel.USER_MODE);
        UnitOfWorkManager.Config cfg2 = new UnitOfWorkManager.Config(false, AccessLevel.SYSTEM_MODE);

        TestUnitOfWork uow1 = new TestUnitOfWork(true, AccessLevel.USER_MODE);
        TestUnitOfWork uow2 = new TestUnitOfWork(false, AccessLevel.SYSTEM_MODE);

        UnitOfWorkManager.uowRegistry = new Map<UnitOfWorkManager.Config, UnitOfWork>{
            cfg1 => uow1,
            cfg2 => uow2
        };
    }

    @isTest
    static void test_getUnitOfWork_overloads() {
        // Exercise all overloaded methods
        UnitOfWork uow1 = UnitOfWorkManager.getUnitOfWork();
        System.assertNotEquals(null, uow1);

        UnitOfWork uow2 = UnitOfWorkManager.getUnitOfWork(true, AccessLevel.SYSTEM_MODE);
        System.assertNotEquals(null, uow2);

        UnitOfWork uow3 = UnitOfWorkManager.getUnitOfWork(false);
        System.assertNotEquals(null, uow3);

        UnitOfWork uow4 = UnitOfWorkManager.getUnitOfWork(AccessLevel.USER_MODE);
        System.assertNotEquals(null, uow4);
    }

    @isTest
    static void test_commitWork() {
        // Use the mock UnitOfWork with a flag
        UnitOfWorkManager.Config cfgTrue = new UnitOfWorkManager.Config(true, AccessLevel.USER_MODE);
        UnitOfWorkManager.Config cfgFalse = new UnitOfWorkManager.Config(false, AccessLevel.SYSTEM_MODE);

        TestUnitOfWork uowTrue = new TestUnitOfWork(true, AccessLevel.USER_MODE);
        TestUnitOfWork uowFalse = new TestUnitOfWork(false, AccessLevel.SYSTEM_MODE);

        Map<UnitOfWorkManager.Config, UnitOfWork> registry = new Map<UnitOfWorkManager.Config, UnitOfWork>{
            cfgTrue => uowTrue,
            cfgFalse => uowFalse
        };

        UnitOfWorkManager.uowRegistry = registry;

        UnitOfWorkManager.commitWork();

        System.assert(((TestUnitOfWork)registry.get(cfgTrue)).committed, 'True config UoW should be committed');
        System.assert(((TestUnitOfWork)registry.get(cfgFalse)).committed, 'False config UoW should be committed');
    }

    @isTest
    static void test_configEqualityAndHashing() {
        UnitOfWorkManager.Config cfg1 = new UnitOfWorkManager.Config(true, AccessLevel.USER_MODE);
        UnitOfWorkManager.Config cfg2 = new UnitOfWorkManager.Config(true, AccessLevel.USER_MODE);
        UnitOfWorkManager.Config cfg3 = new UnitOfWorkManager.Config(false, AccessLevel.SYSTEM_MODE);

        System.assertEquals(cfg1, cfg2, 'Configs with same values should be equal');
        System.assertNotEquals(cfg1, cfg3, 'Configs with different values should not be equal');

        Set<UnitOfWorkManager.Config> setCfg = new Set<UnitOfWorkManager.Config>();
        setCfg.add(cfg1);
        setCfg.add(cfg2); // Should not be added again
        setCfg.add(cfg3);

        System.assertEquals(2, setCfg.size(), 'Set should eliminate duplicate config based on hashCode');
    }

    @isTest
    static void test_commitWork_emptyRegistry() {
        // Ensure empty registry case is covered
        UnitOfWorkManager.uowRegistry = new Map<UnitOfWorkManager.Config, UnitOfWork>();
        UnitOfWorkManager.commitWork(); // Should not throw
    }
}
