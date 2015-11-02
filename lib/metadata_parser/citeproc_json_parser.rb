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

      def is_journal?
        @json['type'] =~ /journal/i
      end
      def is_book?
        @json['type'] =~ /book/i && @json['container-title'].to_s.empty?
      end
      def is_book_series?
        @json['type'] =~ /book/i && !@json['container-title'].to_s.empty?
      end
      def is_conference_proceeding?
        @json['type'] =~ /proceedings/
      end
      def journal_title
        @json['container-title'] if is_journal?
      end
      def journal_isoabbrev_title
        nil
      end
      def book_title
        if is_book? || is_book_series?
          @json['title']
        elsif is_conference_proceeding?
          @json['container-title']
        else
          nil
        end
      end
      def book_series_title
        @json['container-title'] if is_book_series? || is_conference_proceeding?
      end
      def article_title
        @json['title'].strip if is_journal? || is_conference_proceeding?
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

