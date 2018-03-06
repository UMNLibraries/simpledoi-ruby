module SimpleDOI
  module MetadataParser
    # Metadata parser base class
    class Parser
      PROPERTIES = [
        :book_title,
        :book_series_title,
        :isbn,
        :eisbn,
        :journal_title,
        :journal_isoabbrev_title,
        :issn,
        :eissn,
        :article_title,
        :conference_title,
        :contributors,
        :doi,
        :url,
        :publisher,
        :volume,
        :issue,
        :pagination,
        :publication_date
      ].freeze

      Contributor = Struct.new(:given_name, :surname, :contributor_role, :sequence)

      # Default readers for all PROPERTIES
      attr_reader :str, *PROPERTIES

      # Params:
      # +str+:: +String+ XML String
      def initialize(str)
        @str = str
      end

      def journal?
        raise NotImplementedError
      end

      def journal_article?
        raise NotImplementedError
      end

      def book?
        raise NotImplementedError
      end

      def book_series?
        raise NotImplementedError
      end

      def authors
        contributors.select {|c| c.contributor_role == 'author'}
      end

      def editors
        contributors.select {|c| c.contributor_role == 'editor'}
      end

      def contributors
        @contributors ||= []
      end

      # Return all properties as a Hash
      def to_hash
        hash = {}
        PROPERTIES.each { |property| hash[property] = send property }
        # Array of Struct needs additional handling
        hash[:contributors] = @contributors.map(&:to_h)
        hash
      end
    end
  end
end
