
System.debug('user-remove-groups.apex');
List<GroupMember> GroupMemberList = new List<GroupMember>{};
Map<String, String> GroupMemberSetMap = new Map<String, String>{{RECORDID_GROUP}};

for (String groupMemberKey : GroupMemberSetMap.keySet()) {
    String[] groupSetArray = groupMemberKey.split('_');
    if (groupSetArray.size() >= 2) {
        GroupMemberList.add(new GroupMember(Id = groupSetArray[0]));
    }
}

try {
    Database.delete(GroupMemberList, false);
} catch (Exception e) {
    System.debug('Error deleting GroupMembers: ' + e.getMessage());
}

System.debug('Operation Complete');
