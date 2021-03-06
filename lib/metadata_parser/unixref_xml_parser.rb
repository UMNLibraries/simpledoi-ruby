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
        !book_chapter? && !@xml.search("/#{XPATH_ROOT}/book/book_metadata").empty?
      end

      def book_series?
        !@xml.search("/#{XPATH_ROOT}/book/book_series_metadata").empty?
      end

      def book_chapter?
        !@xml.search("/#{XPATH_ROOT}/book/content_item[@component_type=\"chapter\"]").empty?
      end

      def conference_proceeding?
        !@xml.search("/#{XPATH_ROOT}/conference/*[starts-with(local-name(), \"proceedings\")]").empty?
      end

      def journal_article?
        !@xml.search("/#{XPATH_ROOT}/journal/journal_article").empty?
      end

      def journal?
        !@xml.search("/#{XPATH_ROOT}/journal").empty? && !journal_article?
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

      def chapter_title
        @chapter_title ||= @xml.search("/#{XPATH_ROOT}/book/content_item[@component_type=\"chapter\"]/titles/title").first.text.strip rescue nil
      end

      def chapter_number
        @chapter_number ||= @xml.search("/#{XPATH_ROOT}/book/content_item[@component_type=\"chapter\"]/component_number").first.text.strip rescue nil
      end

      def conference_title
        @conference_title ||= @xml.search("/#{XPATH_ROOT}/conference//event_metadata/conference_name").first.text.strip rescue nil
      end

      def conference_series_title
        @conference_series_title ||= @xml.search("/#{XPATH_ROOT}/conference/*/series_metadata/titles/title").first.text.strip rescue nil
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

      def contributors
        role_sequences = Hash.new(0)
        @contributors ||= (@xml.search(contributors_path).map.with_index(1) do |contributor, idx|
          Contributor.new(
            (contributor.search('./given_name').first.text.strip rescue nil),
            (contributor.search('./surname').first.text.strip rescue nil),
            (contributor.attr('contributor_role').strip rescue nil),
            # Incremenent each per role, so all <contributor> elements can be read at once
            # while preserving author vs editor vs other sequences
            role_sequences[contributor.attr('contributor_role')] += 1
          )
        end)
      end

      def doi
        @doi ||= (@xml.search("#{doi_path}/doi").first.text.strip rescue nil) || (@xml.search("#{XPATH_ROOT}//doi_data/doi").first.text.strip rescue nil)
      end

      def url
        @url ||= (@xml.search("#{doi_path}/resource").first.text.strip rescue nil) || (@xml.search("#{XPATH_ROOT}//doi_data/resource").first.text.strip rescue nil)
      end

      def fulltext_url
        # Direct PDF may be in <item crawler="iParadigms"> intended for PDF submission to document similarity
        # testing engine https://www.crossref.org/education/similarity-check/participate/urls-for-existing-deposits/#00319
        @fulltext_url ||= (@xml.search("#{doi_path}/collection[@property='crawler-based']/item[@crawler='iParadigms']/resource").first.text.strip rescue nil)
      end

      def publisher_name
        @publisher_name ||= @xml.search("//publisher/publisher_name").first.text.strip rescue nil
      end

      def publisher_place
        @publisher_place ||= @xml.search("//publisher/publisher_place").first.text.strip rescue nil
      end

      def volume
        @volume ||= (@xml.search("#{volume_path}").first.text.strip rescue nil)
      end

      def issue
        @issue ||= (@xml.search("#{volume_issue_path}/issue").first.text.strip rescue nil)
      end

      def pagination
        @pagination ||= (@xml.search("//pages/first_page").first.text.strip + '-' + @xml.search('//pages/last_page').first.text.strip rescue nil)
      end

      def publication_date
        Date.new(publication_date_hash[:year], publication_date_hash[:month] || 1, publication_date_hash[:day] || 1) rescue nil
      end

      def publication_date_hash
        @publication_date_hash ||= {
          year: (@xml.search("#{publication_date_path}/year").first.text.strip.to_i rescue nil),
          month: (@xml.search("#{publication_date_path}/month").first.text.strip.to_i rescue nil),
          day: (@xml.search("#{publication_date_path}/day").first.text.strip.to_i rescue nil)
        }
      end

      protected

      def doi_path
        xpath = XPATH_ROOT
        if journal_article?
          xpath + '/journal/journal_article/doi_data'
        elsif journal?
          xpath + '/journal/journal_metadata/doi_data'
        elsif book?
          xpath + '/book/book_metadata/doi_data'
        elsif book_chapter?
          xpath + '/book/content_item[@component_type="chapter"]/doi_data'
        elsif book_series?
          xpath + '/book/book_series_metadata/doi_data'
        else
          xpath + '//doi_data'
        end
      end

      def contributors_path
        xpath = XPATH_ROOT
        if journal_article?
          xpath + '/journal/journal_article/contributors/person_name'
        elsif book?
          xpath + '/book/book_metadata/contributors/person_name'
        elsif book_series?
          xpath + '/book/book_series_metadata/contributors/person_name'
        elsif book_chapter?
          # Chapters may list editors in the outer <book> and chapter authors in the inner <content_item>
          xpath + '/book/book_metadata/contributors/person_name|' + xpath + '/book/content_item[@component_type="chapter"]/contributors/person_name'
        elsif conference_proceeding?
          xpath + '/conference/conference_paper/contributors/person_name'
        else
          '//contributors/person_name'
        end
      end

      def volume_issue_path
        xpath = XPATH_ROOT
        if journal_article?
          xpath + '/journal/journal_issue'
        elsif book?
          xpath + '/book/book_metadata'
        elsif book_series?
          xpath + '/book/book_series_metadata'
        elsif conference_proceeding?
          xpath + '/conference/proceedings_metadata'
        else
          '//'
        end
      end

      def volume_path
        xpath = volume_issue_path
        if journal_article?
          xpath + '/journal_volume/volume'
        elsif book? || book_series?
          xpath + '/volume'
        else
          '//volume'
        end
      end

      def publication_date_path
        '//publication_date'
      end
    end
  end
end
