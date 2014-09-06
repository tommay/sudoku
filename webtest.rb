#!/usr/bin/env ruby

require "rubygems"
require "net/http"

require_relative "sudoku.rb"

def main
  (1..10).each do |number|
    page = get_page("http://view.websudoku.com/?level=4&set_id=#{number}")
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

main
