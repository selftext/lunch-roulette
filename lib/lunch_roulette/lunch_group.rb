class LunchRoulette
  class LunchGroup

    MAX_GROUP_SCORE = Config.max_group_score

    TENURE_WEIGHT = Config.tenure_weight
    TEAM_WEIGHT = Config.team_weight
    MANAGER_WEIGHT = Config.manager_weight
    COLLEAGUE_WEIGHT = Config.colleague_weight
    PREVIOUS_LUNCHES_WEIGHT = Config.previous_lunches_weight

    attr_accessor :id, :people

    def initialize(id:, people:)
      @id = id
      @people = people
    end

    def emails
      people.map(&:email)
    end

    def valid?
      score <= MAX_GROUP_SCORE &&
        manager_score <= 1
    end

    def score
      TENURE_WEIGHT * tenure_score +
        TEAM_WEIGHT * team_score +
        MANAGER_WEIGHT * manager_score + 
        COLLEAGUE_WEIGHT * colleague_score + 
        PREVIOUS_LUNCHES_WEIGHT * previous_lunches_score
    end

    def tenure_score
      100.0 / (1 + people.map(&:days_here).standard_deviation)
    end

    def team_score
      10.0 / (1 + people.map(&:team_value).standard_deviation)
    end
    
    def manager_score
      names = people.map(&:name)
      managers = people.map(&:manager)
      overlap = names & managers
      managers.count{|m| overlap.include?(m)}
    end

    def colleague_score
      managers = people.map(&:manager).compact
      managers.uniq.reduce(0) do |sum, manager|
        count = managers.count(manager)
        sum + (count - 1) ** 2
      end
    end

    def previous_lunches_score
      previous_lunches = people.flat_map(&:previous_lunches)
      latest_lunch = people.first.latest_lunch
      previous_lunches.uniq.reduce(0) do |sum, prev_lunch|
        count = previous_lunches.count{|p| prev_lunch.equals(p)}
        sum + (count - 1) ** 2 * latest_lunch.previous_lunch_decay(prev_lunch)
      end
    end

    def inspect_scores
      "Group #{id}: " + 
      "score #{score} ("+
        "tenure #{tenure_score}, " +
        "teams #{team_score}, " +
        "managers #{manager_score}, " +
        "colleagues #{colleague_score}, " +
        "previous_lunches #{previous_lunches_score})"
    end

    def inspect_emails
      "Group #{id}: " + emails.join(', ')
    end
  end
end

