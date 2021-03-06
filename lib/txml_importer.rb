require 'txml_importer/version'
require 'xml'
require 'open-uri'
require 'pretty_strings'
require 'charlock_holmes'

module TxmlImporter
  class Txml
    attr_reader :file_path, :encoding
    def initialize(file_path:, **args)
      @file_path = file_path
      @content = File.read(open(@file_path)) if !args[:encoding].eql?('UTF-8')
      if args[:encoding].nil?
        @encoding = CharlockHolmes::EncodingDetector.detect(@content[0..100_000])[:encoding]
        if @encoding.nil?
          encoding_in_file = @content.dup.force_encoding('utf-8').scrub!("*").gsub!(/\0/, '').scan(/(?<=encoding=").*(?=")/)[0].upcase
          if encoding_in_file.eql?('UTF-8')
            @encoding = ('UTF-8')
          elsif encoding_in_file.eql?('UTF-16')
            @encoding = ('UTF-16LE')
          end
        end
      else
        @encoding = args[:encoding].upcase
      end
      @doc = {
        source_language: "",
        tu: { id: "", counter: 0, vals: [] },
        seg: { counter: 0, vals: [] },
        language_pairs: []
      }
      raise "Encoding type could not be determined. Please set an encoding of UTF-8, UTF-16LE, or UTF-16BE" if @encoding.nil?
      raise "Encoding type not supported. Please choose an encoding of UTF-8, UTF-16LE, or UTF-16BE" unless @encoding.eql?('UTF-8') || @encoding.eql?('UTF-16LE') || @encoding.eql?('UTF-16BE')
      @text = CharlockHolmes::Converter.convert(@content, @encoding, 'UTF-8') if !@encoding.eql?('UTF-8')
    end

    def stats
      if encoding.eql?('UTF-8')
        analyze_stats_utf_8
      else
        analyze_stats_utf_16
      end
      {tu_count: @doc[:tu][:counter], seg_count: @doc[:seg][:counter], language_pairs: @doc[:language_pairs].uniq}
    end

    def import
      reader = read_file
      parse_file(reader)
      [@doc[:tu][:vals], @doc[:seg][:vals]]
    end

    private

    def analyze_stats_utf_8
      File.readlines(@file_path).each do |line|
        analyze_line(line)
      end
    end

    def analyze_stats_utf_16
      @text.each_line do |line|
        analyze_line(line)
      end
    end

    def read_file
      if encoding.eql?('UTF-8')
        XML::Reader.io(open(file_path), options: XML::Parser::Options::NOERROR, encoding: XML::Encoding::UTF_8)
      else
        reader = @text.gsub(/(?<=encoding=").*(?=")/, 'utf-8').gsub(/&#x[0-1]?[0-9a-fA-F];/, ' ').gsub(/[\0-\x1f\x7f\u2028]/, ' ')
        XML::Reader.string(reader, options: XML::Parser::Options::NOERROR, encoding: XML::Encoding::UTF_8)
      end
    end

    def analyze_line(line)
      @doc[:source_language] = line.scan(/(?<=locale=\S)\S+(?=")/)[0] if line.include?('locale=') && !line.scan(/(?<=locale=\S)\S+(?=")/).empty?
      @doc[:source_language] = line.scan(/(?<=locale=\S)\S+(?=')/)[0] if line.include?('locale=') && !line.scan(/(?<=locale=\S)\S+(?=')/).empty?
      @doc[:target_language] = line.scan(/(?<=targetlocale=\S)\S+(?=")/)[0] if line.include?('targetlocale=') && !line.scan(/(?<=targetlocale=\S)\S+(?=")/).empty?
      @doc[:target_language] = line.scan(/(?<=targetlocale=\S)\S+(?=')/)[0] if line.include?('targetlocale=') && !line.scan(/(?<=targetlocale=\S)\S+(?=')/).empty?
      @doc[:tu][:counter] += line.scan(/<\/segment>/).count
      @doc[:seg][:counter] += (line.scan(/<\/source>/).count + line.scan(/<\/target>/).count - line.scan(/<\/target><\/revision>/).count)
      @doc[:language_pairs] << [@doc[:source_language], @doc[:target_language]] if !@doc[:source_language].empty? && !@doc[:source_language].nil? && !@doc[:target_language].empty? && !@doc[:target_language].nil?
    end

    def parse_file(reader)
      last_tag = ''
      @count = 0
      while reader.read do
        unless last_tag.bytes.to_a.eql?([114, 101, 118, 105, 115, 105, 111, 110])
          case reader.name.bytes.to_a
          when [116, 120, 109, 108]
            @doc[:source_language] = reader.get_attribute("locale") if reader.has_attributes? && reader.get_attribute("locale")
            @doc[:target_language] = reader.get_attribute("targetlocale") if reader.has_attributes? && reader.get_attribute("targetlocale")
          when [115, 101, 103, 109, 101, 110, 116]
            generate_unique_id if @count % 2 == 0
            write_tu(reader) if @count % 2 == 0
            @count += 1
          when [115, 111, 117, 114, 99, 101]
            write_seg(reader, 'source')
          when [116, 97, 114, 103, 101, 116]
            write_seg(reader, 'target')
          end
        end
        last_tag = reader.name
      end
      reader.close
    end

    def write_tu(reader)
      @doc[:tu][:vals] << [@doc[:tu][:id]]
    end

    def write_seg(reader, role)
      return if reader.read_string.nil?
      text = PrettyStrings::Cleaner.new(reader.read_string).pretty.gsub("\\","&#92;").gsub("'",%q(\\\'))
      return if text.nil? || text.empty?
      word_count = text.gsub("\s+", ' ').split(' ').length
      if role.eql?('source')
        language = @doc[:source_language]
      else
        language = @doc[:target_language]
      end
      @doc[:seg][:vals] << [@doc[:tu][:id], role, word_count, language, text]
    end

    def generate_unique_id
      @doc[:tu][:id] = [(1..4).map{rand(10)}.join(''), Time.now.to_i, @doc[:tu][:counter] += 1 ].join("-")
    end
  end
end
