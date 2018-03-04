require 'nokogiri'
require_relative '../metadata_parser'

module SimpleDOI
  # Metadata parsers
  module MetadataParser
    # Basic metadata parser for Unixref+xml content types
    class UnixrefXMLParser < Parser
      XPATH_ROOT = '/doi_records/doi_record/crossref'.freeze

      # Params:
      # +str+:: +String+ XML String
      def initialize(str)
        super

        # Nokogiri will throw an exception on bad XML here
        @xml = Nokogiri::XML(@str) { |opts| opts.strict }
      end

      def book?
        !@xml.search("/#{XPATH_ROOT}/book/book_metadata").empty?
      end

      def book_series?
        !@xml.search("/#{XPATH_ROOT}/book/book_series_metadata").empty?
      end

      def conference_proceeding?
        !@xml.search("/#{XPATH_ROOT}/conference/proceedings_metadata").empty?
      end

      def journal?
        !@xml.search("/#{XPATH_ROOT}/journal").empty?
      end

      def book_title
        if book_series?
          @book_title ||= @xml.search("/#{XPATH_ROOT}/book/book_series_metadata/titles/title").first.text.strip rescue nil
        elsif conference_proceeding?
          @book_title ||= @xml.search("/#{XPATH_ROOT}/conference/proceedings_metadata/proceedings_title").first.text.strip rescue nil
        else
          @book_title ||= @xml.search("/#{XPATH_ROOT}/book/book_metadata/titles/title").first.text.strip rescue nil
        end
      end

      def book_series_title
        @book_series_title ||= @xml.search("/#{XPATH_ROOT}/book//series_metadata/titles/title").first.text.strip rescue nil
      end

      def conference_title
        @conference_title ||= @xml.search("/#{XPATH_ROOT}/conference//event_metadata/conference_name").first.text.strip rescue nil
      end

      def isbn
        # Usually includes media_type="print" but some vendors supply <isbn> with no attributes
        @isbn ||= @xml.search("/#{XPATH_ROOT}//isbn[not(@media_type) or @media_type=\"print\"]").first.text.strip rescue nil
      end

      def eisbn
        @eisbn ||= @xml.search("/#{XPATH_ROOT}//isbn[@media_type=\"electronic\"]").first.text.strip rescue nil
      end

      def journal_title
        @journal_title ||= @xml.search("/#{XPATH_ROOT}/journal/journal_metadata/full_title").first.text.strip rescue nil
      end

      def journal_isoabbrev_title
        @journal_isoabbrev_title ||= @xml.search("/#{XPATH_ROOT}/journal/journal_metadata/abbrev_title").first.text.strip rescue nil
      end

      def issn
        # Usually includes media_type="print" but some vendors supply <issn> with no attributes
        @issn ||= @xml.search("/#{XPATH_ROOT}//issn[not(@media_type) or @media_type=\"print\"]").first.text.strip rescue nil
      end

      def eissn
        @eissn ||= @xml.search("/#{XPATH_ROOT}//issn[@media_type=\"electronic\"]").first.text.strip rescue nil
      end

      def article_title
        if conference_proceeding?
          @article_title ||= @xml.search("/#{XPATH_ROOT}/conference/conference_paper/titles/title").first.text.strip rescue nil
        else
          @article_title ||= @xml.search("/#{XPATH_ROOT}/journal/journal_article/titles/title").first.text.strip rescue nil
        end
      end

      def authors
        @authors ||= (@xml.search(authors_path).map.with_index(1) do |contributor, idx|
          Author.new(
            (contributor.search('./given_name').first.text.strip rescue nil),
            (contributor.search('./surname').first.text.strip rescue nil),
            (contributor.attr('contributor_role').strip rescue nil),
            idx
          )
        end)
      end

      def doi
        @doi ||= (@xml.search("#{doi_path}/doi").first.text.strip rescue nil) || (@xml.search("#{XPATH_ROOT}//doi_data/doi").first.text.strip rescue nil)
      end

      def url
        @url ||= (@xml.search("#{doi_path}/resource").first.text.strip rescue nil) || (@xml.search("#{XPATH_ROOT}//doi_data/resource").first.text.strip rescue nil)
      end

      protected

      def doi_path
        xpath = XPATH_ROOT
        if journal?
          xpath + '/journal/journal_article/doi_data'
        elsif book?
          xpath + '/book/book_metadata/doi_data'
        elsif book_series?
          xpath + '/book/book_series_metadata/doi_data'
        else
          xpath + '//doi_data'
        end
      end

      def authors_path
        xpath = XPATH_ROOT
        if journal?
          xpath + '/journal/journal_article/contributors/person_name'
        elsif book?
          xpath + '/book/book_metadata/contributors/person_name'
        elsif book_series?
          xpath + '/book/book_series_metadata/contributors/person_name'
        else
          xpath + '//contributors'
        end
      end
    end
  end
end
