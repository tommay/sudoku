#!/usr/bin/env ruby

require "rubygems"
require "net/http"

require_relative "sudoku.rb"

def main(argv)
  level = if argv.first =~ /^-(.)$/
    argv.shift
    case $1
    when "e", "1"
      1
    when "m", "2"
      2
    when "h", "3"
      3
    when "v", "4"
      4
    else
      usage
    end
  else
    4
  end

  range = case argv.size
  when 1
    (argv[0].to_i .. argv[0].to_i)
  when 2
    (argv[0].to_i .. argv[1].to_i)
  else
    usage
  end

  range.each do |number|
    page = get_page("http://view.websudoku.com/?level=#{level}&set_id=#{number}")
    if page == nil
      puts "Skipping page #{page_number}"
      next
    end

    # "cheat" is the solution

    page =~ %r{cheat='([1-9]*)'}
    cheat = $1

    # "editmask" has a "0" for each fixed value

    page =~ %r{<input id="editmask" [^>]* value="([01]*)">}i
    editmask = $1

    init = cheat.scan(/./).zip(editmask.scan(/./)).map do |value, editable|
      editable == "1" ? "-" : value
    end.join

    puts "#{Puzzle.new(setup: init).solve} solutions"
  end
end

def usage
  puts <<END
usage: #{$0} [-e|m|h|e] start [stop]
  Where -e, -m, -h, -v selects easy, hard, medium, or evil difficulty.
  The numbers -1, -2, -3, and -4 may also be used.
  The default is -v/-4, evil.
  start is the number of the sudoku puzzle to solve.
  If stop is given, the puzzles in the range start..stop are solved.
END
  exit(1)
end

def get_page(page)
  3.times do
    puts "Fetching #{page}"
    begin
      response = Net::HTTP.get_response(URI.parse(page))
      case response
      when Net::HTTPOK
        return response.body.to_s
      when Net::HTTPNotFound
        return nil
      when Net::HTTPRedirection
        return get_page(response['Location'])
      else
        puts "HTTP problem: #{page}: #{response.code} #{response.message}"
      end
    rescue => ex
      puts "HTTP problem: #{page}: #{ex.inspect}"
    end
  end
  nil
end

main(ARGV)
