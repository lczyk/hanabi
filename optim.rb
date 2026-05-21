#!/usr/bin/env ruby
# hanabi pattern optimiser
# usage: ruby optim.rb [--iter N] [--help] <file.hnb>
# reads .hnb, repacks dots into smaller (h*w) grid, prints result to stdout.
# progress goes to stderr.

require 'optparse'

HELP = <<~TXT
  hanabi pattern optimiser

  usage: ruby optim.rb [--iter N] <file.hnb>

  reads a .hnb program, repacks dots into a smaller grid while preserving
  semantics (opcode tuples + execution order), prints optimised grid to stdout.

  algorithm: greedy placer with randomised candidate order + backtracking.
  runs up to --iter random restarts, keeps best (h*w) area found.

  options:
    --iter N         max restart iterations (default 100)
    --stagnation N   stop after N iters w/out improvement (default 50)
    --bt-limit N     backtracking recursion cap per pack (default 500)
    --seed N         base RNG seed (default: iter index)
    --verbose        log every iter, not every 5th
    --help           show this help
TXT

# ---------- parse input ----------

def parse_dot_strict(grid, h, w, r, c)
  l = 0; x = c - 1
  while x >= 0 && grid[r][x] == ' '; l += 1; x -= 1; end
  raise "syntax error at (#{r},#{c}) left" if x < 0
  rr = 0; x = c + 1
  while x < w && grid[r][x] == ' '; rr += 1; x += 1; end
  raise "syntax error at (#{r},#{c}) right" if x >= w
  u = 0; y = r - 1
  while y >= 0 && grid[y][c] == ' '; u += 1; y -= 1; end
  raise "syntax error at (#{r},#{c}) up" if y < 0
  d = 0; y = r + 1
  while y < h && grid[y][c] == ' '; d += 1; y += 1; end
  raise "syntax error at (#{r},#{c}) down" if y >= h
  [u, d, l, rr]
end

def parse_hnb(src)
  lines = src.split("\n", -1)
  h = lines.size
  w = lines.map(&:length).max || 0
  grid = Array.new(h) do |r|
    line = lines[r]
    Array.new(w) { |c| c < line.length ? line[c] : ' ' }
  end
  ops = []
  h.times do |r|
    w.times do |c|
      ops << parse_dot_strict(grid, h, w, r, c) if grid[r][c] == '.'
    end
  end
  ops
end

# ---------- layout state ----------

class Layout
  attr_reader :cells
  def initialize
    @cells = {}  # [r,c] => :n / :s / :d
  end

  def copy
    nl = Layout.new
    nl.instance_variable_set(:@cells, @cells.dup)
    nl
  end

  def set(r, c, k)
    cur = @cells[[r, c]]
    if cur.nil?
      @cells[[r, c]] = k
      return true
    end
    case k
    when :s
      return cur == :s
    when :n
      return cur != :s
    when :d
      return false if cur == :s
      @cells[[r, c]] = :d if cur != :d
      return true
    end
  end

  def try_place(r, c, op)
    return false if r < 0 || c < 0
    u, d, l, rr = op
    needed = []
    needed << [r, c, :d]
    needed << [r - u - 1, c, :n]
    needed << [r + d + 1, c, :n]
    needed << [r, c - l - 1, :n]
    needed << [r, c + rr + 1, :n]
    (1..u).each { |k| needed << [r - k, c, :s] }
    (1..d).each { |k| needed << [r + k, c, :s] }
    (1..l).each { |k| needed << [r, c - k, :s] }
    (1..rr).each { |k| needed << [r, c + k, :s] }
    return false if needed.any? { |cr, cc, _| cr < 0 || cc < 0 }
    snapshot = @cells.dup
    needed.each do |cr, cc, k|
      unless set(cr, cc, k)
        @cells = snapshot
        return false
      end
    end
    true
  end

  def bounds
    return [0, 0] if @cells.empty?
    rs = @cells.keys.map(&:first)
    cs = @cells.keys.map(&:last)
    [rs.max + 1, cs.max + 1]
  end

  def area
    h, w = bounds
    h * w
  end

  def render
    h, w = bounds
    g = Array.new(h) { Array.new(w, ' ') }
    @cells.each do |(r, c), k|
      g[r][c] = (k == :d ? '.' : '#') if k == :d || (k == :n && g[r][c] == ' ')
    end
    g.map { |row| row.join.rstrip }.join("\n") + "\n"
  end
end

# ---------- fast heuristic: single-column tight pack ----------

# always-valid layout: each op gets its own row, all dots in one column.
# uses shared '#' markers between adjacent ops. width = max_L + 1 + max_R + 2.
def fast_pack(ops)
  layout = Layout.new
  max_l = ops.map { |_, _, l, _| l }.max
  dot_col = max_l + 1
  prev_end = 0
  layout.set(0, dot_col, :n)
  ops.each do |u, d, l, r|
    dot_row = prev_end + u + 1
    end_row = dot_row + d + 1
    layout.set(dot_row, dot_col, :d)
    layout.set(end_row, dot_col, :n)
    layout.set(dot_row, dot_col - l - 1, :n)
    layout.set(dot_row, dot_col + r + 1, :n)
    (1..u).each { |k| layout.set(dot_row - k, dot_col, :s) }
    (1..d).each { |k| layout.set(dot_row + k, dot_col, :s) }
    (1..l).each { |k| layout.set(dot_row, dot_col - k, :s) }
    (1..r).each { |k| layout.set(dot_row, dot_col + k, :s) }
    prev_end = end_row
  end
  layout
