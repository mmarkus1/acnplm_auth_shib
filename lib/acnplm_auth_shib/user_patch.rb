require_dependency 'user'

class User
  def self.find_or_create_from_omniauth(omniauth)    
	user = self.find_by_enterprise_id(omniauth['enterpriseid'])
    unless user
      if Redmine::ACNPLMAuth.onthefly_creation? 
        auth = {          
		  :enterpriseid => omniauth['enterpriseid'],
		  :firstname  => omniauth['firstname'],
          :lastname   => omniauth['lastname'],
          :mail       => omniauth['mail']
		  
        }
        user = new(auth)         
		user.login    = omniauth['login']		
        user.language = Setting.default_language
        user.activate
        user.save!
        user.reload
      end
    end
    user
  end
  
	def self.find_by_enterprise_id(enterpriseid)
	  # force string comparison to be case sensitive on MySQL
	  type_cast = (ActiveRecord::Base.connection.adapter_name == 'MySQL') ? 'BINARY' : ''
	  
	  # First look for an exact match
	  user = first(:conditions => ["#{type_cast} enterpriseid = ?", enterpriseid])
	  # Fail over to case-insensitive if none was found
	  user ||= first(:conditions => ["#{type_cast} LOWER(enterpriseid) = ?", enterpriseid.to_s.downcase])
	end  

end
