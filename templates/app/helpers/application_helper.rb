module ApplicationHelper
  def nav_link_to(label, url, options={})
    if current_page?(url)
      options[:class] ? options[:class] << ' current' : options[:class] = 'current'
    end
    link_to(label, url, options)
  end
  
  def nav_item(label, url, options={})
    shallow = options.delete(:shallow)
    
    classes = (options[:class] || '').split(' ')
    if (shallow and request.request_uri == url) or (!shallow and request.request_uri.start_with?(url))
      classes << 'current'
    end
    options[:class] = classes.empty? ? nil : classes.join(' ')
    
    content_tag(:li, link_to(label, url), options)
  end
end