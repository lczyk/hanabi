#!/usr/bin/env ruby
# hanabi interpreter
# usage: ruby hanabi.rb <file.hnb>

class Hanabi
  def initialize(src)
    @lines = src.split("\n", -1)
    @h = @lines.size
    @w = @lines.map(&:length).max || 0
    @grid = Array.new(@h) do |r|
      line = @lines[r]
      Array.new(@w) { |c| c < line.length ? line[c] : ' ' }
    end
    @dots = []
    @h.times do |r|
      @w.times do |c|
        @dots << parse_dot(r, c) if @grid[r][c] == '.'
      end
    end
    @labels = {}
    @dots.each_with_index do |d, i|
      u, dd, l, rr = d[:ws]
      @labels[dd] = i if u == 3 && l == 0 && rr == 0
    end
    @stack = []
  end

  def ws?(ch)
    ch == ' ' || ch == "\t"
  end

  def parse_dot(r, c)
    l = 0
    x = c - 1
    while x >= 0 && ws?(@grid[r][x]); l += 1; x -= 1; end
    raise "syntax error: dot at (#{r},#{c}) has no non-whitespace to the left" if x < 0
    rr = 0
    x = c + 1
    while x < @w && ws?(@grid[r][x]); rr += 1; x += 1; end
    raise "syntax error: dot at (#{r},#{c}) has no non-whitespace to the right" if x >= @w
    u = 0
    y = r - 1
    while y >= 0 && ws?(@grid[y][c]); u += 1; y -= 1; end
    raise "syntax error: dot at (#{r},#{c}) has no non-whitespace above" if y < 0
    d = 0
    y = r + 1
    while y < @h && ws?(@grid[y][c]); d += 1; y += 1; end
    raise "syntax error: dot at (#{r},#{c}) has no non-whitespace below" if y >= @h
    {r: r, c: c, ws: [u, d, l, rr]}
  end

  def run
    @pc = 0
    while @pc < @dots.size
      execute(*@dots[@pc][:ws])
      @pc += 1
    end
  end

  def pop; @stack.pop; end

  def execute(u, d, l, r)
    case u
    when 0 then exec_push(d, l, r)
    when 1 then exec_out(d, l, r)
    when 2 then exec_calc(d, l, r)
    when 3 then exec_jump(d, l, r)
    else raise "bad opcode u=#{u}"
    end
  end

  def exec_push(d, l, r)
    if l == 0 && r == 0
      @stack.push(d)
    elsif l == 0 && r == 1
      d.to_s.each_char { |ch| @stack.push(ch.ord) }
    elsif d == 0 && l == 0 && r == 2
      b = STDIN.getbyte
      @stack.push(b) if b
    elsif d == 0 && l == 0 && r == 3
      line = STDIN.gets
      @stack.push(line ? line.to_i : 0)
    elsif d == 0 && l == 0 && r == 4
      line = STDIN.gets || ""
      line = line.chomp
      line.each_char { |ch| @stack.push(ch.ord) }
    elsif d == 1 && l == 1 && r == 0
      @stack.push(@stack.size)
    elsif d == 0 && l == 1 && r == 0
      a = @stack.pop; b = @stack.pop; @stack.push(a); @stack.push(b)
    elsif d == 0 && l == 1 && r == 1
      @stack.reverse!
    elsif d == 0 && l == 1 && r >= 2
      top = @stack.pop(r)
      @stack.concat(top.reverse)
    elsif d == 0 && l == 2 && r == 0
      a = @stack.pop; b = @stack.pop; @stack.push(a); @stack.push(b)
    elsif d == 0 && l == 2 && r == 1
      @stack.unshift(@stack.pop) unless @stack.empty?
    elsif d == 0 && l == 2 && r >= 2
      part = @stack.pop(r)
      part.unshift(part.pop)
      @stack.concat(part)
    elsif d == 1 && l == 2 && r == 0
      a = @stack.pop; b = @stack.pop; @stack.push(a); @stack.push(b)
    elsif d == 1 && l == 2 && r == 1
      @stack.push(@stack.shift) unless @stack.empty?
    elsif d == 1 && l == 2 && r >= 2
      part = @stack.pop(r)
      part.push(part.shift)
      @stack.concat(part)
    else
      raise "bad push opcode (0,#{d},#{l},#{r})"
    end
  end

  def exec_out(d, l, r)
    if l == 0 && r == 0
      if d == 0
        print @stack.pop.chr
      elsif d == 1
        print @stack.map(&:chr).join
        @stack.clear
      else
        d.times { print @stack.pop.chr }
      end
    elsif l == 0 && r == 1
      if d == 0
        print @stack.pop.to_s
      elsif d == 1
        print @stack.map(&:to_s).join
        @stack.clear
      else
        d.times { print @stack.pop.to_s }
      end
    elsif d == 0 && l == 0 && r == 2
      puts
    elsif d == 0 && l == 1 && r == 0
      @stack.pop
    elsif d == 0 && l == 1 && r >= 1
      r.times { @stack.pop }
    elsif d == 0 && l == 2 && r == 0
      @stack.clear
    else
      raise "bad out opcode (1,#{d},#{l},#{r})"
    end
  end

  def exec_calc(d, l, r)
    if d == 0 && l == 0 && r == 0
      @stack.push(@stack.last)
    elsif d == 0
      c = l; n = r
      top = @stack.last(n)
      c.times { @stack.concat(top) }
    elsif d == 1
      b = @stack.pop; a = @stack.pop
      res = case [l, r]
        when [0, 0] then a == b ? 1 : 0
        when [1, 1] then a != b ? 1 : 0
        when [1, 0] then a < b ? 1 : 0
        when [2, 0] then a <= b ? 1 : 0
        when [0, 1] then a > b ? 1 : 0
        when [0, 2] then a >= b ? 1 : 0
        else raise "bad cmp (2,1,#{l},#{r})"
      end
      @stack.push(res)
    elsif d == 2
      b = @stack.pop; a = @stack.pop
      case [l, r]
      when [0, 0] then @stack.push(a + b)
      when [0, 1] then @stack.push(a - b)
      when [1, 0] then @stack.push(a * b)
      when [1, 1] then @stack.push(a / b)
      when [2, 0] then @stack.push(a ** b)
      when [2, 1] then @stack.push(Math.log(a, b).to_i)
      when [0, 2] then @stack.push(b == 0 ? a : a % b)  # impl quirk: % 0 -> a
      when [1, 2] then @stack.push(a / b)
      when [2, 2] then q, m = a.divmod(b); @stack.push(q); @stack.push(m)
      else raise "bad arith (2,2,#{l},#{r})"
      end
    elsif d == 3 && l == 0 && r == 0
      n = @stack.pop
      @stack.push(n == 0 ? 1 : 0)
    else
      raise "bad calc opcode (2,#{d},#{l},#{r})"
    end
  end

  def exec_jump(d, l, r)
    if l == 0 && r == 0
      # label marker, noop
    elsif l == 0 && r == 1
      v = @stack.pop
      @pc = @labels[d] if v != 0 && @labels.key?(d)
    elsif l == 1 && r == 0
      v = @stack.pop
      @pc = @labels[d] if v == 0 && @labels.key?(d)
    elsif l == 1 && r == 1
      @pc = @labels[d] if @labels.key?(d)
    else
      raise "bad jump opcode (3,#{d},#{l},#{r})"
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  if ARGV.empty?
    warn "usage: ruby hanabi.rb <file.hnb>"
    exit 1
  end
  src = File.read(ARGV[0])
  Hanabi.new(src).run
end