end

# ---------- placer ----------

def candidate_positions(prev_r, prev_c, op, max_h, max_w)
  u, _d, l, _r = op
  out = []
  # extend same row
  if prev_r >= 0
    (prev_c + 1..max_w - 1).each do |c|
      next if c - l - 1 < 0
      out << [prev_r, c]
    end
  end
  # new rows below
  min_new_r = [prev_r + 1, u + 1].max
  (min_new_r..max_h - 1).each do |r|
    (l + 1..max_w - 1).each do |c|
      out << [r, c]
    end
  end
  out
end

$bt_calls = 0
$bt_limit = 500

def pack_recur(ops, idx, prev_r, prev_c, layout, rng, area_budget)
  return layout if idx == ops.size
  $bt_calls += 1
  $deepest = idx if idx > $deepest
  return nil if $bt_calls > $bt_limit
  op = ops[idx]
  h, w = layout.bounds
  # constrain max bounds: existing bounds + small growth, capped by budget shape
  sqb = Math.sqrt(area_budget).ceil
  max_h = [h + 3, sqb + 2].min
  max_h = h + 3 if max_h < h + 1
  max_w = area_budget / [h, 1].max + 2
  max_w = [max_w, w + 3].max
  cands = candidate_positions(prev_r, prev_c, op, max_h, max_w)
  $cands_total += cands.size
  cands.sort_by! { |r, c| [r, c] }
  if rng && cands.size > 4
    head_n = 6
    head = cands.first(head_n).shuffle(random: rng)
    cands = head + cands.drop(head_n)
  end
  cands.each do |r, c|
    saved = layout.cells.dup
    next unless layout.try_place(r, c, op)
    h2, w2 = layout.bounds
    if h2 * w2 >= area_budget
      layout.instance_variable_set(:@cells, saved)
      next
    end
    result = pack_recur(ops, idx + 1, r, c, layout, rng, area_budget)
    return result if result
    layout.instance_variable_set(:@cells, saved)
  end
  nil
end

def pack(ops, rng, area_budget)
  $bt_calls = 0
  $deepest = 0
  $cands_total = 0
  layout = Layout.new
  result = pack_recur(ops, 0, -1, -1, layout, rng, area_budget)
  [result, $bt_calls, $deepest, $cands_total]
end

# ---------- main ----------

opts = { iter: 100, stagnation: 50, bt_limit: 500, seed: nil, verbose: false }
parser = OptionParser.new do |o|
  o.on('--iter N', Integer) { |v| opts[:iter] = v }
  o.on('--stagnation N', Integer) { |v| opts[:stagnation] = v }
  o.on('--bt-limit N', Integer) { |v| opts[:bt_limit] = v }
  o.on('--seed N', Integer) { |v| opts[:seed] = v }
  o.on('--verbose') { opts[:verbose] = true }
  o.on('--help') { puts HELP; exit 0 }
end
parser.parse!(ARGV)
$bt_limit = opts[:bt_limit]

if ARGV.empty?
  warn HELP
  exit 1
end

src = File.read(ARGV[0])
ops = parse_hnb(src)

orig_lines = src.split("\n", -1)
orig_h = orig_lines.size
orig_w = orig_lines.map(&:length).max || 0
orig_area = orig_h * orig_w
warn "input: #{ops.size} ops, original #{orig_h}x#{orig_w} = #{orig_area}"

best = fast_pack(ops)
best_area = best.area
h, w = best.bounds
warn "fast heuristic: #{h}x#{w} = #{best_area} (#{(100.0 * best_area / orig_area).round(1)}% of original)"

finalize = lambda do |*_args|
  if best
    h, w = best.bounds
    warn "final: #{h}x#{w} = #{best_area} (#{(100.0 * best_area / orig_area).round(1)}% of original)"
    print best.render
  else
    warn "no improvement found"
    print src
  end
  exit 0
end
trap('INT', &finalize)
trap('TERM', &finalize)

last_improve = 0
total_t0 = Time.now
opts[:iter].times do |i|
  if i - last_improve >= opts[:stagnation]
    warn "no progress in #{opts[:stagnation]} iterations; stopping"
    break
  end
  seed = opts[:seed] ? opts[:seed] + i : i
  rng = (i == 0 && opts[:seed].nil? ? nil : Random.new(seed))
  t0 = Time.now
  layout, bt_calls, deepest, cands_total = pack(ops, rng, best_area - 1)
  dt = Time.now - t0
  log_step = opts[:verbose] ? 1 : 5
  if layout
    a = layout.area
    if a < best_area
      best_area = a
      best = layout
      last_improve = i
      h, w = layout.bounds
      warn "iter #{i}: improved to #{h}x#{w} = #{a} (bt=#{bt_calls} cands=#{cands_total} #{(dt*1000).round}ms)"
    elsif i % log_step == 0
      warn "iter #{i}: found area=#{a} >= best=#{best_area} (bt=#{bt_calls} deepest=#{deepest}/#{ops.size} cands=#{cands_total} #{(dt*1000).round}ms)"
    end
  elsif i % log_step == 0
    warn "iter #{i}: pack failed budget<#{best_area} bt=#{bt_calls} deepest=#{deepest}/#{ops.size} cands=#{cands_total} #{(dt*1000).round}ms"
  end
end
warn "elapsed #{(Time.now - total_t0).round(2)}s"

finalize.call
