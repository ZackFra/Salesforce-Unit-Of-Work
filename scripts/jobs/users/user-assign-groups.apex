System.debug('user-assign-groups.apex');
List<GroupMember> PSAList = new List<GroupMember>{};

// USERID_PERMSET_SET= 'USERID_PERMSETID' => 'USERID%PERMSETID', 'USERID_PERMSETID' => 'USERID%PERMSETID', 'USERID_PERMSETID' => 'USERID%PERMSETID'

Map<String, String> SetMap = new Map<String, String>{{GROUP_STRING}};
System.debug('SetMap: '+SetMap);
for (String i: SetMap.keySet()){
    System.debug('i: '+i);
    List<String> SetArry = i.split('_');
    String UserID = SetArry[0];
    String GroupID = SetArry[1];
    GroupMember psa = new GroupMember(
        GroupId = GroupID
        ,UserOrGroupId = UserID
    );
    PSAList.add(psa);
}

Database.SaveResult[] result = Database.Insert(PSAList, false);

for(Database.SaveResult i:result){
    System.debug('result: '+i);
}

System.debug('Complete');