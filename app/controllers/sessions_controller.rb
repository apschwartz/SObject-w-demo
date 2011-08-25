class SessionsController < ApplicationController
  require 'sf.com/SObject'
  
  def new
    redirect_to '/auth/forcedotcom/'
  end
  
  def create
    ENV['sfdc_api_version'] = '21.0'
    ENV['sfdc_token'] = request.env['omniauth.auth']['credentials']['token']
    ENV['sfdc_instance_url'] = request.env['omniauth.auth']['instance_url']
    redirect_to :controller => 'sessions', :action => 'example'     # Cause the example to run upon successful OAuth login
  end

  def fail
    render :text =>  request.env["omniauth.auth"].to_yaml
  end
  
  # The following is an example use of the SObject class
  def example
    # Create a new account from scratch
    account = SObject.new('Account')
    account.Name = 'My unit test account'
    account.Description = 'My test account'
    account.Type = 'Other'
    account.save              # Saves account and sets account.Id

    # Verify that worked
    account2 = SObject.find("SELECT Id, Description from Account where Id = '#{account.Id}'")
    account2 = account2[0]    # Don't forget, SObject.find returns a list, even if only one object is found
    throw "Save and basic read failed" if (account2.Description != account.Description)

    # Update a retreived record
    account2.Description = 'My updated description'   # Update a value read in the query
    account2.NumberOfEmployees = 1                    # Update a new value, not included in the SoQL query
    account2.save      # Save both fields
    # Verify that worked
    account3 = SObject.find("SELECT Id, Description, NumberOfEmployees from Account where Id = '#{account2.Id}'")[0]
    throw "Update of record failed" if (account3.Description != 'My updated description' || 
                                        account3.NumberOfEmployees != 1)
                                        
    # Let's create a couple of contacts
    contacts = Array.new
    contact1 = SObject.new('Contact')
    contact1.LastName = 'Schwartz'
    contact1.FirstName = 'Andy'
    contact1.Phone = '111-222-3333'
    contact1.AccountId = account.Id
    contact1.save
    contact2 = SObject.new('Contact')
    contact2.LastName = 'VanWinkle'
    contact2.FirstName = 'Rip'
    contact2.Phone = '914-555-1234'
    contact2.AccountId = account.Id
    contact2.save

    # Read back the Account record along with a nested query of the associated Contacts
    my_account = SObject.find(%"SELECT Id, 
                                       Name, 
                                       Description, 
                                       (SELECT Id, 
                                               LastName, 
                                               FirstName, 
                                               Phone 
                                        from Contacts
                                        order by LastName) 
                                from Account 
                                where Id = '#{account.Id}'")[0]
    throw "Account read failed" if (my_account.Name != account.Name ||
                                    my_account.Id != account.Id)
    throw "Nested Contact read failed" if (my_account.Contacts[0].FirstName != contact1.FirstName ||
                                           my_account.Contacts[0].Id != contact1.Id ||
                                           my_account.Contacts[1].FirstName != contact2.FirstName ||
                                           my_account.Contacts[1].Id != contact2.Id)
    
    # Clean up from our example
    my_account.delete
    account_try = SObject.find("SELECT Id from Account where Id = '#{my_account.Id}'")
    throw "Delete failed" if account_try.size != 0

  end
    

end
