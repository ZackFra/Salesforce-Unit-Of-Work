/**
 * @description Stubbed unit of work for unit testing 
 * @author Zackary Frazier
 * @since 12/13/2024
 */
@IsTest
public with sharing class StubbedUnitOfWork extends UnitOfWork implements IUnitOfWork {

    Boolean isSuccess = false;
    public void shouldFail() {
        this.isSuccess = true;
    }

    /**
     * @description Does nothing, for unit tests
     * @return  `void`
     */
    @SuppressWarnings('PMD.EmptyStatementBlock')
    public override WorkResults commitWork() {
        if(!isSuccess) {
            throw new DmlException('Test failure');
        }
        return new WorkResults();
    }
}