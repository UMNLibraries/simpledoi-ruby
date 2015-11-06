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
        :doi,
        :url
      ].freeze

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

      def book?
        raise NotImplementedError
      end

      def book_series?
        raise NotImplementedError
      end

      # Return all properties as a Hash
      def to_hash
        hash = {}
        PROPERTIES.each { |property| hash[property] = send property }
        hash
      end
    end
  end
end
