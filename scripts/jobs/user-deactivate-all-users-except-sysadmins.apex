System.debug('user-deactivate-all-users-except-sysadmins');

Id SysAdminProfileId = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1].Id;
Id CICDUserId = [SELECT Id FROM User WHERE Alias='cinte' LIMIT 1].Id;
Id CommsAutomationID = [SELECT Id FROM User WHERE Alias='cauto' LIMIT 1].Id;

// Select all users that were created in prod that does not have sys admin profile. Test users in sandboxes are created by CICD user.
List<User> UserList = [SELECT Id,Username,IsActive FROM User WHERE UserType='Standard' AND ProfileId !=:SysAdminProfileId AND CreatedById !=:CICDUserId AND Id !=:CICDUserId AND Id !=:CommsAutomationID AND IsActive=true AND (NOT LastName LIKE '%Integration%') LIMIT 100];

system.debug('User Count to process: '+UserList.size());

if(UserList.size()>0){
    for(User i:UserList){
        system.debug('Updating: '+i.Username);
        i.IsActive=false;
    }

    Database.SaveResult[] result = Database.Update(UserList, false);

    for(Database.SaveResult i:result){
        System.debug('result: '+i);
    }
}

UserList = [SELECT Id,Username,IsActive FROM User WHERE UserType='Standard' AND ProfileId !=:SysAdminProfileId AND CreatedById !=:CICDUserId AND Id !=:CICDUserId AND IsActive=true];
system.debug('User Count After Update: '+UserList.size());

System.debug('Complete');