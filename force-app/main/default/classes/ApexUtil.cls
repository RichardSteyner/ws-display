public class ApexUtil {
    
    public static Boolean isLeadTriggerInvoked = true;
    public static Boolean isAccountTriggerInvoked = true;
    public static Boolean isContactTriggerInvoked = true;
    public static Boolean isOpportunityTriggerInvoked = true;
    public static Map<String, String> globalSubscriptionStatusContact = new Map<String, String>{'1'=>'_softOptIn', '2'=>'_softOptOut', '3'=>'_confirmedOptIn', '4'=>'_confirmedOptOut'};
    
    public static String getFieldSelectNetsuiteXML(String fieldSF, String fieldNetsuite, String pref){
        String resultXML='', resultId='', resultText='';
        resultId = fieldSF != null ? fieldSF.substringBetween('<', '>') : null;
        if(resultId!=null){
        	resultText = fieldSF.substringAfter('>').trim();
            resultXML = '		<' + pref + ':' + fieldNetsuite + ' internalId="' + resultId + '" xmlns:platformCore="urn:core_2020_1.platform.webservices.netsuite.com">' +
                    	'			<platformCore:name>' + resultText + '</platformCore:name>' +
                		'		</' + pref + ':' + fieldNetsuite + '>';
        }else{
        	resultXML = '';
        }
        return resultXML;
    }
    
    public static String getFieldCustomSelectNetsuiteXML(String fieldSF, String fieldNetsuite, String internalId, String typeId){
        String resultXML='', resultId='', resultText='';
        resultId = fieldSF != null ? fieldSF.substringBetween('<', '>') : null;
        if(resultId!=null){
        	resultText = fieldSF.substringAfter('>').trim();
            resultXML = '			<platformCore:customField internalId="' + internalId +'" scriptId="' + fieldNetsuite + '" xsi:type="platformCore:SelectCustomFieldRef">' + 
                          '               <platformCore:value internalId="' + resultId + '" typeId="' + typeId + '">' +
                          '                   <platformCore:name>' + resultText + '</platformCore:name>' +
                          '               </platformCore:value>' +
                          '           </platformCore:customField>';
        }else{
        	resultXML = '';
        }
        return resultXML;
    }

}