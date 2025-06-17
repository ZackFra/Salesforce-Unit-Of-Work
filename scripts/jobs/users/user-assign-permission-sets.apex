System.debug('user-assign-permission-sets.apex');
List<PermissionSetAssignment> PSAList = new List<PermissionSetAssignment>{};

// USERID_PERMSET_SET= 'USERID_PERMSETID' => 'USERID%PERMSETID', 'USERID_PERMSETID' => 'USERID%PERMSETID', 'USERID_PERMSETID' => 'USERID%PERMSETID'

Map<String, String> PermSetMap = new Map<String, String>{{USERID_PERMSET_SET}};
for (String i: PermSetMap.keySet()){
    List<String> PermSetArry = i.split('_');
    String UserID = PermSetArry[0];
    String PermSetID = PermSetArry[1];
    PermissionSetAssignment psa = new PermissionSetAssignment(
        PermissionSetId = PermSetID
        ,AssigneeId = UserID
    );
    PSAList.add(psa);
}

Database.SaveResult[] result = Database.Insert(PSAList, false);

for(Database.SaveResult i:result){
    System.debug('result: '+i);
}

System.debug('Complete');