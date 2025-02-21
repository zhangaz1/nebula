Feature: Lookup tag index full scan

  Background:
    Given a graph with space named "nba"

  Scenario: Tag with relational RegExp filter[1]
    When executing query:
      """
      LOOKUP ON team where team.name =~ "\\d+\\w+"
      """
    Then a SemanticError should be raised at runtime: Expression (team.name=~"\d+\w+") is not supported, please use full-text index as an optimal solution

  Scenario: Tag with relational NE filter
    When profiling query:
      """
      LOOKUP ON team WHERE team.name != "Hornets"
      """
    Then the result should be, in any order:
      | VertexID        |
      | "76ers"         |
      | "Bucks"         |
      | "Bulls"         |
      | "Cavaliers"     |
      | "Celtics"       |
      | "Clippers"      |
      | "Grizzlies"     |
      | "Hawks"         |
      | "Heat"          |
      | "Jazz"          |
      | "Kings"         |
      | "Knicks"        |
      | "Lakers"        |
      | "Magic"         |
      | "Mavericks"     |
      | "Nets"          |
      | "Nuggets"       |
      | "Pacers"        |
      | "Pelicans"      |
      | "Pistons"       |
      | "Raptors"       |
      | "Rockets"       |
      | "Spurs"         |
      | "Suns"          |
      | "Thunders"      |
      | "Timberwolves"  |
      | "Trail Blazers" |
      | "Warriors"      |
      | "Wizards"       |
    And the execution plan should be:
      | id | name             | dependencies | operator info                             |
      | 3  | Project          | 2            |                                           |
      | 2  | Filter           | 4            | {"condition": "(team.name!=\"Hornets\")"} |
      | 4  | TagIndexFullScan | 0            |                                           |
      | 0  | Start            |              |                                           |

  # TODO: Support compare operator info that has multiple column hints
  Scenario: Tag with simple relational IN filter
    When profiling query:
      """
      LOOKUP ON team WHERE team.name IN ["Hornets", "Jazz"]
      """
    Then the result should be, in any order:
      | VertexID  |
      | "Jazz"    |
      | "Hornets" |
    And the execution plan should be:
      | id | name      | dependencies | operator info |
      | 3  | Project   | 4            |               |
      | 4  | IndexScan | 0            |               |
      | 0  | Start     |              |               |
    When executing query:
      """
      LOOKUP ON team WHERE team.name IN ["non-existed-name"]
      """
    Then the result should be, in any order:
      | VertexID |
    When profiling query:
      """
      LOOKUP ON player WHERE player.age IN [40 - 1 , 72/2] YIELD player.age
      """
    Then the result should be, in any order:
      | VertexID            | player.age |
      | "Amar'e Stoudemire" | 36         |
      | "Tracy McGrady"     | 39         |
      | "Tony Parker"       | 36         |
      | "Boris Diaw"        | 36         |
    And the execution plan should be:
      | id | name      | dependencies | operator info |
      | 3  | Project   | 4            |               |
      | 4  | IndexScan | 0            |               |
      | 0  | Start     |              |               |
    # (a IN b) OR c
    When profiling query:
      """
      LOOKUP ON player WHERE player.age IN [40, 25] OR player.name == "ABC" YIELD player.age
      """
    Then the result should be, in any order:
      | VertexID        | player.age |
      | "Dirk Nowitzki" | 40         |
      | "Joel Embiid"   | 25         |
      | "Kobe Bryant"   | 40         |
      | "Kyle Anderson" | 25         |
    And the execution plan should be:
      | id | name      | dependencies | operator info |
      | 3  | Project   | 4            |               |
      | 4  | IndexScan | 0            |               |
      | 0  | Start     |              |               |
    # (a IN b) OR (c IN d)
    When profiling query:
      """
      LOOKUP ON player WHERE player.age IN [40, 25] OR player.name IN ["Kobe Bryant"] YIELD player.age
      """
    Then the result should be, in any order:
      | VertexID        | player.age |
      | "Dirk Nowitzki" | 40         |
      | "Joel Embiid"   | 25         |
      | "Kobe Bryant"   | 40         |
      | "Kyle Anderson" | 25         |
    And the execution plan should be:
      | id | name      | dependencies | operator info |
      | 3  | Project   | 4            |               |
      | 4  | IndexScan | 0            |               |
      | 0  | Start     |              |               |
    # (a IN b) AND c
    When profiling query:
      """
      LOOKUP ON player WHERE player.age IN [40, 25] AND player.name == "Kobe Bryant" YIELD player.age
      """
    Then the result should be, in any order:
      | VertexID      | player.age |
      | "Kobe Bryant" | 40         |
    And the execution plan should be:
      | id | name      | dependencies | operator info |
      | 3  | Project   | 4            |               |
      | 4  | IndexScan | 0            |               |
      | 0  | Start     |              |               |
    When profiling query:
      """
      LOOKUP ON player WHERE player.name IN ["Kobe Bryant", "Tim Duncan"] AND player.age > 30
      """
    Then the result should be, in any order:
      | VertexID      |
      | "Kobe Bryant" |
      | "Tim Duncan"  |
    And the execution plan should be:
      | id | name      | dependencies | operator info |
      | 3  | Project   | 4            |               |
      | 4  | IndexScan | 0            |               |
      | 0  | Start     |              |               |
    # c AND (a IN b)
    When profiling query:
      """
      LOOKUP ON player WHERE player.age IN [40, 25] AND player.name == "Kobe Bryant" YIELD player.age
      """
    Then the result should be, in any order:
      | VertexID      | player.age |
      | "Kobe Bryant" | 40         |
    And the execution plan should be:
      | id | name      | dependencies | operator info |
      | 3  | Project   | 4            |               |
      | 4  | IndexScan | 0            |               |
      | 0  | Start     |              |               |

  Scenario: Tag with complex relational IN filter
    Given an empty graph
    And load "nba" csv data to a new space
    # (a IN b) AND (c IN d) while a, c both have indexes
    When profiling query:
      """
      LOOKUP ON player WHERE player.age IN [40, 25] AND player.name IN ["ABC", "Kobe Bryant"] YIELD player.age
      """
    Then the result should be, in any order:
      | VertexID      | player.age |
      | "Kobe Bryant" | 40         |
    And the execution plan should be:
      | id | name      | dependencies | operator info |
      | 3  | Project   | 4            |               |
      | 4  | IndexScan | 0            |               |
      | 0  | Start     |              |               |
    # (a IN b) AND (c IN d) while a, c have a composite index
    When executing query:
      """
      CREATE TAG INDEX composite_player_name_age_index ON player(name(64), age);
      """
    Then the execution should be successful
    And wait 6 seconds
    When submit a job:
      """
      REBUILD TAG INDEX composite_player_name_age_index
      """
    Then wait the job to finish
    When profiling query:
      """
      LOOKUP ON player WHERE player.age IN [40, 25] AND player.name IN ["ABC", "Kobe Bryant"] YIELD player.age
      """
    Then the result should be, in any order:
      | VertexID      | player.age |
      | "Kobe Bryant" | 40         |
    And the execution plan should be:
      | id | name      | dependencies | operator info |
      | 3  | Project   | 4            |               |
      | 4  | IndexScan | 0            |               |
      | 0  | Start     |              |               |
    # (a IN b) AND (c IN d) while only a has index
    # first drop tag index
    When executing query:
      """
      DROP TAG INDEX composite_player_name_age_index
      """
    Then the execution should be successful
    When executing query:
      """
      DROP TAG INDEX player_name_index
      """
    Then the execution should be successful
    And wait 6 seconds
    # since the tag index has been dropped, here a TagIndexFullScan should be performed
    When profiling query:
      """
      LOOKUP ON player WHERE player.name IN ["ABC", "Kobe Bryant"] YIELD player.age
      """
    Then the result should be, in any order:
      | VertexID      | player.age |
      | "Kobe Bryant" | 40         |
    And the execution plan should be:
      | id | name             | dependencies | operator info |
      | 3  | Project          | 2            |               |
      | 2  | Filter           | 4            |               |
      | 4  | TagIndexFullScan | 0            |               |
      | 0  | Start            |              |               |
    When profiling query:
      """
      LOOKUP ON player WHERE player.age IN [40, 25] AND player.name IN ["ABC", "Kobe Bryant"] YIELD player.age
      """
    Then the result should be, in any order:
      | VertexID      | player.age |
      | "Kobe Bryant" | 40         |
    And the execution plan should be:
      | id | name      | dependencies | operator info |
      | 3  | Project   | 4            |               |
      | 4  | IndexScan | 0            |               |
      | 0  | Start     |              |               |
    Then drop the used space

  Scenario: Tag with relational NOT IN filter
    When profiling query:
      """
      LOOKUP ON team WHERE team.name NOT IN ["Hornets", "Jazz"]
      """
    Then the result should be, in any order:
      | VertexID        |
      | "76ers"         |
      | "Bucks"         |
      | "Bulls"         |
      | "Cavaliers"     |
      | "Celtics"       |
      | "Clippers"      |
      | "Grizzlies"     |
      | "Hawks"         |
      | "Heat"          |
      | "Wizards"       |
      | "Warriors"      |
      | "Kings"         |
      | "Knicks"        |
      | "Lakers"        |
      | "Magic"         |
      | "Mavericks"     |
      | "Nets"          |
      | "Nuggets"       |
      | "Pacers"        |
      | "Pelicans"      |
      | "Pistons"       |
      | "Raptors"       |
      | "Rockets"       |
      | "Spurs"         |
      | "Suns"          |
      | "Thunders"      |
      | "Timberwolves"  |
      | "Trail Blazers" |
    And the execution plan should be:
      | id | name             | dependencies | operator info                                              |
      | 3  | Project          | 2            |                                                            |
      | 2  | Filter           | 4            | {"condition": "(team.name NOT IN [\"Hornets\",\"Jazz\"])"} |
      | 4  | TagIndexFullScan | 0            |                                                            |
      | 0  | Start            |              |                                                            |
    When profiling query:
      """
      LOOKUP ON player WHERE player.age NOT IN [40 - 1 , 72/2] YIELD player.age
      """
    Then the result should be, in any order:
      | VertexID                | player.age |
      | "Yao Ming"              | 38         |
      | "Aron Baynes"           | 32         |
      | "Ben Simmons"           | 22         |
      | "Blake Griffin"         | 30         |
      | "Vince Carter"          | 42         |
      | "Carmelo Anthony"       | 34         |
      | "Chris Paul"            | 33         |
      | "Cory Joseph"           | 27         |
      | "Damian Lillard"        | 28         |
      | "Danny Green"           | 31         |
      | "David West"            | 38         |
      | "DeAndre Jordan"        | 30         |
      | "Dejounte Murray"       | 29         |
      | "Dirk Nowitzki"         | 40         |
      | "Dwight Howard"         | 33         |
      | "Dwyane Wade"           | 37         |
      | "Giannis Antetokounmpo" | 24         |
      | "Grant Hill"            | 46         |
      | "JaVale McGee"          | 31         |
      | "James Harden"          | 29         |
      | "Jason Kidd"            | 45         |
      | "Joel Embiid"           | 25         |
      | "Jonathon Simmons"      | 29         |
      | "Kevin Durant"          | 30         |
      | "Klay Thompson"         | 29         |
      | "Kobe Bryant"           | 40         |
      | "Kristaps Porzingis"    | 23         |
      | "Kyle Anderson"         | 25         |
      | "Kyrie Irving"          | 26         |
      | "LaMarcus Aldridge"     | 33         |
      | "LeBron James"          | 34         |
      | "Luka Doncic"           | 20         |
      | "Manu Ginobili"         | 41         |
      | "Marc Gasol"            | 34         |
      | "Marco Belinelli"       | 32         |
      | "Nobody"                | 0          |
      | "Null1"                 | -1         |
      | "Null2"                 | -2         |
      | "Null3"                 | -3         |
      | "Null4"                 | -4         |
      | "Paul Gasol"            | 38         |
      | "Paul George"           | 28         |
      | "Rajon Rondo"           | 33         |
      | "Ray Allen"             | 43         |
      | "Ricky Rubio"           | 28         |
      | "Rudy Gay"              | 32         |
      | "Russell Westbrook"     | 30         |
      | "Shaquille O'Neal"      | 47         |
      | "Stephen Curry"         | 31         |
      | "Steve Nash"            | 45         |
      | "Tiago Splitter"        | 34         |
      | "Tim Duncan"            | 42         |
    And the execution plan should be:
      | id | name             | dependencies | operator info                                |
      | 3  | Project          | 2            |                                              |
      | 2  | Filter           | 4            | {"condition": "(player.age NOT IN [39,36])"} |
      | 4  | TagIndexFullScan | 0            |                                              |
      | 0  | Start            |              |                                              |

  Scenario: Tag with relational CONTAINS/NOT CONTAINS filter
    When executing query:
      """
      LOOKUP ON team WHERE team.name CONTAINS "ABC"
      """
    Then a SemanticError should be raised at runtime: Expression (team.name CONTAINS "ABC") is not supported, please use full-text index as an optimal solution
    When executing query:
      """
      LOOKUP ON team WHERE team.name NOT CONTAINS "ABC"
      """
    Then a SemanticError should be raised at runtime: Expression (team.name NOT CONTAINS "ABC") is not supported, please use full-text index as an optimal solution

  Scenario: Tag with relational STARTS WITH filter
    When profiling query:
      """
      LOOKUP ON team WHERE team.name STARTS WITH toUpper("t")
      """
    Then the result should be, in any order:
      | VertexID        |
      | "Trail Blazers" |
      | "Timberwolves"  |
      | "Thunders"      |
    And the execution plan should be:
      | id | name             | dependencies | operator info                                  |
      | 3  | Project          | 2            |                                                |
      | 2  | Filter           | 4            | {"condition": "(team.name STARTS WITH \"T\")"} |
      | 4  | TagIndexFullScan | 0            |                                                |
      | 0  | Start            |              |                                                |
    When executing query:
      """
      LOOKUP ON team WHERE team.name STARTS WITH "ABC"
      """
    Then the result should be, in any order:
      | VertexID |
    When executing query:
      """
      LOOKUP ON team WHERE team.name STARTS WITH 123
      """
    Then a SemanticError should be raised at runtime: Column type error : name
    When profiling query:
      """
      LOOKUP ON team WHERE team.name NOT STARTS WITH toUpper("t")
      """
    Then a SemanticError should be raised at runtime: Expression (team.name NOT STARTS WITH toUpper("t")) is not supported, please use full-text index as an optimal solution

  Scenario: Tag with relational ENDS/NOT ENDS WITH filter
    When executing query:
      """
      LOOKUP ON team WHERE team.name ENDS WITH toLower("S")
      """
    Then a SemanticError should be raised at runtime: Expression (team.name ENDS WITH toLower("S")) is not supported, please use full-text index as an optimal solution
    When executing query:
      """
      LOOKUP ON team WHERE team.name NOT ENDS WITH toLower("S")
      """
    Then a SemanticError should be raised at runtime: Expression (team.name NOT ENDS WITH toLower("S")) is not supported, please use full-text index as an optimal solution
