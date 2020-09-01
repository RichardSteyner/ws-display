global class NetsuiteGetContactsBatch implements Database.Batchable<String>, Database.Stateful, Database.AllowsCallouts {

    public String startDate;   
    
    global NetsuiteGetContactsBatch(String startDate){
        this.startDate = startDate;
    }
    
    global List<String> start(Database.BatchableContext BC){
        List<String> nsIds = new List<String>(); 
        try{
        	NetsuiteGetIds getContacts = new NetsuiteGetIds('contact');
			List<String> auxList = getContacts.getUpdatedIds(startDate);
            nsIds.addAll(auxList);
        }catch(Exception e){
            System.debug('NetsuiteGetContactsBatch Error Start: ' + e.getLineNumber() + '--' + e.getMessage());
        }
        return nsIds;
    }
    
    global void execute(Database.BatchableContext BC, List<String> scope){
        NetsuiteContactParser nsContact;
        String jsonResponse;
        Contact objContact;
        Account objAccount;
        Map<String, Contact> contacts = new Map<String, Contact>();
        Map<String, Id> companyAccounts = new Map<String, Id>();
        Map<String, Account> entityAccounts = new Map<String, Account>();
        Map<String, Id> userIds = new Map<String, Id>();
    	for(String auxId : scope){
            System.debug(auxId);
        	try{
                jsonResponse = NetsuiteConnection.getNetsuiteObject('contact/' + auxId, '');
                if(jsonResponse!=null){
                    nsContact = (NetsuiteContactParser) json.deserialize(jsonResponse, NetsuiteContactParser.class);
                    System.debug('-----------CONTACT------------');
                    System.debug(nsContact);
                    System.debug('-----------CONTACT------------');
                    
                    objContact = new Contact(NS_ID__c=auxId, Company_Id__c=nsContact.getCompanyId(), FirstName=nsContact.firstName, LastName=nsContact.getLastName(),
                                             Phone=nsContact.phone, Email=nsContact.email, Inactive__c=nsContact.isinactive,
                                             Global_Subscription_Status__c=ApexUtil.globalSubscriptionStatusContact.get(nsContact.globalsubscriptionstatus));
                    
                    if(nsContact.getCompanyId()!=null){
                        companyAccounts.put(nsContact.getCompanyId(), null);
                        contacts.put(auxId, objContact);
                    }else if(nsContact.entityId!=null && String.isNotBlank(nsContact.entityId)){
                        objAccount = new Account(Entity_NS_ID__c=nsContact.entityId.trim().toUpperCase(), Name=nsContact.entityId);
                        objContact.Entity_Id__c=nsContact.entityId.trim().toUpperCase();
                        entityAccounts.put(nsContact.entityId.trim().toUpperCase(), objAccount);
                        contacts.put(auxId, objContact);
                    }
                    
                    if(nsContact.owner!=null){
                       objContact.Owner_NS_ID__c=String.valueOf(nsContact.owner); 
                       userIds.put(String.valueOf(nsContact.owner), null);
                    }
                } else 
                    System.debug('NetsuiteGetContactsBatch -> Response null or responseCode not 200.!');
           	}catch(Exception e){
            	System.debug('NetsuiteGetContactsBatch Error Execute: ' + e.getLineNumber() + '--' + e.getMessage());
        	}
        }
        
        ApexUtil.isAccountTriggerInvoked = false;
        List<Database.UpsertResult> upsertResults;
        upsertResults = Database.upsert(entityAccounts.values(), Account.Entity_NS_ID__c, false);
        for(Database.UpsertResult upsertResult:upsertResults) {
            if(!upsertResult.isSuccess()) {
                for(Database.Error upsertError : upsertResult.getErrors()) 
                    System.debug('NetsuiteGetContactsBatch - Entity Upsert Error: ' + upsertError.getMessage());
            }
        }
        
        for(User u : [select Id, NS_ID__c from User where NS_ID__c in: userIds.keySet()])
            userIds.put(u.NS_ID__c, u.Id);
        
        for(Account a : [select Id, NS_ID__c from Account where NS_ID__c in: companyAccounts.keySet()])
            companyAccounts.put(a.NS_ID__c, a.Id);
                
		for(Contact c : contacts.values()){
			if(c.Company_Id__c!=null)
            {
            	if(companyAccounts.get(c.Company_Id__c)!=null) 
                	c.AccountId=companyAccounts.get(c.Company_Id__c);
                else
                    System.debug('Cannot relate to company: ' + c.Company_Id__c);
            }else if(c.Entity_Id__c!=null){
                if(entityAccounts.get(c.Entity_Id__c)!=null && entityAccounts.get(c.Entity_Id__c).Id!=null) 
                	c.AccountId=entityAccounts.get(c.Entity_Id__c).Id;
                else
                    System.debug('Cannot relate to entity: ' + c.Entity_Id__c);
            }
            
            if(c.Owner_NS_ID__c!=null){
                if(userIds.get(c.Owner_NS_ID__c)!=null) 
                	c.OwnerId=userIds.get(c.Owner_NS_ID__c);
                else
                    System.debug('Contact->Cannot relate to Owner: ' + c.Owner_NS_ID__c);
            }
        }
        
		ApexUtil.isContactTriggerInvoked = false;        
       	upsertResults = Database.upsert(contacts.values(), Contact.NS_ID__c, false);
        for(Database.UpsertResult upsertResult:upsertResults){
        	if(!upsertResult.isSuccess()) {
            	for(Database.Error upsertError : upsertResult.getErrors()) 
                	System.debug('NetsuiteGetContactsBatch - Contact Upsert Error: ' + upsertError.getMessage());
            }
     	}
    }
    
    global void finish(Database.BatchableContext BC){
        System.debug('Finish NetsuiteGetContactsBatch');
        if(!Test.isRunningTest()){
        }
    }
    
}