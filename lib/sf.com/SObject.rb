# This class allows access to and manipulation of SF.com objects as ruby objects.
#
# Author:: Andy Schwartz
# Copyright:: Copyright (c) 2011 Andrew Schwartz
# License:: ALL RIGHTS RESERVED.  Will decide on a less-restrictive license at a later date.


require 'rubygems'
require 'httparty'

class SObject
  include HTTParty
  format :json
  
  attr_reader :fields
  
  def initialize(object_name = nil)
    @reserved_fields = ['fields', 'object_name', 'reserved_fields']
    @object_name = object_name
    @fields = Array.new
    @updated_fields = Array.new
    @Id = nil
  end

  # Creates a new SObject using a SOQL search, specified as the +select+ parameter to this class-level method.
  def self.find(select)
    SObject.set_headers
    x = get(SObject.root_url+"/query/?q=#{CGI::escape(select)}")
    raise x.parsed_response[0]['message'] if x.response.code.to_i > 299
    objects = Array.new
    x['records'].each do |x|
      object = SObject.from_query_response x
      objects << object
    end
    return objects
  end
  
  def self.from_query_response(query_result)
    result_object = SObject.new
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

  def delete
    self.class.headers 'Authorization' => "OAuth #{ENV['sfdc_token']}"
    self.class.headers 'Content-Type' => "application/json"
    response = self.class.delete(SObject.root_url+"/sobjects/#{@object_name}/#{@Id}")
    raise response.parsed_response[0]['message'] if response.code.to_i > 299
    nil
  end
 
  def method_missing(sym, *args)
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

  def self.set_headers
   headers 'Authorization' => "OAuth #{ENV['sfdc_token']}"
  end

  def self.root_url
    @root_url = ENV['sfdc_instance_url']+"/services/data/v"+ENV['sfdc_api_version']
  end
  

  
end
    
    