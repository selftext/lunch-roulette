require 'csv'
require 'set'

IN_CSV = 'data/people_legacy.csv'
OUT_CSV = 'data/people_converted.csv'
ID_FIELD = 'email'
LEGACY_LUNCHES_FIELD = 'previous_lunches'
LUNCHES_FIELD = 'lunches'

def read_people
  people = []
  CSV.foreach(IN_CSV, headers: true) do |row|
    people << Hash[row].merge(legacy_lunches: String(row[LEGACY_LUNCHES_FIELD]).split(',').map(&:to_i))
  end
  people
end

def lunch_groups(people)
  lunches = Hash.new([])
  people.each do |p|
    p[:legacy_lunches].each do |l|
      lunches[l] += [p[ID_FIELD]]
    end
  end
  lunches.sort_by{|l| l[0]}
end

def lunch_sets(lunch_groups)
  current_set = 1
  person_max_set = Hash.new(0)
  sets = Hash.new(Set.new)
  lunch_groups.each do |g|
    max_set = g[1].map{|person| person_max_set[person]}.max
    current_set += 1 if max_set >= current_set
    g[1].each{|person| person_max_set[person] = current_set}
    sets[current_set] += [g[0]]
  end
  sets
end

def people_month_groups(groups)
  current_months_back = 0
  current_group = 0
  people = Hash.new([])

  groups.reverse.each do |g| 
    max_months_back = people.
      select{|k, v| g.include? k}.
      values.flatten.map{|v| v[:months_back]}.
      max || 0

    if max_months_back >= current_months_back 
      current_months_back += 1
      current_group = 0
    end

    g.each{|p| people[p] += [{months_back: current_months_back, group: current_group}]}
    current_group += 1
  end

  people.map do |person, gs|
    [person, gs.reverse.map{|g| {month: current_months_back - g[:months_back], group: g[:group]}}]
  end.to_h
end


def groups(people)
  people.reduce(Hash.new([])) do |accum, (person, groups)|
    groups.each do |g|
      accum[g] += [person]
    end
    accum
  end
end

def month_groups_heavy(groups, total_months)
  current_month = total_months
  current_group = 0

  groups.reverse.reduce(Hash.new([])) do |accum, g| 
    min_month = accum.
      select{|k, v| g.include? k}.
      values.flatten.map{|v| v[:month]}.
      min || total_months

    current_group += 1
    if min_month <= current_month 
      current_month -= 1
      current_group = 0
    end

    added_groups = g.map do |p|
      [p, [{month: current_month, group: current_group}] + accum[p]]
    end
    accum.merge(added_groups.to_h)
  end
end

def month_groups_merge(groups, total_months)
  groups.sort_by{|g, _| g}.reverse.reduce(Hash.new([])) do |accum, (group, people)| 
    min_month = accum.
      select{|p, _| people.include? p}.
      values.
      flatten.
      map{|g| g[:month]}.
      min || total_months + 1

    added_groups = people.map do |p|
      [p, [{month: min_month - 1, group: group}]]
    end.to_h
    accum.merge(added_groups){|p, oldval, newval| newval + oldval}
  end
end

def months_back(groups)
  groups.sort_by{|g, _| g}.reverse.reduce(Hash.new([])) do |accum, (group, people)| 
    months_back = accum.
      select{|p, _| people.include? p}.
      values.
      flatten.
      map{|g| g[:mb]}.
      max.to_i + 1

    people.each do |p|
      accum[p] += [{mb: months_back, g: group}]
    end
    accum
  end
end

def months(months_back) 
  total_months = months_back.
    values.
    flatten.
    map{|g| g[:months_back]}.
    max

  months_back.map do |p, g|
    months = g.map do |g|
      {month: total_months - g[:months_back] + 1, group: g[:group]}
    end.sort_by{|g| g[:month]}
    [p, months]
  end.to_h
end


def set_groups(lunch_sets)
  lunch_sets.flat_map do |s|
    i = 0
    s[1].sort.map do |g|
      i += 1
      [g, {set: s[0], group: i}]
    end
  end.to_h
end

def people_set_groups(people, set_groups)
  people.map do |p|
    p_set_groups = p[:legacy_lunches].map do |l|
      set_groups[l]
    end
    p.merge(
      lunches: p_set_groups,
      LUNCHES_FIELD => p_set_groups.map{|l| "#{l[:set]}-#{l[:group]}"}.join(', ')
    )
  end.sort_by{|p| p[:lunches].length}.reverse
end

def valid?(people_set_groups)
  people_set_groups.map do |p|
    sets = p[:lunches].map{|l| l[:set]}
    sets.uniq == sets
  end.all?
end

def write_csv(people_set_groups)
  header = people_set_groups.first.keys.reject{|k| [:legacy_lunches, :lunches].include?(k)}
  CSV.open(OUT_CSV, "w") do |csv|
    csv << header
    people_set_groups.each do |row|
      csv << header.map{|k| row[k]}
    end
  end
end

people = read_people
set_groups = set_groups(lunch_sets(lunch_groups(people)))
people_set_groups = people_set_groups(people, set_groups)

if valid?(people_set_groups)
  write_csv(people_set_groups) 
  puts "File written to #{OUT_CSV}"
else
  puts "Conversion was invalid"
end
