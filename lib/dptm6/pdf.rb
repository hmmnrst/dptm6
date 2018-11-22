require 'zlib'
require 'dptm6/path'

module DPTM6; module PDF
  REGEXP_DATA = /\A(?:(?'dict'<<(?>\g'dict'|[^<>]++)*+>>\s*+)|(?'num'\s*\d+\s*+))/m

  class File
    attr_reader :fp, :trailer
    attr_accessor :xref, :pages
    private_class_method :new

    @@obj0_pages = nil
    @@obj0_info  = nil
    @@obj0_root  = nil

    def self.open(file)
      new(file, "rb")
    end

    def self.create(file)
      new(file, "wb")
    end

    def initialize(file, mode)
      @fp = Kernel.open(file, mode)

      if (mode[0] == "r")
        read_xref
        read_info
      else
        @xref = []
        @pages = []
      end
    end

    def close
      @fp.close
    end

    def get_dclimage(num)
      PDF::DCLImage.new(self, num)
    end

    def get_object(num, type = PDF::Object)
      type.new(self, num)
    end

    def get_object_by_key(dict, key, type = PDF::Object)
      ary = dict.scan(/#{key}\s++(\d++)\s++\d++\s++R/m)
      return nil if ary.empty?

      num = ary[0][0].to_i
      get_object(num, type)
    end

    def write_info
      str = @pages.collect { |i| "#{i} 0 R " }.join
      @@obj0_pages.data[/\/Kids\s++\[\s++([\d\sR]++)\]/,1] = str
      @@obj0_pages.data[/\/Count\s++(\d++)/,1] = @pages.size.to_s
      @@obj0_pages.move_to(self, 1).write

      @@obj0_info.move_to(self, @xref.size).write

      @@obj0_root.move_to(self, @xref.size).write
    end

    def write_xref
      pos = @fp.pos
      size = @xref.size

      @fp.write("xref\n")
      @fp.write("#{0} #{size}\n")
      @xref.sort_by(&:last).each do |i,j,k|
        @fp.write("%010d %05d %c \n" % (k == 0 ? [i, 65535, "f"] : [i, 0, "n"]))
      end

      @fp.write(<<-EOS)
trailer
<< /Size #{size}
   /Root #{size-1} 0 R
   /Info #{size-2} 0 R
>>
      EOS

      @fp.write(<<-EOS)
startxref
#{pos}
%%EOF
      EOS
    end

    private

    def read_xref
      @fp.pos = @fp.size - 40
      str = @fp.read
      pos_xref = str[/startxref\s++(\d++)/m,1].to_i

      # get beginning positions of objects
      @fp.pos = pos_xref
      str = @fp.gets.chomp!
      if (str != "xref")
        raise "invalid data (expected 'xref')"
      end
      a, b, = @fp.gets.split.collect(&:to_i)
      pos_obj = b.times.collect { @fp.gets.split[0].to_i }

      # get ending positions of objects
      tmp = pos_obj.each_with_index.sort_by(&:first) << [pos_xref, b]
      tmp = tmp.each_cons(2).collect { |a,b| [a[0], b[0] - a[0], a[1]] }
      @xref = tmp.sort_by(&:last)

      @fp.gets
      @trailer = @fp.read.slice(PDF::REGEXP_DATA)
    end

    def read_info
      @obj_root  = get_object_by_key(@trailer, '/Root')
      @obj_info  = get_object_by_key(@trailer, '/Info')
      @obj_pages = get_object_by_key(@obj_root.data, '/Pages')
      @@obj0_root  ||= @obj_root
      @@obj0_info  ||= @obj_info
      @@obj0_pages ||= @obj_pages

      str = @obj_pages.data[/\/Kids\s++\[\s++([\d\sR]++)\]/m,1]   #=> (\d+ 0 R )*
      @pages = str.scan(/(\d++)\s++(\d++)\s++(R)/).collect { |a| a[0].to_i }
    end
  end

  class Object
    attr_reader :pdf, :num
    attr_accessor :data

    def initialize(pdf, num)
      @pdf = pdf
      @num = num
      read
    end

    def to_string
      return @data if (@num == 0 && @data =~ /%PDF/)

      "#{@num} #{0} obj\n" << @data << "endobj\n"
    end

    def move_to(pdf, num)
      @pdf = pdf
      @num = num
      self
    end

    def write
      fp = @pdf.fp
      pos = fp.pos
      fp.write(to_string)
      len = fp.pos - pos
      @pdf.xref << [pos, len, @num]
    end

    def replace_pagenum(hash)
      hash.each do |key,num|
        @data[/#{key}\s++(\d++)\s++\d++\s++R/,1] = num.to_s
      end
    end

    private

    def read
      fp = @pdf.fp
      pos, len, = @pdf.xref[@num]

      fp.pos = pos
      buf = fp.read(len)

      if (buf =~ /\A%PDF/)
        @data = buf
        return
      end

      buf.slice!(/\A[^\n]++\n/m)
      @data = buf.slice!(PDF::REGEXP_DATA)
    end
  end

  class PageObject < Object
    def to_string
      replace_pagenum('/Contents'  => @obj_content.num,
                      '/Resources' => @obj_resource.num)
      super
    end

    def write
      @pdf.pages << @num
      super
    end

    private

    def read
      super
      @obj_content  = @pdf.get_object_by_key(@data, '/Contents' , PDF::StreamObject  )
      @obj_resource = @pdf.get_object_by_key(@data, '/Resources', PDF::ResourceObject)
    end
  end

  class ResourceObject < Object
    attr_reader :x_objects

    def to_string
      unless @x_objects.empty?
        ary = @x_objects.collect { |key,obj| "#{key} #{obj.num} 0 R" }
        @data[/\/XObject\s++(<<[^<>]*+>>)/,1] = "<< #{ary.join(' ')} >>"
      end
      super
    end

    private

    def read
      super
      # /XObject << /x5 5 0 R /x6 6 0 R >>
      @x_objects = {}
      if (@data =~ /\/XObject\s++<<([^<>]++)>>/m)
        $~[1].scan(/(\/\w++)\s++(\d++)\s++(\d++)\s++(R)/) do |a|
          @x_objects[a[0]] = @pdf.get_object(a[1].to_i, PDF::StreamObject)
        end
      end
    end
  end

  class StreamObject < Object
    attr_reader :obj_length

    def set_deflevel(level)
      @def_level = level if @stream
    end

    def stream
      Zlib.inflate(@stream)
    end

    def stream=(str)
      @stream = Zlib.deflate(str, @def_level)
    end

    def to_string
      replace_pagenum('/Length' => @obj_length.num)

      buf = "#{@num} #{0} obj\n"
      buf << @data
      if @stream
        @obj_length.data = "   #{@stream.length}\n"
        buf << "stream\n" << @stream << "\nendstream\n"
      end
      buf << "endobj\n"
    end

    def write
      super
      @obj_length.write
    end

    private

    def read
      fp = @pdf.fp
      pos, len, = @pdf.xref[@num]

      fp.pos = pos
      buf = fp.read(len)

      buf.slice!(/\A[^\n]++\n/m)
      @data = buf.slice!(PDF::REGEXP_DATA)

      @obj_length = @pdf.get_object_by_key(@data, '/Length')
      length = @obj_length.data.to_i

      if @data.include?("/FlateDecode")
        buf.slice!(/\A[^\n]++\n/m)   #=> "stream\n"
        @stream = buf[0,length]
        @def_level = Zlib::DEFAULT_COMPRESSION
      end
    end
  end

  class DCLImage < PageObject
    def initialize(pdf, num)
      super(pdf, pdf.pages[num])
    end

    def move_to(pdf, num)
      # OBJECT / NUMBER
      # psimage   +1
      #   length  +2
      # resource  +0
      # page      +3+nx
      # xobj_i    +3+i
      #   length  +3+nx+1+i
      m = pdf.xref.size + 1
      nx = @obj_resource.x_objects.size
      @obj_content.           move_to(pdf, m + 1)
      @obj_content.obj_length.move_to(pdf, m + 2)
      @obj_resource.          move_to(pdf, m    )
      super(pdf, m + 3 + nx)
      @obj_resource.x_objects.each_with_index do |(key,obj),i|
        obj.           move_to(pdf, m + 3      + i)
        obj.obj_length.move_to(pdf, m + 4 + nx + i)
      end
      self
    end

    def set_deflevel(level)
      @obj_content.set_deflevel(level)
    end

    def write
      @obj_content. write
      @obj_resource.write
      super
      @obj_resource.x_objects.each_value(&:write)
    end

    REGEXP_PARSE = Regexp.compile('(?:(\[[^\[\]]*+\])\s++)?+'           <<   # array
                                  '(?:(-?+\d++(?:\.\d++)?+)\s++)?+' * 6 <<   # numbers
                                  '(?:(/\w++)\s++)?+'                   <<   # set ExtGState parameters ("'/a0 'gs ")
                                  '(\w++)\s++'                          <<   # operator (required)
                                  '((?:/\w++\s++\w++\s++){2})?+'         )   # draw XObject ("... cm '/a0 gs /x5 Do '")
    def parse
      stream_new = "q\n"

      # previous values
      concat = nil
      color  = { :rg => nil, :RG => nil }
      flag_x = false

      buf_node = []
      path = Path.new
      str_check = @obj_content.stream.gsub(REGEXP_PARSE) do |a|
        md = $~
        op = md[-2].to_sym
        case op
        when :m, :l   # moveto, lineto
          buf_node << Path::Node.new(md[2], md[3], op)
        when :h, :B   # close, fill and stroke
          if flag_x   # frame of XObject
            flag_x = false
            Path.new(buf_node).output_stroke(stream_new, true)
            path = Path.new
          else
            path.add(buf_node)
          end
          buf_node = []
        when :S   # stroke
          path.optimize.output_fill(stream_new)
          path = Path.new
          Path.new(buf_node).output_stroke(stream_new)
          buf_node = []
        when :rg, :RG   # set RGB for stroking / non-stroking
          rgbstr = md[2..4].join(' ')
          if (rgbstr == color[op])
          else
            path.optimize.output_fill(stream_new)
            path = Path.new
            color[op] = rgbstr
            stream_new << a
          end
        when :cm   # concat matrix
          if md[-1]   # insert XObject
            flag_x = true
            stream_new << "q\n"
            stream_new << "0 1 1 0 -842 0 cm\n" if concat   # cancel concat matrix for paths
            stream_new << a << "Q\n"
          else
            stream_new << "q " << (concat = a) unless concat
          end
        when :q, :Q   # gsave, grestore
        else   # others : copy
          stream_new << a
        end
        ''   # delete parsed string
      end
      STDERR.puts("WARNING: Some script could not be parsed -- #{str_check.inspect}") if (str_check != '')

      stream_new << "Q\n"
      @obj_content.stream = stream_new
      self
    end
  end
end; end
