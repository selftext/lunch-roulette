$:.push "./lib"

require 'csv'
require 'optparse'
require 'yaml'
require 'set'
require 'digest'

require 'lunch_roulette/config'
require 'lunch_roulette/enumerable_extension'
require 'lunch_roulette/lunch'
require 'lunch_roulette/lunch_set'
require 'lunch_roulette/lunch_group'
require 'lunch_roulette/person'
require 'lunch_roulette/survey'
require 'csv_client'
# require 'sheets_client'

class LunchRoulette

  SPREADSHEET_ID = Config.config[:spreadsheet_id]
  SPREADSHEET_URL = Config.config[:spreadsheet_url]
  PEOPLE_RANGE = Config.config[:people_range]
  PEOPLE_OLD_RANGE = Config.config[:people_old_range]
  SURVEY_RANGE = Config.config[:survey_range]

  SURVEY_DATE_FORMAT = Config.config[:survey_date_format]
  PERSON_DATE_FORMAT = Config.config[:person_date_format]
  FILE_DATE_FORMAT = Config.config[:file_date_format]

  SURVEY_TRUE = Config.config[:survey_true]

  ITERATIONS = Config.config[:iterations]

  TIME_NOW = DateTime.now
  PEOPLE_INPUT_FILE = Config.config[:people_input_file]
  PEOPLE_OUTPUT_FILE = Config.config[:people_output_file].split('.csv').first + '_' + TIME_NOW.strftime(FILE_DATE_FORMAT).to_s + '.csv'

  def initialize(*args)
    options = Hash.new

    o = OptionParser.new do |o|
      o.banner = "Usage: ruby lunch_roulette.rb [OPTIONS]"
      o.on('-f', '--file F', 'Offline people input: read people data from provided CSV') { |f| options[:people_file] = f.to_s }
      o.on('-o', '--offline', "Offline output: write timestamped CSV data locally to output directory") { options[:offline] = true }
      o.on('-s', '--survey', 'read survey data from configured Google sheet') { options[:survey] = true }
      o.on('-i', '--iterations I', "Iterations, default #{ITERATIONS}") { |i| options[:iterations] = i.to_i }
      o.on('-v', '--valid', "Stop searching when the first valid set is encountered") { options[:valid] = true }
      o.on('-c', '--concise', "Concise output: suppress stats and previous-lunches printouts") { |c| options[:concise_output] = true }
      o.on('-h', '--help', 'Print this help') { puts o; exit }
      o.parse!
    end

    Config.options = options
  end

  def run!
    begin
      puts "🥑  Devouring delicious data:"
      lunchable_people, unlunchable_people = people.partition(&:lunchable?)

      puts "🥒  Slicing up #{Config.options[:iterations] || ITERATIONS} scrumptious sets:"
      unless lunch_set = spin(lunchable_people, Config.options[:iterations] || ITERATIONS)
        puts "🔪  No lunch sets made the cut!"
        return
      end
      puts "🍇  We have a winner! Set ##{lunch_set.id} is born, with #{lunch_set.groups.size} great groups"

      puts "🐓  Plating palatable previous groups:\n#{lunch_set.inspect_previous_groups}" unless Config.options[:concise_output]
      puts "🌮  Sautéing savory scores:\n#{lunch_set.inspect_scores}" unless Config.options[:concise_output]
      puts "🍕  Grilling gastronomical group emails:\n#{lunch_set.inspect_emails}"

      puts "🍦  Flash-freezing flavorful files:"
      export_people(lunch_set.people + unlunchable_people)
      export_previous_people(people) unless Config.options[:offline]
    rescue Exception => e
      puts e.message
    end
  end

  protected

  def spin(people, iterations)
    i = 0
    valid_sets = 0
    iterations.times.reduce(nil) do |leader|
      new_set = LunchSet.generate(people.shuffle)
      valid_sets += 1 if new_set.valid?
      print "#{valid_sets == 0 ? '🐄' : '🍔'}  Valid sets found: #{valid_sets}. Percent complete: #{((100.0 * (i += 1) / iterations)).round(4)}%\r"
      
      break new_set if new_set.valid? && Config.options[:valid]

      [leader, new_set].compact.select(&:valid?).min_by(&:score)
    end.tap{puts "\n"}
  end

  def people
    @people ||= 
      if Config.options[:people_file]
        puts "Reading people file from: #{Config.options[:people_file]}"
        CsvClient.read_csv(Config.options[:people_file])
      else
        puts "Downloading people sheet from: #{SPREADSHEET_URL}"
        SheetsClient.get(SPREADSHEET_ID, PEOPLE_RANGE)
      end.map do |p|
        Person.new(
          name: p['name'],
          email: p['email'], 
          start_date: DateTime.strptime(p['start_date'], PERSON_DATE_FORMAT),
          team: p['team'] && p['team'].empty? ? nil : p['team'],
          manager: p['manager'] && p['manager'].empty? ? nil : p['manager'], 
          leadership: p['leadership'].to_s.downcase.gsub(/\s+/, '') == 'true',
          lunchable_default: p['lunchable_default'].downcase == 'true',
          lunches: String(p['lunches']).split(',').map{|s| Lunch.from_s(s.strip)},
          survey: surveys.
            select(&:current?).
            select{|s| s.email == p['email']}.
            sort_by(&:date).
            reverse.
            first
        )
      end
  end

  def surveys
    @surveys ||= 
      if Config.options[:survey]
        puts "Downloading surveys sheet from: #{SPREADSHEET_URL}"
        SheetsClient.get(SPREADSHEET_ID, SURVEY_RANGE)
      else
        []
      end.map do |s|
        next unless s.length == 3
        Survey.new(
          email: s.values[0],
          lunchable: s.values[1].downcase == SURVEY_TRUE, 
          date: DateTime.strptime(s.values[2], SURVEY_DATE_FORMAT)
        )
      end
  end

  def export_people(people)
    people_rows = people.sort_by(&:start_date).map(&:to_row)
    if Config.options[:offline]
      puts "Writing new people file to: #{PEOPLE_OUTPUT_FILE}"
      CsvClient.write_csv(PEOPLE_OUTPUT_FILE, people_rows)
    else
      puts "Updating new people sheet at: #{SPREADSHEET_URL}"
      SheetsClient.update(SPREADSHEET_ID, PEOPLE_RANGE, people_rows)
    end
  end

  def export_previous_people(people)
    people_rows = people.sort_by(&:start_date).map(&:to_row)
    puts "Updating previous people sheet at: #{SPREADSHEET_URL}"
    SheetsClient.update(SPREADSHEET_ID, PEOPLE_OLD_RANGE, people_rows)
  end
end

LunchRoulette.new(ARGV).run!
