require_dependency 'account_controller'

module Redmine::ACNPLMAuth
  module AccountControllerPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable
        alias_method_chain :login, :saml
        alias_method_chain :logout, :saml
      end
    end

    module InstanceMethods

      def login_with_saml
        #TODO: test 'replace_redmine_login' feature
		
        if saml_settings["enabled"] && saml_settings["replace_redmine_login"]
          redirect_to :controller => "account", :action => "login_with_saml_redirect", :provider => "saml", :origin => back_url
        else
          login_without_saml
        end
      end

      def login_with_saml_redirect		        
	  
		auth = {
          "firstname"  		=> request.env['AJP_givenname'],
          "lastname"   		=> request.env['AJP_surname'],
          "mail"       		=> request.env['AJP_emailaddress'],
		  "displayname"     => request.env['AJP_displayname'],
		  "login"       	=> request.env['AJP_enterpriseid'],
		  "uid"       		=> request.env['AJP_enterpriseid'],
		  "enterpriseid"    => request.env['AJP_enterpriseid'],
		  "provider"       	=> "shibboleth"
        }
				
		user = User.find_or_create_from_omniauth(auth) 

        # taken from original AccountController
        # maybe it should be splitted in core
        if user.blank?          
		  logger.warn "Failed login for '#{auth['uid']}' from #{request.remote_ip} at #{Time.now.utc}"
          error = l(:notice_account_invalid_creditentials).sub(/\.$/, '')
          if saml_settings["enabled"]                        
			error << ". Could not find account for #{auth['uid']}"
          end
          if saml_settings["replace_redmine_login"]
            render_error({:message => error.html_safe, :status => 403})
            return false
          else
            flash[:error] = error
            redirect_to signin_url
          end
        else
          user.update_attribute(:last_login_on, Time.now)          
		  params[:back_url] = request.protocol+request.env["HTTP_HOST"]+request.env["SCRIPT_NAME"]
          successful_authentication(user)
          #cannot be set earlier, because sucessful_authentication() triggers reset_session()
          session[:logged_in_with_saml] = true
        end
		
		
      end

      def login_with_saml_callback		
	  
		auth = {
          "firstname"  => request.env['AJP_givenname'],
          "lastname"   => request.env['AJP_surname'],
          "mail"       => request.env['AJP_emailaddress'],
		  "displayname"       => request.env['AJP_displayname'],
		  "login"       => request.env['AJP_enterpriseid'],
		  "uid"       => request.env['AJP_enterpriseid'],
		  "enterpriseid"       => request.env['AJP_enterpriseid'],
		  "provider"       => "shibboleth"
        }						
        
        user = User.find_or_create_from_omniauth(auth) 

        # taken from original AccountController
        # maybe it should be splitted in core
        if user.blank?          
		  logger.warn "Failed login for '#{auth['uid']}' from #{request.remote_ip} at #{Time.now.utc}"
          error = l(:notice_account_invalid_creditentials).sub(/\.$/, '')
          if saml_settings["enabled"]            
			error << ". Could not find account for #{auth['displayname']}"
          end
          if saml_settings["replace_redmine_login"]
            render_error({:message => error.html_safe, :status => 403})
            return false
          else
            flash[:error] = error
            redirect_to signin_url
          end
        else
          user.update_attribute(:last_login_on, Time.now)          
		  params[:back_url] = request.protocol+request.env["HTTP_HOST"]+request.env["SCRIPT_NAME"]
          successful_authentication(user)
          #cannot be set earlier, because sucessful_authentication() triggers reset_session()
          session[:logged_in_with_saml] = true
        end
      end

      def login_with_saml_failure		
        error = params[:message] || 'unknown'
        error = 'error_saml_' + error
        if saml_settings["replace_redmine_login"]
          render_error({:message => error.to_sym, :status => 500})
          return false
        else
          flash[:error] = l(error.to_sym)
          redirect_to signin_url
        end
      end

      def logout_with_saml		
        if saml_settings["enabled"] && session[:logged_in_with_saml]
          logout_user
          redirect_to saml_logout_url(home_url)
        else
          logout_without_saml
        end
      end

      private
      def saml_settings		
        Redmine::ACNPLMAuth.settings_hash
      end

      def saml_logout_url(service = nil)		
		logout_uri = ""
        logout_uri += service.to_s unless logout_uri.blank?
        logout_uri || home_url
      end

    end
  end
end

unless AccountController.included_modules.include? Redmine::ACNPLMAuth::AccountControllerPatch	
  AccountController.send(:include, Redmine::ACNPLMAuth::AccountControllerPatch)
  AccountController.skip_before_filter :verify_authenticity_token, :only => [:login_with_saml_callback]
end
