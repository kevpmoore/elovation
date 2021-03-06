module ApplicationHelper
  def gravatar_url(player, options = {})
    options.assert_valid_keys :size
    size = options[:size] || 32
    digest = player.email.blank? ? "0" * 32 : Digest::MD5.hexdigest(player.email)
    "http://www.gravatar.com/avatar/#{digest}?d=mm&s=#{size}"
  end

  def format_time(time)
    "#{time_ago_in_words(time)} ago"
  end

  def player_avatar(player)
    if player.avatar.exists?
      image_tag(player.avatar.url(:thumb))
    else
      image_tag(gravatar_url(player, size: 80))
    end
  end

  def player_avatar_tiny(player)
    if player.avatar.exists?
      image_tag(player.avatar.url(:tiny))
    else
      image_tag(gravatar_url(player, size: 24))
    end
  end
end
