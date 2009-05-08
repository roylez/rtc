#!/usr/bin/env ruby
#Author: Roy L Zuo (roylzuo at gmail dot com)
#Last Change: Mon Apr 20 14:24:33 2009 EST
#Description: 
require 'net/http'
require 'uri'
require 'md5'
require 'rubygems'      #TODO treate ruby 1.9 differently with other versions
require 'json'
require 'config.rb'

class RTM
    #main class, provides methods like rtm.test.echo via a middle help class RTMNamespace
    def initialize(key, secret, token=nil)
        @uri = URI.parse('http://api.rememberthemilk.com/services/rest/')
        @api_key = key
        @shared_secret = secret
        @auth_token = token
    end

    def call_api_method(method, args={})
        args['method'] = "rtm.#{method}"
        args['api_key'] = @api_key
        args['auth_token'] = @auth_token if @auth_token
        args['format'] = 'json'
    
        # make sure everything in our arguments is a string
        args.each do |key,value|
            key_s = key.to_s
            args.delete(key) if key.class != String
            args[key_s] = value.to_s
        end

        #api_sig is always the last one
        args['api_sig'] = sign_request(args)

        #all parameters should be in alphabetical order!
        para = args.collect {|k,v| [k,v].join('=')}.sort.join('&').gsub(/\s+/, '+')
        res = Net::HTTP.get_response( @uri.host, "#{@uri.path}?"+para )
        #XmlSimple.xml_in res.body
        #puts res.body
        JSON.parse( res.body )['rsp']
    end

    def method_missing( symbol, *args )
        namespace = symbol.id2name
        RTMNamespace.new( namespace, self )
    end

    def sign_request(args)      MD5.md5(@shared_secret + args.sort.flatten.join).to_s end

    attr_accessor :auth_token, :shared_secret, :api_key
end 

## this is just a helper class so that you can do things like
## rtm.test.echo.  the method_missing in RTM returns one of
## these.
## this class is the "test" portion of the programming.  its method_missing then
## get invoked with "echo" as the symbol.  it has stored a reference to the original
## rtm object, so it can then invoke call_api_method
class RTMNamespace
    def initialize(namespace, rtm)
        @namespace = namespace
        @rtm = rtm
    end

    def method_missing( symbol, *args )
        method_name = symbol.id2name
        @rtm.call_api_method( "#{@namespace}.#{method_name}", *args)
    end
end

if __FILE__ == $0
    rtm = RTM.new($api_key, $shared_secret, $token)
    #r.send_request({:method=>'rtm.test.login'})
    p rtm.test.login
    p rtm.test.echo
    p rtm.lists.getList['lists']['list']
end
