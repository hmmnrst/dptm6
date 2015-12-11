class Path
  class Node
    attr_reader :x, :y, :op
    attr_accessor :prev, :next

    def initialize(x, y, op)
      @x = x.to_f
      @y = y.to_f
      @op = op.to_sym
    end

    def connect(next_node)
      self.next = next_node
      next_node.prev = self
      self
    end

    def reconnect(opp_node)
      # assume that self.x == opp_node.x && self.y == opp_node.y
      if (self.next.x == opp_node.prev.x && self.next.y == opp_node.prev.y)
        opp_node.prev.connect(self.next)
        self.connect(opp_node)
        self
      else
        nil
      end
    end

    def output(op = @op)
      @op = nil
      "%g %g %s " % [@x, @y, op]
    end
  end

  def initialize(nodes = [])
    @nodes = nodes
  end

  def add(buf_node)
    (buf_node << buf_node[0]).each_cons(2) { |a,b| @nodes << a.connect(b) } if (buf_node.length >= 2)
  end

  def optimize
    return self unless @nodes

    # reconnect nodes (total number of nodes is not changed)
    @nodes.group_by(&:y).each do |y,nodes|
      nodes.group_by(&:x).each do |x,buf|
        while (n1 = buf.pop)
          buf.each { |n2| break if n1.reconnect(n2) }
        end
      end
    end

    # remove needless nodes
    @nodes.reject! do |node|
      d1x = node.prev.x - node.x
      d1y = node.prev.y - node.y
      d2x = node.next.x - node.x
      d2y = node.next.y - node.y
      if (d1x * d2y == d2x * d1y)
        node.prev.connect(node.next)
        true
      else
        false
      end
    end

    self
  end

  def output_fill(buf = '')
    return buf if (@nodes.length < 2)
    buf << "\n" unless (buf[-1] == "\n")
    nodes = @nodes.dup
    while (node0 = node = nodes.shift)
      next unless node.op
      buf << node.output(:m)
      until ((node = node.next) == node0)
        buf << node.output(:l)
      end
      buf << "h\n"
    end
    buf << "B\n"
  end

  def output_stroke(buf = '', close = false)
    return buf if (@nodes.length < 1)
    @nodes.each { |node| buf << node.output }
    buf << "h " if close
    buf << "S\n"
  end
end
