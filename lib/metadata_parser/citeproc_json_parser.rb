require 'json'
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
        !!(@json['type'] =~ /book/i) && @json['container-title'].to_s.empty?
      end

      def book_series?
        !!(@json['type'] =~ /book/i) && !@json['container-title'].to_s.empty?
      end

      def conference_proceeding?
        !!(@json['type'] =~ /proceedings/)
      end

      def journal_title
        if journal_article?
          @json['container-title']&.strip
        elsif journal?
          @json['title']&.strip
        else
          nil
        end
      end

      def journal_isoabbrev_title
        if journal_article?
          @json['container-title-short']&.strip
        elsif journal?
          @json['short-title']&.first
        else
          nil
        end
      end

      def book_title
        if book? || book_series?
          @json['title']&.strip
        elsif conference_proceeding?
          @json['container-title']&.strip
        end
      end

      def book_series_title
        @json['container-title']&.strip if book_series? || conference_proceeding?
      end

      def article_title
        @json['title']&.strip if journal_article? || conference_proceeding?
      end

      def authors
        @authors ||= (@json['author'].map.with_index(1) do |contributor, idx|
          Author.new(
            (contributor['given'].strip rescue nil),
            (contributor['family'].strip rescue nil),
            'n/a',
            idx
          )
        end)
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
