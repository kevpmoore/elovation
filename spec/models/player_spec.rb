require "spec_helper"

describe Player do
  describe "as_json" do
    it "returns the json representation of the player" do
      player = FactoryGirl.build(:player, name: "John Doe", email: "foo@example.com")

      player.as_json.should == {
        name: "John Doe",
        email: "foo@example.com"
      }
    end
  end

  describe "validations" do
    context "name" do
      it "is required" do
        player = FactoryGirl.build(:player, name: nil)

        player.should_not be_valid
        player.errors[:name].should == ["can't be blank"]
      end

      it "must be unique" do
        FactoryGirl.create(:player, name: "Drew")
        player = FactoryGirl.build(:player, name: "Drew")

        player.should_not be_valid
        player.errors[:name].should == ["has already been taken"]
      end
    end

    context "email" do
      it "can be blank" do
        player = FactoryGirl.build(:player, email: "")
        player.should be_valid
      end

      it "must be a valid email format" do
        player = Player.new
        player.email = "invalid-email-address"
        player.should_not be_valid
        player.errors[:email].should == ["is invalid"]
        player.email = "valid@example.com"
        player.valid?
        player.errors[:email].should == []
      end
    end
  end

  describe "name" do
    it "has a name" do
      player = FactoryGirl.create(:player, name: "Drew")

      player.name.should == "Drew"
    end
  end

  describe "recent_results" do
    it "returns 5 of the player's results" do
      game = FactoryGirl.create(:game)
      player = FactoryGirl.create(:player)

      10.times { FactoryGirl.create(:result, game: game, teams: [FactoryGirl.create(:team, rank: 1, players: [player]), FactoryGirl.create(:team, rank: 2)]) }

      player.recent_results.size.should == 5
    end

    it "returns the 5 most recently created results" do
      newer_results = nil
      game = FactoryGirl.create(:game)
      player = FactoryGirl.create(:player)

      Timecop.freeze(3.days.ago) do
        5.times { FactoryGirl.create(:result, game: game, teams: [FactoryGirl.create(:team, rank: 1, players: [player]), FactoryGirl.create(:team, rank: 2)]) }
      end

      Timecop.freeze(1.day.ago) do
        newer_results = 5.times.map { FactoryGirl.create(:result, game: game, teams: [FactoryGirl.create(:team, rank: 1, players: [player]), FactoryGirl.create(:team, rank: 2)]) }
      end

      player.recent_results.sort.should == newer_results.sort
    end

    it "orders results by created_at, descending" do
      game = FactoryGirl.create(:game)
      player = FactoryGirl.create(:player)
      old = new = nil

      Timecop.freeze(2.days.ago) do
        old = FactoryGirl.create(:result, game: game, teams: [FactoryGirl.create(:team, rank: 1, players: [player]), FactoryGirl.create(:team, rank: 2)])
      end

      Timecop.freeze(1.days.ago) do
        new = FactoryGirl.create(:result, game: game, teams: [FactoryGirl.create(:team, rank: 1, players: [player]), FactoryGirl.create(:team, rank: 2)])
      end

      player.recent_results.should == [new, old]
    end
  end

  describe "destroy" do
    it "deletes related ratings and results" do
      player = FactoryGirl.create(:player)
      rating = FactoryGirl.create(:rating, player: player)
      result = FactoryGirl.create(:result, teams: [FactoryGirl.create(:team, rank: 1, players: [player]), FactoryGirl.create(:team, rank: 2)])

      player.destroy

      Rating.find_by_id(rating.id).should be_nil
      Result.find_by_id(result.id).should be_nil
    end
  end

  describe "ratings" do
    describe "find_or_create" do
      it "returns the rating if it exists" do
        player = FactoryGirl.create(:player)
        game = FactoryGirl.create(:game)
        rating = FactoryGirl.create(:rating, game: game, player: player)

        expect do
          found_rating = player.ratings.find_or_create(game)
          found_rating.should == rating
        end.to_not change { player.ratings.count }
      end

      it "creates a rating and returns it if it doesn't exist" do
        player = FactoryGirl.create(:player)
        game = FactoryGirl.create(:game)

        expect do
          player.ratings.find_or_create(game).should_not be_nil
        end.to change { player.ratings.count }.by(1)
      end
    end
  end

  describe "rewind_rating!" do
    it "resets the player's rating to the previous rating" do
      player = FactoryGirl.create(:player)
      game = FactoryGirl.create(:game)
      rating = FactoryGirl.create(:rating, game: game, player: player, value: 1002)
      FactoryGirl.create(:rating_history_event, rating: rating, value: 1001)
      FactoryGirl.create(:rating_history_event, rating: rating, value: 1002)

      player.rewind_rating!(game)

      player.ratings.where(game_id: game.id).first.value.should == 1001
    end
  end

  describe "wins" do
    it "finds wins" do
      player1 = FactoryGirl.create(:player)
      player1WinTeam = FactoryGirl.create(:team, rank: 1, players: [player1])

      player2 = FactoryGirl.create(:player)
      player2WinTeam = FactoryGirl.create(:team, rank: 1, players: [player2])

      game = FactoryGirl.create(:game)
      win = FactoryGirl.create(:result, game: game, teams: [player1WinTeam, FactoryGirl.create(:team, players: [player2], rank: 2)])
      loss = FactoryGirl.create(:result, game: game, teams: [FactoryGirl.create(:team, rank: 2, players: [player1]), player2WinTeam])

      player1.results.for_game(game).size.should == 2
      player1.total_wins(game).should == 1
      player1.wins(game, player2).should == 1
    end
  end

  describe 'win/loss' do
    it 'with a win and loss' do
      player1 = FactoryGirl.create(:player)
      player1WinTeam = FactoryGirl.create(:team, rank: 1, players: [player1])

      player2 = FactoryGirl.create(:player)
      player2WinTeam = FactoryGirl.create(:team, rank: 1, players: [player2])

      game = FactoryGirl.create(:game)
      win_for_player_1 = FactoryGirl.create(:result, game: game, teams: [player1WinTeam, FactoryGirl.create(:team, players: [player2], rank: 2)])
      loss_for_player_1 = FactoryGirl.create(:result, game: game, teams: [FactoryGirl.create(:team, rank: 2, players: [player1]), player2WinTeam])

      player1.win_loss_ratio(game).should == 50.0
    end

    it 'defaults to zero' do
      player1 = FactoryGirl.create(:player)
      game = FactoryGirl.create(:game)

      player1.win_loss_ratio(game).should == 0
    end
  end

  describe 'win/loss today' do
    it 'with a win and loss' do
      player1 = FactoryGirl.create(:player)
      player2 = FactoryGirl.create(:player)
      game = FactoryGirl.create(:game)

      create_result(game, player1, player2)
      create_result(game, player1, player2)
      create_result(game, player2, player1)
      create_result(game, player2, player1)

      Timecop.freeze(3.days.ago) do
        5.times { create_result(game, player1, player2) }
      end

      player1.win_loss_ratio(game).should be_within(77.77).of(0.01)
      player1.win_loss_ratio_for_today(game).should == 50
    end
  end

  describe 'streak' do
    it 'wins are counted' do
      player1 = FactoryGirl.create(:player)
      player2 = FactoryGirl.create(:player)
      game = FactoryGirl.create(:game)

      5.times { create_result(game, player1, player2) }

      player1.streak(game).should == 5
    end

    it 'a loss breaks the streak' do
      player1 = FactoryGirl.create(:player)
      player2 = FactoryGirl.create(:player)
      game = FactoryGirl.create(:game)


      5.times { create_result(game, player1, player2) }
      create_result(game, player2, player1)

      player1.streak(game).should == 0
    end
  end

  describe 'is active?' do
    it 'played a long time ago' do
      player1 = FactoryGirl.create(:player)
      player2 = FactoryGirl.create(:player)
      game = FactoryGirl.create(:game)

      Timecop.freeze(21.days.ago) do
        20.times { create_result(game, player1, player2) }
      end

      player1.is_active?.should be_false
    end

    it 'played recently' do
      player1 = FactoryGirl.create(:player)
      player2 = FactoryGirl.create(:player)
      game = FactoryGirl.create(:game)

      Timecop.freeze(19.days.ago) do
        20.times { create_result(game, player1, player2) }
      end

      player1.is_active?.should be_true
    end

    it 'played recently but not enough games' do
      player1 = FactoryGirl.create(:player)
      player2 = FactoryGirl.create(:player)
      game = FactoryGirl.create(:game)

      Timecop.freeze(15.days.ago) do
        5.times { create_result(game, player1, player2) }
      end

      Timecop.freeze(35.days.ago) do
        4.times { create_result(game, player1, player2) }
      end

      player1.is_active?.should be_false
    end
  end

  describe 'last n' do
    it 'with a win and loss' do
      player1 = FactoryGirl.create(:player)
      player2 = FactoryGirl.create(:player)
      game = FactoryGirl.create(:game)

      # FactoryGirl.create(:result, game: game, teams: [player1WinTeam, FactoryGirl.create(:team, players: [player2], rank: 2)])
      create_result(game, player1, player2)
      create_result(game, player1, player2)
      create_result(game, player1, player2)
      create_result(game, player2, player1)
      create_result(game, player1, player2)

      player1.last_n(game, 5).should == "WLWWW"
      player2.last_n(game, 5).should == "LWLLL"
    end
  end

  def create_result(game, winner, loser)
    FactoryGirl.create(:result, game: game, teams: [FactoryGirl.create(:team, rank: 1, players: [winner]), FactoryGirl.create(:team, rank: 2, players: [loser])])
  end

  describe "ties" do
    it "finds ties" do
      player1 = FactoryGirl.create(:player)
      player1WinTeam = FactoryGirl.create(:team, rank: 1, players: [player1])

      player2 = FactoryGirl.create(:player)
      player2WinTeam = FactoryGirl.create(:team, rank: 1, players: [player2])

      game = FactoryGirl.create(:game)
      tie = FactoryGirl.create(:result, game: game, teams: [player1WinTeam, player2WinTeam])

      player1.results.for_game(game).size.should == 1
      player1.total_ties(game).should == 1
      player1.ties(game, player2).should == 1
    end
  end

  describe "losses" do
    it "finds losses" do
      player = FactoryGirl.create(:player)
      game = FactoryGirl.create(:game)
      win = FactoryGirl.create(:result, game: game, teams: [FactoryGirl.create(:team, rank: 1, players: [player]), FactoryGirl.create(:team, rank: 2)])
      loss = FactoryGirl.create(:result, game: game, teams: [FactoryGirl.create(:team, rank: 2, players: [player]), FactoryGirl.create(:team, rank: 1)])
      player.results.for_game(game).size.should == 2
      player.results.for_game(game).losses.should == [loss]
    end
  end

  describe "against" do
    it "finds results against a specific opponent" do
      player = FactoryGirl.create(:player)
      game = FactoryGirl.create(:game, max_number_of_players_per_team: 2)
      opponent1 = FactoryGirl.create(:player)
      opponent2 = FactoryGirl.create(:player)
      win_against_opponent1 = FactoryGirl.create(:result, game: game, teams: [FactoryGirl.create(:team, rank: 1, players: [player]), FactoryGirl.create(:team, rank: 2, players: [opponent1])])
      loss_against_opponent1 = FactoryGirl.create(:result, game: game, teams: [FactoryGirl.create(:team, rank: 2, players: [player]), FactoryGirl.create(:team, rank: 1, players: [opponent1])])
      win_against_opponent2 = FactoryGirl.create(:result, game: game, teams: [FactoryGirl.create(:team, rank: 1, players: [player]), FactoryGirl.create(:team, rank: 2, players: [opponent2])])
      opponent2_game_against_different_player = FactoryGirl.create(:result, game: game, teams: [FactoryGirl.create(:team, rank: 1), FactoryGirl.create(:team, rank: 2, players: [opponent2])])
      win_with_opponent1 = FactoryGirl.create(:result, game: game, teams: [FactoryGirl.create(:team, rank: 1, players: [player, opponent1]), FactoryGirl.create(:team, rank: 2)])

      player.results.for_game(game).against(opponent1).sort_by(&:id).should match_array [win_against_opponent1, loss_against_opponent1]
      player.results.for_game(game).against(opponent2).sort_by(&:id).should match_array [win_against_opponent2]
    end
  end
end
