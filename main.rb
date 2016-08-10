require 'telegram/bot'
require 'thor'
require 'pry'
$setfile = "settings.json"
$dir = "samples"
def start_text
  "This will be a garmony trainer"
end
class Player
  attr_reader :id
  attr_accessor :right, :wrong, :think
  def initialize(chat_id)
    @id = chat_id;
    @right = @wrong = 0
  end
end
$players = []
$answers = Dir.entries('samples').delete_if{|d| d=="." or d == ".."}



def audio(bot,message)
  player = $players.find{|p| p.id == message.chat.id}
  if !player
    player = Player.new(message.chat.id)
    $players << player
  end
  if !player.think
    tone = $answers.sample;
    bot.api.send_audio(chat_id: message.chat.id, audio: Faraday::UploadIO.new("#{$dir}/#{tone}/vk.mp3",'audio/mp3'))
    player.think = tone
    question = "What tone?"
    vars = $answers.reject{|a| a==tone}.sample(3); vars<<tone; vars.shuffle!
    answers = Telegram::Bot::Types::ReplyKeyboardMarkup
          .new(keyboard: [[vars[0],vars[1]], [vars[2], vars[3]],["finish"]], one_time_keyboard: true)
    bot.api.send_message(chat_id: message.chat.id, text: question, reply_markup: answers)
  else
    puts "player think in method audio"
  end
end

def check_player_ans(bot,message)
  player = $players.find{|p| p.id == message.chat.id}
  if !player
    puts "answer from unknown player"
    return start(bot,message)
  end
  if player.think == message.text
    bot.api.sendMessage(chat_id: message.chat.id, text: "👍");
    player.right+=1
  else
    bot.api.sendMessage(chat_id: message.chat.id,text: "It's false!\nRight answer: #{player.think}")
    player.wrong+=1
  end
  player.think = nil
  audio(bot,message)
end

def finish(bot,message)
  player = $players.find{|p| p.id == message.chat.id}
  if !player
    puts "unknows player in finish"
    return nil
  end
  answers = Telegram::Bot::Types::ReplyKeyboardMarkup
          .new(keyboard: [['/audio']], one_time_keyboard: true)

  bot.api.sendMessage(chat_id: message.chat.id,text: "Your score: #{player.right} right,  #{player.wrong} wrong", reply_markup: answers)
  player.think = nil
end
def start(bot,message)
  question = "Hello, #{message.from.first_name}\n\n" + start_text
  answers = Telegram::Bot::Types::ReplyKeyboardMarkup
          .new(keyboard: [['/audio']], one_time_keyboard: true)
  bot.api.send_message(chat_id: message.chat.id, text: question, reply_markup: answers)
end

class ChordTrainer < Thor
  desc "set", "set telegram-api token"
  option :token, :type => :string
  def set
    pars = (File.exist?($setfile)) ? JSON.parse(open($setfile).read): {}
    pars["token"] = options[:token] if options[:token]
    out = File.open($setfile,"w"); out.write(pars.to_json); out.close
  end
  desc "test", 'binding.pry'
  def test
    binding.pry
  end
  desc "listen", "start telegram bot"
  def listen
    if !File.exist?($setfile)
      puts "set params"
      return nil
    end
    pars = JSON.parse(open($setfile).read)
    $token = pars["token"]
    Telegram::Bot::Client.run($token) do |bot|
      bot.listen do |message|
        case message.text
        when '/start'
          start(bot,message)
        when '/audio'
          audio(bot,message)
        when 'finish'
          finish(bot,message)
        else
          #puts message.text
          if message.text.match /\A([a-hA-H]|[cCfF]is|[eEaA]s)(aug|dim)?\d*\z/
            check_player_ans(bot,message)
          else
            answers = Telegram::Bot::Types::ReplyKeyboardMarkup
              .new(keyboard: [['/audio']], one_time_keyboard: true)
            bot.api.send_message(chat_id: message.chat.id, text: '', reply_markup: answers)
          end
        end
      end
    end
  end
end
$counter = 0
def autorestart(args)
  begin
    ChordTrainer.start(args)
  rescue => e
    $counter += 1
    puts "(#{$counter})\t#{e.class}"
    puts e.message
    sleep 5
    autorestart(args)
  end
end

autorestart(ARGV)
#ChordTrainer.start(ARGV)

