class SessionsController < ApplicationController
  require 'sf.com/SObject'
  
  def new
    redirect_to '/auth/forcedotcom/'
  end
  
  def create
    ENV['sfdc_api_version'] = '21.0'
    ENV['sfdc_token'] = request.env['omniauth.auth']['credentials']['token']
    ENV['sfdc_instance_url'] = request.env['omniauth.auth']['instance_url']
    redirect_to :controller => 'sessions', :action => 'bom_rev_with_lineitems'
  end
  def fail
    render :text =>  request.env["omniauth.auth"].to_yaml
  end
  
  def pm_task
    @pmts = SObject.find('SELECT Id, Name, Task_Description__c, Bugzilla__c, Feature_Description__c from PM_Task__c order by Task_Description__c')
    @pmts.each {|pmt| p pmt}
  end
  
  def bom_revision
    @bomrev = SObject.find('SELECT Id, Name, Revision_Letter__c, Revision_Purpose__c, Revision_State__c from BoM_Revision__c where Name = \'130-Test-01-A\'')[0]
  end
  
  def bom_rev_update
    @bomrev = SObject.find('SELECT Id, Name, Bill_Of_Material__c, Revision_Letter__c, Revision_Purpose__c, Revision_State__c from BoM_Revision__c where Name like \'130-Test-01-%\' order by Revision_Letter__c DESC limit 1')[0]
    @bomrev.Revision_Letter__c = @bomrev.Revision_Letter__c.next
    @bomrev.Revision_Purpose__c = "Revision #{@bomrev.Revision_Letter__c}" 
    @bomrev.save
  end
  
  def bom_rev_add
    @bomrev = SObject.find('SELECT Id, Name, Bill_Of_Material__c, Revision_Letter__c, Revision_Purpose__c, Revision_State__c from BoM_Revision__c where Name like \'130-Test-01-%\' order by Revision_Letter__c DESC limit 1')[0]
    @newbomrev = SObject.new("BoM_Revision__c")
    @newbomrev.Revision_Letter__c = @bomrev.Revision_Letter__c.next
    @newbomrev.Revision_Purpose__c = "Revision #{@newbomrev.Revision_Letter__c}"
    @newbomrev.Bill_of_Material__c = @bomrev.Bill_of_Material__c
    @newbomrev.save
    @newbomrev = SObject.find("SELECT Id, Name, Bill_Of_Material__c, Revision_Letter__c, Revision_Purpose__c, Revision_State__c from BoM_Revision__c where Id = '#{@newbomrev.Id}'")[0]
  end
  
  def bom_rev_with_lineitems
    @bomrev = SObject.find('SELECT Id, Name, Revision_Letter__c, Revision_Purpose__c, Revision_State__c, (Select Id, Line_No__c, Item_Name__c from BoM_Line_Items__r order by Line_No__c) from BoM_Revision__c where Name = \'130-Test-01-A\'')[0]
  end
  
  def contact_create_and_delete
    contact = SObject.new('contact')
    contact.FirstName = 'Test'
    contact.LastName = 'contact_create_and_delete'
    contact.Phone = '111-222-3333'
    contact.save
    contact.delete
  end
    

end
