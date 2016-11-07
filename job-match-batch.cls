public class JobMatchBatch implements Database.Batchable<sObject>{
    //Database.executeBatch(new JobMatchBatch(), 2000);
   public Database.QueryLocator start(Database.BatchableContext BC){
      return Database.getQueryLocator('SELECT Id FROM Job_Posting__c WHERE Closing_Date__c >= TODAY OR Closing_Date__c = NULL');
   }
   public void execute(Database.BatchableContext BC, List<Job_Posting__c> scope){
    List<Job_Match__c> jobMatches = new List<Job_Match__c>();
    Set<Id> jobPosting = new Set<Id>();

    for(Job_Posting__c s : scope){
        jobPosting.add(s.Id);     	
     }
     
       List<Job_Seeker_Qualification__c> jobsQualificationList = [SELECT Id, Importance__c, Name, Weight__c, Years_of_Experience__c, Qualifications__c, Job_Posting__c,        RecordTypeId                                                         
        FROM Job_Seeker_Qualification__c
        WHERE Job_Posting__c IN:jobPosting AND Qualifications__c != NULL];
         
       Map<Id, List<Job_Seeker_Qualification__c>> jMap = new Map<Id, List<Job_Seeker_Qualification__c>>();
       Set<string> qualifications = new Set<string>();
       
       for(Job_Seeker_Qualification__c s : jobsQualificationList){
           qualifications.add(s.Qualifications__c);
           if(jMap.containsKey(s.Job_Posting__c)){
               List<Job_Seeker_Qualification__c> tempList = jMap.get(s.Job_Posting__c);
               tempList.add(s);
               jMap.put(s.Job_Posting__c, tempList);
           }else{
               jMap.put(s.Job_Posting__c, new List<Job_Seeker_Qualification__c>{s});
           }
       }
       list<Job_Seeker_Qualification__c> seekerQualificationList =[SELECT Id, Start_Date__c, End_Date__c, Years_of_Experience__c, Job_Seeker__c, Qualifications__c, RecordTypeId
        FROM Job_Seeker_Qualification__c
        WHERE Qualifications__c IN:qualifications AND Job_Seeker__c != NULL];
        
       Map<Id, List<Job_Seeker_Qualification__c>> jsMap = new Map<Id, List<Job_Seeker_Qualification__c>>();
       
       for(Job_Seeker_Qualification__c s : seekerQualificationList){
           if(jsMap.containsKey(s.Job_Seeker__c)){
               List<Job_Seeker_Qualification__c> tempList = jsMap.get(s.Job_Seeker__c);
               tempList.add(s);
               jsMap.put(s.Job_Seeker__c, tempList);
           }else{
               jsMap.put(s.Job_Seeker__c, new List<Job_Seeker_Qualification__c>{s});
           }
       }
       for(Id jobPostId:jMap.keySet()){
           List<Job_Seeker_Qualification__c> jobQueryList = jMap.get(jobPostId);
           
           for(Id jobSeekerId:jsMap.keySet()){
               List<Job_Seeker_Qualification__c> jobSeekerList = jsMap.get(jobSeekerId);              
               integer totalQualifications =  jobQueryList.size();
               double matchScore = compareQualifications(jobQueryList, jobSeekerList);
               
               if(matchScore > 0)
               	jobMatches.add(new Job_Match__c(Job_Seeker__c = jobSeekerId, Job_Posting__c = jobPostId, Percent_Match__c = matchScore, Upsert_Key__c= jobPostId + '|' + jobSeekerId));
           }
       }
	  UPSERT jobMatches Upsert_Key__c;       
    }
    
    public static double compareQualifications(List<Job_Seeker_Qualification__c> jobQueryList, List<Job_Seeker_Qualification__c> jobSeekerList){
        integer matchesFound = 0;
        double candidateMatch= 0.0;
        List<Job_Seeker_Qualification__c> requiredQualifications = new List<Job_Seeker_Qualification__c>();
        
        for(Job_Seeker_Qualification__c jq:jobQueryList){
            if (jq.Importance__c == 'Required'){
                requiredQualifications.add(jq);
            }
        }
        integer satisfiedRequirements = 0;
        for(Job_Seeker_Qualification__c jq:requiredQualifications){
            for(Job_Seeker_Qualification__c js:jobSeekerList){
                if(jq.Qualifications__c == js.Qualifications__c){
                    satisfiedRequirements++;
                }
            }
        }
        if(satisfiedRequirements < requiredQualifications.size())
            return 0;
         double sumMatch = 0.0;
        for(Job_Seeker_Qualification__c jq:jobQueryList){
            double expWanted = jq.Years_of_Experience__c;          
            if(expWanted == null)
                expWanted = 0.0; 
            if(expWanted > 10)
                expWanted=10;
            double qualificationWeight = jq.Weight__c;
            if(qualificationWeight == null)
                qualificationWeight = 5.0;
            qualificationWeight = (10 -qualificationWeight)*10;
            for(Job_Seeker_Qualification__c js:jobSeekerList){
                double expPossessed = js.Years_of_Experience__c;
                if(expPossessed == null)
                    expPossessed = 0.0;  
                 if(expPossessed > 10)
                	expPossessed=10;
                if(jq.Qualifications__c == js.Qualifications__c){ 
                    if(expWanted != 0){
                        sumMatch += (((expPossessed/expWanted)*100)+qualificationWeight)/2;
                    }                     
                }               
            }
        }
        if(jobQueryList.size() == 0)
            return 0;
        candidateMatch = sumMatch/jobQueryList.size();
        return candidateMatch;
    }
    public void finish(Database.BatchableContext BC){
    }
}
