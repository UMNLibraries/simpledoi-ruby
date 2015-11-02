require 'nokogiri'
require_relative '../metadata_parser'

module SimpleDOI
  module MetadataParser
    class UnixrefXMLParser < Parser
      XPATH_ROOT = '/doi_records/doi_record/crossref'.freeze

      # Params:
      # +str+:: +String+ XML String
      def initialize(str)
        super

        # Nokogiri will throw an exception on bad XML here
        @xml = Nokogiri::XML(@str) {|opts| opts.strict}
      end
      def is_book?
        !@xml.search("/#{XPATH_ROOT}/book/book_metadata").empty?
      end
      def is_book_series?
        !@xml.search("/#{XPATH_ROOT}/book/book_series_metadata").empty?
      end
      def is_conference_proceeding?
        !@xml.search("/#{XPATH_ROOT}/conference/proceedings_metadata").empty?
      end
      def is_journal?
        !@xml.search("/#{XPATH_ROOT}/journal").empty?
      end
      def book_title
        if is_book_series?
          @book_title ||= @xml.search("/#{XPATH_ROOT}/book/book_series_metadata/titles/title").first.text.strip rescue nil
        elsif is_conference_proceeding?
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
        @isbn ||= @xml.search("/#{XPATH_ROOT}//isbn[@media_type=\"print\"]").first.text.strip rescue nil
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
        @issn ||= @xml.search("/#{XPATH_ROOT}//issn[@media_type=\"print\"]").first.text.strip rescue nil
      end
      def eissn
        @eissn ||= @xml.search("/#{XPATH_ROOT}//issn[@media_type=\"electronic\"]").first.text.strip rescue nil
      end
      def article_title
        if is_conference_proceeding?
          @article_title ||= @xml.search("/#{XPATH_ROOT}/conference/conference_paper/titles/title").first.text.strip rescue nil
        else
          @article_title ||= @xml.search("/#{XPATH_ROOT}/journal/journal_article/titles/title").first.text.strip rescue nil
        end
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
        if is_journal?
          xpath += '/journal/journal_article/doi_data'
        elsif is_book?
          xpath += '/book/book_metadata/doi_data'
        elsif is_book_series?
          xpath += '/book/book_series_metadata/doi_data'
        else
          xpath += '//doi_data'
        end
      end
    end
  end
end
