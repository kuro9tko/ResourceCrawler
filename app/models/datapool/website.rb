# == Schema Information
#
# Table name: datapool_websites
#
#  id              :bigint(8)        not null, primary key
#  title           :string(255)      not null
#  basic_src       :string(255)      not null
#  remain_src      :text(65535)
#  crawl_state     :integer          default("single_standby"), not null
#  last_crawl_time :datetime
#  options         :text(65535)
#
# Indexes
#
#  index_datapool_websites_on_basic_src  (basic_src)
#

class Datapool::Website < Datapool::ResourceBase
  serialize :options, JSON
  has_many :resources, class_name: 'Datapool::ResourceMetum', foreign_key: :datapool_website_id

  enum crawl_state: {
    single_standby: 0,
    single_crawled: 1,
    cycle_crawl_standby: 10,
    cycle_crawling: 11,
    cycle_crawled: 12,
  }

  def self.constract_from_tweet(tweet:, options: {})
    return [] unless tweet.urls?
    tweet_text = Sanitizer.delete_urls(tweet.text)

    websites = tweet.urls.flat_map do |urle|
      website = self.constract(
        url: urle.expanded_url.to_s,
        title: tweet_text,
        options: {
          tweet_id: tweet.id
        }.merge(options)
      )
      website
    end
    return websites.flatten
  end

  def self.constract(url:, title:, options: {})
    website = Datapool::Website.new
    website.src = url.to_s
    website.title = title
    website.options = options
    return website
  end

  @html_dom_cache = nil

  def get_html_dom
    @html_dom_cache ||= RequestParser.request_and_parse_html(url: self.src.to_s, options: {:follow_redirect => true})
    return @html_dom_cache
  end

  def get_css_js_file_urls
    html_dom = self.get_html_dom
    css_js_extes = Datapool::WebMetum::CSS_FILE_EXTENSIONS + Datapool::WebMetum::JS_FILE_EXTENSIONS
    css_js_file_urls = Sanitizer.scan_url_path_resources(html_dom.to_html.downcase, css_js_extes)
    return css_js_file_urls
  end

  def scrape_cycle_links!
    html_dom = self.get_html_dom
    urls = html_dom.css("a").map{|atag| atag[:href]}
    src_website = Datapool::Website.find_by_url(url: urls).index_by(&:src)
    new_urls = urls.select{|url| src_website[url].present? }
    websites = new_urls.map do |url|
      ws = Datapool::Website.new(crawl_state: :cycle_crawling)
      ws.src = url
      ws
    end
    self.transaction do
      Datapool::Website.import(websites)
      self.update!(last_crawl_time: Time.current, crawl_state: :cycle_crawled)
    end
  end

  def scrape_single_html_recourses!
    html_dom = self.get_html_dom
    #docs = HTMLDom.doc_nodes(html_dom.children)
    #attr_values = docs.map{|d| d.attributes.values }.flatten
    css_js_file_urls = self.get_css_js_file_urls

    contents = Sanitizer.scan_url_path_resources(html_dom.to_html.downcase, Datapool::ResourceMetum.resource_file_extensions)
    css_js_file_urls.each do |url|
      text = RequestParser.request_and_response_body(url: self.src.to_s, options: {:follow_redirect => true})
      contents += Sanitizer.scan_url_path_resources(text.downcase, Datapool::ResourceMetum.resource_file_extensions)
    end
    resource_meta = contents.uniq.map do |url|
      resource = Datapool::WebsiteResourceMetum.constract(
        url: url,
        title: self.title,
        check_file: true,
        options: {}
      )
      resource.website_id = self.id
      resource
    end
    self.transaction do
      Datapool::WebsiteResourceMetum.import_resources!(resources: resource_meta)
      self.update!(last_crawl_time: Time.current, crawl_state: :single_crawled)
    end
  end
end
