require 'rubygems'
require 'httparty'

# Provides access to, and manipulation of, Salesforce.com objects as ruby objects.
#
# This integration provides an easy ability to query, create, update and delete SF objects from Ruby.  
# SF object field names are referenced directly as method names, providing a similar look-and-feel to Apex.
# Example:
#   puts my_contact.FirstName
#   my_contact.LastName = "schwartz"
#
# Properly setting expecations, this class:
# - Does not create a Rails ActiveRecord object for Salesforce.
# - Does not use the Salesforce <tt><b>Describe</b></tt> function to learn the allowed fields of an object.  
#   If undefined fields are attempted to be set, an error will be generated from Salesforce when the object is saved.
#
# Author:::    Andy Schwartz (aschwartz@edgewaternetworks.com and andy-sf@schegg.org)
# Copyright::: Copyright (c) 2011 Andrew Schwartz
#
# == Usage Examples
#
# 1) <b>Create a new SObject and write it out to Salesforce:</b>
#   my_contact = SObject.new('Contact')
#   my_contact.LastName = "Schwartz"
#   my_contact.FirtName = "Andrew"
#   my_contact.Email = "andy-salesforce@schegg.org"
#   my_contact.save
#
# 2) <b>Retrieve one or more objects via a SOQL query:</b>
#   contacts = SObject.find("select Id, FirstName, LastName, Phone from Contact where Account.Name = 'Acme'")
#   contacts.each { |c| puts "#{c.FirstName} #{c.LastName} #{c.Phone}" }
#
# A list is always returned, even if only one record is retrieved, so add "[0] if you know only one record will be returned".
# Also, a returned object can be updated and saved back.  Examples of both:
#   my_contact = SObject.find("select Id, Phone from Contact where Name = 'Andrew Schwartz'")[0]
#   my_contact.Phone = '111-222-3333'
#   my_contact.Description = 'Even an un-queried field can be updated and saved'
#   my_contact.save
#
# 2b) <b>Retrieval of an object with related objects is also supported.  The related objects are returned as nested SObjects.  For example:</b>
#   my_Accounts_with_Contacts = SObject.find(%"select Id, 
#                                                     Name, 
#                                                     Website, 
#                                                     (select Id, 
#                                                             Name, 
#                                                             Phone 
#                                                      from Contacts 
#                                                      limit 10) 
#                                              from Account 
#                                              limit 10")
#   my_Accounts_with_Contacts.each do |account|
#     puts account.Name + " -- #{account.Website}"
#     if account.Contacts != nil
#       account.Contacts.each do |contact|
#         puts "  " + contact.Name + " - " + contact.Phone.to_s
#       end
#     end
#   end
#
# You can even update a retrieved related object if you want.  For example, given the above query:
#   my_Accounts_with_Contacts.Contacts[0].Phone = '111-222-3333'
#   my_Accounts_with_Contacts.Contacts[0].save
#
# 3) <b>Deleting is supported as well, of course:</b>
#   my_contact = SObject.find("select Id from Contact where Name = 'Andrew Schwartz'")[0]
#   my_contact.delete if my_contact != nil
class SObject
  include HTTParty
  format :json
  
  # Lists all retrieved and/or set fields in this instance of an SObject.  A (very) poor man's Describe function.  
  attr_reader :fields #:nodoc:#
  
  # Create a new, empty SObject.  Must provide the object's name as known to the SF.com API.
  #
  # Example:
  #  my_contact = SObject.new('Contact')
  #  my_thingy = SObject.new('MyCustomObject__c')
  def initialize(object_name)
    @reserved_fields = ['fields', 'object_name', 'reserved_fields']
    @object_name = object_name
    @fields = Array.new
    @updated_fields = Array.new
    @Id = nil
  end

  # Creates a new SObject using a SOQL search, specified as a string parameter to this class-level method.
  def self.find(soql)
    SObject.set_headers
    x = get(SObject.root_url+"/query/?q=#{CGI::escape(soql)}")
    raise x.parsed_response[0]['message'] if x.response.code.to_i > 299
    objects = Array.new
    x['records'].each do |x|
      object = SObject.from_query_response x
      objects << object
    end
    return objects
  end
  
  # Creates or Updates the object, depending on whether the object Id is already set (ie. performs an upsert).
  #
  # Throws an exception if Salesforce returns an error.  Otherwise simply returns nil.
  def save
    self.class.headers 'Authorization' => "OAuth #{ENV['sfdc_token']}"
    self.class.headers 'Content-Type' => "application/json"
    fields_list = Hash.new
    @updated_fields.each {|f| fields_list[f.to_s] = instance_variable_get "@#{f}"}
    options = {
      :body => fields_list.to_json
    }
    if @Id == nil
      response = self.class.post(SObject.root_url+"/sobjects/#{@object_name}", options)
      raise response.parsed_response[0]['message'] if response.code.to_i > 299
      @Id = response.parsed_response['id']
    else
      response = self.class.post(SObject.root_url+"/sobjects/#{@object_name}/#{@Id}?_HttpMethod=PATCH", options)
      raise response.parsed_response[0]['message'] if response.code.to_i > 299
    end
    nil
  end

  # Deletes the object.
  #
  # Throws an exception if Salesforce returns an error.  Otherwise simply returns nil.
  def delete
    self.class.headers 'Authorization' => "OAuth #{ENV['sfdc_token']}"
    self.class.headers 'Content-Type' => "application/json"
    response = self.class.delete(SObject.root_url+"/sobjects/#{@object_name}/#{@Id}")
    raise response.parsed_response[0]['message'] if response.code.to_i > 299
    nil
  end
 
  # This is a public method but is never called directly.  Allows access to SObject fields by just specifying the field name
  # as a method name.
  #
  # Example:
  #   puts my_contact.FirstName
  #   my_contact.LastName = 'Smith'
  def method_missing(sym, *args) #:nodoc:#
    if sym =~ /^(\w+)=$/
      if @reserved_fields.include?("#{$1}")
        throw "Field '#{$1}' cannot be modified."
      end
      if !@updated_fields.include?("#{$1}")
        @updated_fields << "#{$1}"
      end
      if !@fields.include?("#{$1}")
        @fields << "#{$1}"
      end
      instance_variable_set "@#{$1}", args[0]
    else
      instance_variable_get "@#{sym}"
    end
  end

  
  private
  
  # Used by +find()+ to create an SObject from a soql query response.  Called recursively if the query response contains referenced 
  # child objects.
  def self.from_query_response(query_result)
    result_object = SObject.new(nil)
    query_result.each do |k,v|
      if k == 'attributes'
        result_object.instance_variable_set "@object_name", v["type"]
        next
      end
      result_object.fields << k
      if v.class != Hash
        result_object.instance_variable_set "@#{k}".to_s, v
      else
        objects = Array.new
        v['records'].each do |x|
          object = SObject.from_query_response x
          objects << object
        end
        result_object.instance_variable_set "@#{k}".to_s, objects
      end
    end
    return result_object     
  end
  

  def self.set_headers
   headers 'Authorization' => "OAuth #{ENV['sfdc_token']}"
  end

  def self.root_url
    @root_url = ENV['sfdc_instance_url']+"/services/data/v"+ENV['sfdc_api_version']
  end
  

  
end
    
    