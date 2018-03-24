require 'json'
require 'date'
require_relative '../metadata_parser'

module SimpleDOI
  module MetadataParser
    class CiteprocJSONParser < Parser
      # Format docs: https://citeproc-js.readthedocs.io/en/latest/csl-json/markup.html
      def initialize(str)
        super
        # JSON will throw an exception here if invalid
        @json = JSON.parse(@str)
      end

      def journal_article?
        !!(@json['type'] =~ /journal/i && @json['type'] =~ /article/i)
      end

      def journal?
        @json['type'].to_s.downcase == 'journal'
      end

      def book?
        !!(@json['type'] =~ /book/i) && scalar('container-title').to_s.empty?
      end

      def book_series?
        !!(@json['type'] =~ /book/i) && !scalar('container-title').to_s.empty?
      end

      def book_chapter?
        !!(@json['type'] =~ /chapter/)
      end

      def conference_proceeding?
        !!(@json['type'] =~ /proceedings|conference/)
      end

      def journal_title
        if journal_article?
          scalar('container-title')
        elsif journal?
          @json['title']&.strip
        else
          nil
        end
      end

      def journal_isoabbrev_title
        if journal_article?
          scalar('container-title-short')
        elsif journal?
          @json['short-title']&.first
        else
          nil
        end
      end

      def book_title
        if book? || book_series?
          @json['title']&.strip
        elsif book_chapter? || conference_proceeding?
          scalar('container-title')
        end
      end

      def book_series_title
        scalar('container-title') if book_series? || conference_proceeding?
      end

      def article_title
        @json['title']&.strip if journal_article? || conference_proceeding?
      end

      def chapter_title
        @json['title']&.strip if book_chapter?
      end

      def conference_title
        @json['event']&.strip if conference_proceeding?
      end

      def authors
        contributors('author').select {|c| c.contributor_role == 'author'}
      end

      def editors
        contributors('editor').select {|c| c.contributor_role == 'editor'}
      end


      def contributors(set_type=nil)
        # Return the whole array if no type requested
        @contributors ||= []
        return @contributors if set_type.nil?

        # Gather the requested contributor type if it has not been previously requested
        if @contributors.select {|contributor| contributor.contributor_role == set_type}.empty?
          @contributors += (@json[set_type].map.with_index(1) do |contributor, idx|
            Contributor.new(
              (contributor['given'].strip rescue nil),
              (contributor['family'].strip rescue nil),
              set_type,
              idx
            )
          end)
        end
        @contributors
      end

      # Cannot distinguish between ISSN,eISSN so just take the first one
      def issn
        @json['ISSN'].first.strip rescue nil
      end

      # Citeproc produces a list of unlabled ISSNs so we provide a method to get them all
      def issns
        @json['ISSN'] rescue []
      end

      def eissn
        nil
      end

      def isbn
        # We only really need one and will only use one.
        isbns&.first
      end

      def isbns
        # ISBN is usually returned as an array like "ISBN"=>["http://id.crossref.org/isbn/978-1-59059-847-4"]
        if @json['ISBN']&.first =~ /^http/
          @json['ISBN'].first.scan(/isbn\/(.+)/).flatten rescue []
        else
          @json['ISBN'] || []
        end
      end

      def doi
        @json['DOI']
      end

      def publisher_name
        @json['publisher']&.strip
      end

      def publisher_place
        @json['publisher-location']&.strip
      end

      def volume
        @json['volume']&.strip
      end

      def issue
        @json['issue']&.strip
      end

      def pagination
        @json['page']&.strip
      end

      def publication_date
        arr_to_date(@json['issued']['date-parts'].first) rescue nil
      end

      def publication_date_hash
        arr_to_date_hash(@json['issued']['date-parts'].first) rescue nil
      end

      # Returns a Date object based on source array [year, month, day]
      # substituting 1 for absent month, day
      def arr_to_date(date_source)
        Date.new(date_source[0], date_source[1] || 1, date_source[2] || 1)
      end

      # Returns a Hash indexed :year, :month, :day based on a source array [year, month, day]
      # maintining nil for missing date parts
      def arr_to_date_hash(date_source)
        Hash[[:year, :month, :day].zip(date_source)]
      end

      protected
      # Some items in JSON are supplied as arrays by some vendors and strings by most others
      # We assume single strings for these, so force the array down to a single scalar
      def scalar(key)
        [@json[key]].flatten.first.strip rescue nil
      end
    end
  end
end
