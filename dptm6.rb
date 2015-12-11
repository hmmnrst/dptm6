require 'zlib'
require './pdf'

class CLI
  def initialize(args)
    @options = { :compression_level => Zlib::DEFAULT_COMPRESSION, :optimization_level => 1 }
    @files = []

    args = args.dup
    while (arg = args.shift)
      case arg
      when /\A-C(\d++)?/   # compression level
        @options[:compression_level] = ($~[1] || Zlib::DEFAULT_COMPRESSION).to_i
      when /\A-O(\d?+)/   # optimization level
        @options[:optimization_level] = ($~[1] || 1).to_i
      when /\A-o/   # output file name
        @options[:outfile] = args.shift
      when /\A-h/i
        @options[:help] = true
      else
        file = arg.sub(/\[([^\[\]]*+)\]\z/, "")
        str = ($~ ? $~[1] : "0..-1")
        pages = str.gsub("\s", "").split(",").collect do |range|
          md = range.match(/\A(-?+\d++)(?:(-|..|...)(-?+\d++))?+\z/)
          raise "invalid page specification: [#{range}]" unless md

          p1 = md[1].to_i
          p2 = (md[3] || p1).to_i
          case md[2]
          when "..." then p1...p2
          else            p1..p2
          end
        end
        @files << [file, pages]
      end
    end
  end

  def exec
    if (@options[:help] || @files.empty?)
      put_help
      return
    end

    clevs = [:NO_COMPRESSION, :BEST_SPEED, :BEST_COMPRESSION, :DEFAULT_COMPRESSION].inject({}) do |hash,name|
      hash[Zlib.const_get(name)] = name
      hash
    end
    clev = @options[:compression_level]
    clev = Zlib::DEFAULT_COMPRESSION unless (0..9).include?(clev)
    STDERR.puts("#compression level : #{clevs[clev] || clev}")

    optlev = @options[:optimization_level]
    STDERR.puts("#optimization flag : #{optlev != 0}")

    outfile = @options[:outfile] || find_nextfile(@files[0][0])
    STDERR.puts("#output file name  : #{outfile}")

    pdf2 = PDF::File.create(outfile)
    head = nil

    @files.each do |file,pages|
      pdf = PDF::File.open(file)
      unless head
        head = pdf.get_object(0)
        head.move_to(pdf2, 0).write
      end

      n = pdf.pages.size
      pages.each do |range|
        first = range.first % n
        last  = range.last  % n
        inc = (first <= last ? 1 : -1)
        last -= inc if range.exclude_end?

        first.step(last, inc) do |i|
          STDERR.puts("processing #{file}[#{i}]")
          image = pdf.get_dclimage(i)
          image.set_deflevel(clev)
          image.parse if (optlev > 0)
          image.move_to(pdf2, nil)
          image.write
        end
      end
      pdf.close
    end

    pdf2.write_info
    pdf2.write_xref
    pdf2.close
  end

  def find_nextfile(basefile)
    pos = basefile.rindex(".pdf")
    file = nil
    (1..99).each do |i|
      file = basefile.dup.insert(pos, "_#{i}")
      return file unless File.exist?(file)
    end
    raise "failed to create a new filename.  (last candidate: #{file})"
  end

  def put_help
    STDERR.puts(<<-EOS)
usage: ruby #{File.basename(__FILE__)} [-C[n]] [-O[n]] [-o output.pdf] input.pdf...

       options
       -C[n] : compression level
               0      : NO_COMPRESSION
               1 - 9  : BEST_SPEED - BEST_COMPRESSION
               others : DEFAULT_COMPRESSION (default)
       -O[n] : optimization flag
               0      : off
               others : on (default)
       -o output.pdf : output filename
               If not specified, "input_%d.pdf" is used instead.

       input files
               Filenames can have page specifications.
               example: input.pdf[0,5...2,8..-1]   #=> [0,5,4,3,8,9,...,n-1]
    EOS
  end
end


if ($0 == __FILE__)
  CLI.new(ARGV).exec
end
