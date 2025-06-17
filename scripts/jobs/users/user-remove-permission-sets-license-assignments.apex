/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-01-2024
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
System.debug('user-remove-permission-sets-license-assignments.apex');
List<PermissionSetLicenseAssign> PSAList = new List<PermissionSetLicenseAssign>{};
Map<String, String> PermSetMap = new Map<String, String>{{RECORDID_PERMSET_SET}};

for (String permSetKey : PermSetMap.keySet()) {
    String[] permSetArray = permSetKey.split('_');
    if (permSetArray.size() >= 2) {
        PSAList.add(new PermissionSetLicenseAssign(Id = permSetArray[0]));
    }
}

try {
    Database.delete(PSAList, false);
} catch (Exception e) {
    System.debug('Error deleting PermissionSetLicenseAssign: ' + e.getMessage());
}


System.debug('Operation Complete');
