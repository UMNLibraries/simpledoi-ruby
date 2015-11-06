require 'json'
require_relative '../metadata_parser'

module SimpleDOI
  module MetadataParser
    class CiteprocJSONParser < Parser
      def initialize(str)
        super
        # JSON will throw an exception here if invalid
        @json = JSON.parse(@str)
      end

      def journal?
        @json['type'] =~ /journal/i
      end

      def book?
        @json['type'] =~ /book/i && @json['container-title'].to_s.empty?
      end

      def book_series?
        @json['type'] =~ /book/i && !@json['container-title'].to_s.empty?
      end

      def conference_proceeding?
        @json['type'] =~ /proceedings/
      end

      def journal_title
        @json['container-title'] if journal?
      end

      def journal_isoabbrev_title
        nil
      end

      def book_title
        if book? || book_series?
          @json['title']
        elsif conference_proceeding?
          @json['container-title']
        end
      end

      def book_series_title
        @json['container-title'] if book_series? || conference_proceeding?
      end

      def article_title
        @json['title'].strip if journal? || conference_proceeding?
      end

      # Cannot distinguish between ISSN,eISSN so just take the first one
      def issn
        @json['ISSN'].first rescue nil
      end

      def eissn
        nil
      end

      def isbn
        # ISBN is returned as an array like "ISBN"=>["http://id.crossref.org/isbn/978-1-59059-847-4"]
        # We only really need one and will only use one.
        @json['ISBN'].first.scan(/isbn\/(.+)/).flatten.pop rescue nil
      end

      def doi
        @json['DOI']
      end
    end
  end
end
