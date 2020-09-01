global class NetsuiteGetSalesOrderBatch implements Database.Batchable<String>, Database.Stateful, Database.AllowsCallouts {

    public String startDate;   
    public Set<String> auxAccountIds;
    
    global NetsuiteGetSalesOrderBatch(String startDate){
        this.startDate = startDate;
        auxAccountIds = new Set<String>();
    }
    
    global List<String> start(Database.BatchableContext BC){
        List<String> nsIds = new List<String>(); 
        try{
            NetsuiteGetIds getSales = new NetsuiteGetIds('salesorder');
			List<String> auxList = getSales.getUpdatedIds(startDate);
            nsIds.addAll(auxList);
        }catch(Exception e){
            System.debug('NetsuiteGetSalesOrderBatch Error Start: ' + e.getLineNumber() + '--' + e.getMessage());
        }
        return nsIds;
    }
    
    global void execute(Database.BatchableContext BC, List<String> scope){
        NetsuiteSalesOrderParser nsSales;
        String jsonResponse;
        Opportunity objOpp;
        Account objAccount;
        Map<String, Opportunity> opps = new Map<String, Opportunity>();
        Map<String, Account> accounts = new Map<String, Account>();
        Map<String, Id> userIds = new Map<String, Id>();
    	for(String auxId : scope){
            System.debug(auxId);
        	try{
                jsonResponse = NetsuiteConnection.getNetsuiteObject('salesOrder/' + auxId, '');
                if(jsonResponse!=null){
                    nsSales = (NetsuiteSalesOrderParser) json.deserialize(jsonResponse, NetsuiteSalesOrderParser.class);
                    System.debug('-----------SALES ORDER------------');
                    System.debug(nsSales.trandate);
                    System.debug('-----------SALES ORDER------------');
                    
                    objOpp = new Opportunity(NS_ID__c=auxId, Name=auxId, Balance__c=nsSales.balance, Web_Order_Number__c=nsSales.getWebOrderNumber(),
                                             Order_Detail__c=nsSales.getOrderDetail(), Order__c=nsSales.custbody5, Warehouse_Notes__c=nsSales.getWarehouseNotes(),
                                             Art_file_by_email__c=nsSales.custbody_artfile_by_email, StageName=nsSales.getStage(),
                                             Email__c=nsSales.email, Discount_Total__c=nsSales.discountTotal, Customer_NS_ID__c=nsSales.getEntityId(),
                                             Ship_Date__c=nsSales.shipDate, Ship_Method__c=nsSales.getShipMethod(), Shipping_Cost__c=nsSales.shippingCost,
                                             Netsuite_Status__c=nsSales.status, Subtotal__c=nsSales.subtotal, Tax_Total__c=nsSales.taxTotal,
                                             Transaction_Date__c=nsSales.trandate, Document_Number__c=nsSales.tranId, CloseDate=nsSales.trandate,
                                             Graphics_Designer_NS_Id__c=nsSales.getCustbody3Id(), 
                                             Order_processed_By_NS_ID__c=nsSales.getCustbody9Id(), 
                                             Owner_NS_ID__c=nsSales.getSalesRepId());
                    opps.put(auxId, objOpp);
                    
                    if(nsSales.getEntityId()!=null){
                        objAccount = new Account(NS_ID__c=nsSales.getEntityId(), Name=nsSales.entity.refName);
                        auxAccountIds.add(nsSales.getEntityId());
                        accounts.put(nsSales.getEntityId(), objAccount);
                    }
                    if(nsSales.getCustbody3Id()!=null){
                        userIds.put(nsSales.getCustbody3Id(), null);
                    }
                    if(nsSales.getCustbody9Id()!=null){
                        userIds.put(nsSales.getCustbody9Id(), null);
                    }
                    if(nsSales.getSalesRepId()!=null){
                        userIds.put(nsSales.getSalesRepId(), null);
                    }
                }else
                    System.debug('NetsuiteGetSalesOrderBatch -> Response null or responseCode not 200.!');
           	}catch(Exception e){
            	System.debug('NetsuiteGetSalesOrderBatch Error Execute: ' + e.getLineNumber() + '--' + e.getMessage());
        	}
        }
        
        ApexUtil.isAccountTriggerInvoked = false;
        List<Database.UpsertResult> upsertResults;
        upsertResults = Database.upsert(accounts.values(), Account.NS_ID__c, false);
        for(Database.UpsertResult upsertResult:upsertResults) {
            if(!upsertResult.isSuccess()) {
                for(Database.Error upsertError : upsertResult.getErrors()) 
                    System.debug('NetsuiteGetSalesOrderBatch - Account Upsert Error: ' + upsertError.getMessage());
            }
        }
           
        for(User u : [select Id, NS_ID__c from User where NS_ID__c in: userIds.keySet()])
            userIds.put(u.NS_ID__c, u.Id);
                
		for(Opportunity o : opps.values()){
			if(o.Customer_NS_ID__c!=null)
            {
            	if(accounts.get(o.Customer_NS_ID__c)!=null && accounts.get(o.Customer_NS_ID__c).Id!=null) 
                	o.AccountId=accounts.get(o.Customer_NS_ID__c).Id;
                else
                    System.debug('Cannot relate to account: ' + o.Customer_NS_ID__c);
            }
            if(o.Graphics_Designer_NS_Id__c!=null){
                if(userIds.get(o.Graphics_Designer_NS_Id__c)!=null) 
                	o.Graphics_Designer__c=userIds.get(o.Graphics_Designer_NS_Id__c);
                else
                    System.debug('Cannot relate to Graphics Designer: ' + o.Graphics_Designer_NS_Id__c);
            }
            if(o.Order_processed_By_NS_ID__c!=null){
                if(userIds.get(o.Order_processed_By_NS_ID__c)!=null) 
                	o.Order_processed_By__c=userIds.get(o.Order_processed_By_NS_ID__c);
                else
                    System.debug('Cannot relate to Order Processed By: ' + o.Order_processed_By_NS_ID__c);
            }
            if(o.Owner_NS_ID__c!=null){
                if(userIds.get(o.Owner_NS_ID__c)!=null) 
                	o.OwnerId=userIds.get(o.Owner_NS_ID__c);
                else
                    System.debug('Cannot relate to Owner: ' + o.Owner_NS_ID__c);
            }
        }
        
		ApexUtil.isOpportunityTriggerInvoked = false;         
       	upsertResults = Database.upsert(opps.values(), Opportunity.NS_ID__c, false);
        for(Database.UpsertResult upsertResult:upsertResults){
        	if(!upsertResult.isSuccess()) {
            	for(Database.Error upsertError : upsertResult.getErrors()) 
                	System.debug('NetsuiteGetSalesOrderBatch - Opportunity Upsert Error: ' + upsertError.getMessage());
            }
     	}
    }
    
    global void finish(Database.BatchableContext BC){
        System.debug('Finish NetsuiteGetSalesOrderBatch');
        if(!Test.isRunningTest()){
            System.debug(auxAccountIds);
            Database.executeBatch(new NetsuiteGetCustomersBatch(startDate, auxAccountIds), 25);
        }
    }
    
}