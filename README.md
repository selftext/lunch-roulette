# 🥑🥒🍔🍇 Lunch Roulette 🐓🌮🍕🍦

Lunch Roulette is a tool for finding diverse dining groups among coworkers and friends. It uses staff data (stored in Google Sheets or in CSV form) to generate small lunch groups of people from different teams and tenures who haven't dined together before.

With a single command, Lunch Roulette will download staff data and participation survey results from Google Sheets, scan through thousands of possible lunch groups until it finds the best one, update the Google Sheet with the results, and print out the emails of each group for dispersal. 

This is a forked version of the original [Lunch Roulette](https://github.com/fredbenenson/lunch-roulette), written and [blogged about](https://kickstarter.engineering/lunch-roulette-f5272a3990b9) by [Fred Benenson](https://twitter.com/fredbenenson) 🐋.

## How it works

Lunch Roulette is a command line application written in Ruby. It requires a CSV file with staff information and "features," such as their team, manager, and start date. This file can live offline in CSV form, or it can exist as a Google Sheet which Lunch Roulette accesses through the Google Sheets API. 

It is run using the ruby executable:

```ruby
ruby lib/lunch_roulette.rb
```

Features are things like the team that a person is on, or the day they started. These features can be weighted in different ways and mapped so that some values are "closer" to others. These weights and mappings are stored in a config file.

Other configurable options can be set at runtime, such as the path to an offline source CSV, the number of iterations to perform, and the ability to stop the search when the first valid lunch set is found.

```
Usage: ruby lunch_roulette.rb [OPTIONS]
    -f, --file F                     Offline people input: read people data from provided CSV
    -o, --offline                    Offline output: write timestamped CSV data locally to output directory
    -s, --survey                     read survey data from configured Google sheet
    -i, --iterations I               Iterations, default 1000
    -v, --valid                      Stop searching when the first valid set is encountered
    -c, --concise                    Concise output: suppress stats and previous-lunches printouts
    -h, --help                       Print this help
```

## A Dummy Staff

So that you can run Lunch Roulette out of the box, I've provided a dummy staff (thanks to Fred Benenson for using Namey to create the hilariously fake names) dataset in data/people_sample.csv


## Configuring Lunch Roulete

At the minimum, Lunch Roulette needs to know how different individual features are from each other. This is achieved by hardcoding a one dimensional mapping in `config/config.yml`:

```
iterations: 1_000
min_group_size: 4

max_manager_score: 1
max_previous_lunches_score: 2

team_mappings:
  Engineering: 0
  Data: 10
  Product: 20
  Design: 30
  Marketing: 40
  Outreach: 50
  Community Support: 60
  Integrity: 70
  Communications: 80
  Operations: 90
  Exec: 110

tenure_weight: 0.2
team_weight: 0.9
manager_weight: 1.0
colleague_weight: 1.0
previous_lunches_weight: 2.5
previous_lunches_half_life: 2
```

Lunch Roulette expects all employees to have a team (Community, Design, etc.) and a manager (the name of another teammate). It won't break if these are missing though.

## Using Google Sheets

Lunch Roulette is designed to be a one-command affair, and to do so it leverages the [Google Sheets API](https://developers.google.com/sheets/api/guides/concepts) to download and update your people data direct from a Google Sheet. To set this up a few things have to be configured first with Google. [Follow their quickstart guide](https://developers.google.com/sheets/api/quickstart/ruby) for Ruby scripts to get yourself situated.

## Surveys

If you want to survey your coworkers to see who is lunchable, Lunch Roulette is equipped to use those responses to make its groups. Just make a Google Form with a yes or no question, and point Lunch Roulette to the spreadsheet of survey results. It will download those and link them to users by email address. 

## Legacy support for group ids

The original Lunch Roulette algorithm gave every lunch group an id, starting from 1 and increasing incrementally. This made it hard to tell which previous lunch groups occurred on the same day, and moreover it made it hard to tell just how far in the past each previous lunch actually took place.

In this version of Lunch Roulette, lunches have two ids: a `set_id` and a `group_id`. For example, lunch `13-9` represents the 9th lunch group in the 13th edition of Lunch Roulette. This makes it easy to tell how far back in time a user's previous lunch was. So if you and I both were in lunch group `13-9`, and today we get put into group `20-10`, we can tell at a glance that it's been 7 session since we last dined together (20 - 13 = 7).

If you have been using the legacy version of Lunch Roulette with the single-id system, fear not. I've included a conversion script `convert_legacy_data.rb` that will automatically determine and record the `set_id`-`group_id` versions of all your staff's previous lunches.
