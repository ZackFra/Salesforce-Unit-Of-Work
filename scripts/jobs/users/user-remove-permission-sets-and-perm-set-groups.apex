System.debug('user-remove-permission-sets-and-perm-set-groups.apex');
List<PermissionSetAssignment> PSAList = new List<PermissionSetAssignment>{};
Map<String, String> PermSetMap = new Map<String, String>{{RECORDID_PERMSET_SET}};

for (String permSetKey : PermSetMap.keySet()) {
    String[] permSetArray = permSetKey.split('_');
    if (permSetArray.size() >= 2) {
        PSAList.add(new PermissionSetAssignment(Id = permSetArray[0]));
    }
}

try {
    Database.delete(PSAList, false);
} catch (Exception e) {
    System.debug('Error deleting PermissionSetAssignments: ' + e.getMessage());
}


System.debug('Operation Complete');
