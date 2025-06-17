/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-05-2024
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
System.debug('user-reset-passwords.apex');
List<Id> RecordIdsList = new List<Id>{{RECORDID_LIST}};

for (Id recordId : RecordIdsList) {
    try {
        System.resetPassword(recordId, true);   
    } catch (Exception e) {
        System.debug('Error resetting password for ' + recordId + ' with Error: ' + e.getMessage());
    }
}
System.debug('Operation Complete');
