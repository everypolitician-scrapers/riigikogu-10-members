
# Fetch member information from riigikogu.ee

require 'json'
require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'open-uri/cached'
require 'pry'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def date_from(t)
  return if t.to_s.empty?
  Date.parse(t).to_s rescue ''
end

def scrape_list(url, term_id)
  noko = noko_for(url)

  districts = noko.xpath('.//h4[contains(.,"Valimisringkonnad")]/following-sibling::ul[1]/li').map { |li|
    li.text[/Ringkond nr. \d+ – (.*)/, 1]
  }

  table = noko.at_xpath('.//h2[contains(., "Riigikogu liikmed")]/following::table')
  table.css('tr').drop(1).each do |tr|
    tds = tr.css('td')
    next if tds[2].text.to_s.empty?

    nplus = tds[0].text.lines.map(&:tidy).reject(&:empty?)
    name = nplus.shift
    notes = nplus.join("; ")
    if matched = name.match(/^*(\d+)\. (.*)/)
      id, name = matched.captures
    end
    district_id = tds[2].text.tidy.split("/").first.to_i
    raise "Unknown district: #{tds[2].text} -> #{district_id}" if district_id.zero?

    data = { 
      name: name,
      faction: tds[3].text.tidy,
      party: tds[4].text.tidy,
      area_id: district_id,
      area: districts[ district_id - 1 ],
      term: term_id,
      notes: notes,
    }
    # puts data
    ScraperWiki.save_sqlite([:name, :term], data)
  end
end

terms = { 
  10 => 'http://www.riigikogu.ee/tutvustus-ja-ajalugu/riigikogu-ajalugu/x-riigikogu-koosseis/juhatus-ja-liikmed/',
}

terms.each do |id, url|
  scrape_list(url, id)
end
